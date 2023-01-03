open! Import
open Rresult
open Bos
open Result.Syntax

let ( / ) = Fpath.( / )

module Versioning = struct
  let current_version = 2
  let version_file plugin_path = plugin_path / "ocaml-platform-version"

  let save_current_version plugin_path =
    OS.File.write_lines (version_file plugin_path)
      [ string_of_int current_version ]

  let parse_version = function
    | [] | _ :: _ :: _ -> None
    | [ v ] -> int_of_string_opt v

  let read_version plugin_path =
    let* pexists = OS.Dir.exists plugin_path in
    if not pexists then Ok None
    else
      let version_file = version_file plugin_path in
      let* vexists = OS.File.exists version_file in
      if not vexists then Ok (Some 0)
        (* Old enough to not have a version file *)
      else
        let* vcontent = OS.File.read_lines version_file in
        match parse_version vcontent with
        | None ->
            Result.errorf
              "Couldn't read cache version. Consider wiping the cache by \
               removing the directory '%a'."
              Fpath.pp plugin_path
        | Some v -> Ok (Some v)
end

module type Migrater = sig
  val migrate : Fpath.t -> (unit, [> `Msg of string ]) result
end

module Migrate_0_to_1 : Migrater = struct
  (** Constants *)

  let old_name_suffix = "+bin+platform"
  let new_version_suffix = "+platform"

  (** Helpers *)

  let replace_with old new_ s =
    Astring.String.cuts ~sep:old s |> String.concat new_

  let strip_suffix s = replace_with old_name_suffix "" s

  let modify_name f path =
    let base, name = Fpath.split_base path in
    let new_name = f (Fpath.to_string name) in
    let new_path = base / new_name in
    if Fpath.equal path new_path then Ok ()
    else Bos.OS.Cmd.run Cmd.(v "mv" % p path % p new_path)

  let iter_subdir f dir =
    let* subdirs = OS.Dir.contents dir in
    List.fold_left
      (fun acc subdir ->
        let* () = acc in
        f subdir)
      (Ok ()) subdirs

  let migrate_suffix ~suffix s =
    s |> strip_suffix |> replace_with suffix (new_version_suffix ^ suffix)

  (** Migraters *)

  (** The opam files contain a link to the archive: update that. *)
  let migrate_opam opam =
    let* content = OS.File.read opam in
    let new_content = migrate_suffix ~suffix:".tar.gz" content in
    OS.File.write opam new_content

  (** The name of install file contains the package name: update that. *)
  let migrate_install install = modify_name strip_suffix install

  (** The name of a pkg ver directory contains the package name and the version:
      update that, and migrate the install file and the opam file. *)
  let migrate_version pkgver =
    let* () = iter_subdir migrate_install (pkgver / "files") in
    let* () = migrate_opam (pkgver / "opam") in
    modify_name (fun name -> strip_suffix name ^ new_version_suffix) pkgver

  (** The name of a pkg directory contains the package name: update that, and
      migrate all pkgver directory inside. *)
  let migrate_package pkg =
    let* () = iter_subdir migrate_version pkg in
    modify_name strip_suffix pkg

  (** The name of an archive contains the package name and version: update that. *)
  let migrate_archive archive =
    modify_name (migrate_suffix ~suffix:".tar.gz") archive

  (** Compiler packages are now generated on the fly. Remove unused repo. *)
  let remove_sandbox_compiler_packages plugin_path =
    let repo_path = plugin_path / "platform_sandbox_compiler_packages" in
    OS.Dir.delete ~recurse:true repo_path

  (** Migrate all packages and archives. *)
  let migrate plugin_path =
    let packages_path = plugin_path / "cache" / "repo" / "packages" in
    let* () = iter_subdir migrate_package packages_path in
    let* () = remove_sandbox_compiler_packages plugin_path in
    let archive_path = plugin_path / "cache" / "archives" in
    iter_subdir migrate_archive archive_path
end

module Migrate_1_to_2 : Migrater = struct
  (** In earlier versions of [ocaml-platform], files that should be installed
      directly in the [share] folder were not installed. See
      {:https://github.com/tarides/ocaml-platform-installer/issues/148} *)

  (** Constants *)

  (** Tools impacted by the bug are removed. *)
  let tools_to_remove = [ "ocamlformat"; "merlin"; "dune" ]

  (** Helpers *)

  let iter_subdir f dir =
    let* subdirs = OS.Dir.contents dir in
    List.fold_left
      (fun acc subdir ->
        let* () = acc in
        f subdir)
      (Ok ()) subdirs

  let remove_if_needed condition path =
    let name = Fpath.basename path in
    if List.exists (condition name) tools_to_remove then
      Bos.OS.Cmd.run Cmd.(v "rm" % "-r" % p path)
    else Ok ()

  (** Migraters *)

  let migrate_package = remove_if_needed String.equal

  let migrate_archive =
    (* [dune-release] starts as [dune] but should not be removed, so we add a
       [.] to ensure the name of the package is finished. *)
    remove_if_needed (fun name pkg ->
        Astring.String.is_prefix ~affix:(pkg ^ ".") name)

  (** Migrate all packages and archives. *)
  let migrate plugin_path =
    let packages_path = plugin_path / "cache" / "repo" / "packages" in
    let* () = iter_subdir migrate_package packages_path in
    let archive_path = plugin_path / "cache" / "archives" in
    iter_subdir migrate_archive archive_path
end

module Migrate = struct
  open Versioning

  let rec migrate_data plugin_path v =
    let* () =
      match v with
      | 0 -> Migrate_0_to_1.migrate plugin_path
      | 1 -> Migrate_1_to_2.migrate plugin_path
      | _ -> Ok ()
    in
    if v + 1 >= current_version then Ok () else migrate_data plugin_path (v + 1)

  let wipe_plugin_data plugin_path = OS.Dir.delete ~recurse:true plugin_path

  (** Store a version number inside the repo directory to allow migrating the
      layout and clear obsolete packages. Operate on the files directory for
      flexibility. Also init the binary repo to make sure the version file is
      updated and that nothing is done with the repo before any migration. *)
  let init_repo_with_migration ~name plugin_path =
    let init_repo () =
      let global_binary_repo_path = plugin_path / "cache" in
      Binary_repo.init ~name global_binary_repo_path
    in
    let* version = read_version plugin_path in
    match version with
    | None ->
        (* No migration to do. Init the repo before saving the version, to not
           interfere the initialisation steps. *)
        let* repo = init_repo () in
        let* () = save_current_version plugin_path in
        Ok repo
    | Some version ->
        if version = current_version then init_repo ()
        else if version > current_version then
          Result.errorf
            "ocaml-platform was downgraded. Please either install a newer \
             version or remove the directory '%a'."
            Fpath.pp plugin_path
        else
          (* Might wipe the repository in case of a problem. Init the repo
             afterward. *)
          let* () =
            Logs.debug (fun m ->
                m "Current cache is at version %d and current version is %d"
                  version current_version);
            match migrate_data plugin_path version with
            | Ok () as ok -> ok
            | Error (`Msg msg) ->
                (* Don't let an error disturb the workflow, wipe the cache. *)
                Logs.warn (fun f ->
                    f "Deleting the cache due to a migration error (%s)" msg);
                wipe_plugin_data plugin_path
          in
          let* () = save_current_version plugin_path in
          init_repo ()
end

type t = {
  global_repo : Binary_repo.t;
  push_repo : Binary_repo.t option;
      (** [Some _] in case of a pinned compiler, [None] otherwise. *)
}

let load opam_opts ~pinned =
  let plugin_path =
    opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform"
  in
  let* global_repo =
    Migrate.init_repo_with_migration ~name:"platform-cache" plugin_path
  in
  if pinned then (
    (* Pinned compiler: don't actually cache the result by using a local
       repository. *)
    Logs.app (fun m -> m "* Pinned compiler detected. Caching is disabled.");
    let* switch_path =
      let+ switch_prefix = Opam.Config.Var.get opam_opts "prefix" in
      Fpath.(v switch_prefix / "var" / "cache" / "ocaml-platform")
    in
    let hash = Hashtbl.hash switch_path in
    let name = Printf.sprintf "ocaml-platform-pinned-cache-%d" hash in
    let+ push_repo = Migrate.init_repo_with_migration ~name switch_path in
    { global_repo; push_repo = Some push_repo })
  else
    (* Otherwise, use the global cache. *)
    Ok { global_repo; push_repo = None }

let has_binary_pkg t ~ocaml_version_dependent bname =
  if ocaml_version_dependent && Option.is_some t.push_repo then false
  else Binary_repo.has_binary_pkg t.global_repo bname

let push_repo t = Option.value t.push_repo ~default:t.global_repo

let enable_repos opam_opts t =
  (* Add the global repository first. The last repo added will be looked up
     first. *)
  let repos = t.global_repo :: Option.to_list t.push_repo in
  Result.List.fold_left
    (fun () repo ->
      let repo = Binary_repo.repo repo in
      let* () = Installed_repo.enable_repo opam_opts repo in
      Installed_repo.update opam_opts repo)
    () repos
