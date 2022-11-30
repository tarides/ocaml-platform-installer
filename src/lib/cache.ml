open! Import
open Rresult
open Bos
open Result.Syntax

let ( / ) = Fpath.( / )

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

  (** Migrate all packages and archives. *)
  let migrate plugin_path =
    let packages_path = plugin_path / "cache" / "repo" / "packages" in
    let* () = iter_subdir migrate_package packages_path in
    let archive_path = plugin_path / "cache" / "archives" in
    iter_subdir migrate_archive archive_path
end

module Migrate = struct
  let current_version = 1
  let version_file plugin_path = plugin_path / "ocaml-platform-version"

  let rec migrate_data plugin_path v =
    let* () =
      match v with 0 -> Migrate_0_to_1.migrate plugin_path | _ -> Ok ()
    in
    if v + 1 >= current_version then Ok () else migrate_data plugin_path (v + 1)

  let parse_version = function
    | [] | _ :: _ :: _ -> None
    | [ v ] -> int_of_string_opt v

  let read_version plugin_path =
    let* pexists = OS.Dir.exists plugin_path in
    if not pexists then Ok current_version (* No migration to do *)
    else
      let version_file = version_file plugin_path in
      let* vexists = OS.File.exists version_file in
      if not vexists then Ok 0 (* Old enough to not have a version file *)
      else
        let* vcontent = OS.File.read_lines version_file in
        match parse_version vcontent with
        | None -> Result.errorf "Couldn't read cache version"
        | Some v -> Ok v

  let save_current_version plugin_path =
    OS.File.write_lines (version_file plugin_path)
      [ string_of_int current_version ]

  let wipe_plugin_data plugin_path = OS.Dir.delete ~recurse:true plugin_path

  (** Store a version number inside the repo directory to allow migrating the
      layout and clear obsolete packages. Operate on the files directory for
      flexibility, should be done before doing anything with the repository. *)
  let migrate plugin_path =
    let* version = read_version plugin_path in
    if version = current_version then Ok ()
    else if version > current_version then Error `Future_version
    else
      let* () = migrate_data plugin_path version in
      save_current_version plugin_path

  (** Don't let an error disturb the workflow, wipe the cache. *)
  let migrate plugin_path =
    match migrate plugin_path with
    | Ok () as ok -> ok
    | Error `Future_version ->
        Result.errorf
          "ocaml-platform was downgraded. Please either install a newer \
           version or remove the directory '%a'."
          Fpath.pp plugin_path
    | Error (`Msg msg) ->
        Logs.warn (fun f ->
            f "Deleting the cache due to a migration error (%s)" msg);
        wipe_plugin_data plugin_path
end

type t = {
  global_repo : Binary_repo.t;
  push_repo : Binary_repo.t option;
      (** [Some _] in case of a pinned compiler, [None] otherwise. *)
}

let load opam_opts ~pinned =
  let init_with_migration ~name plugin_path =
    let global_binary_repo_path = plugin_path / "cache" in
    let* () = Migrate.migrate plugin_path in
    Binary_repo.init ~name global_binary_repo_path
  in
  let plugin_path =
    opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform"
  in
  let* global_repo = init_with_migration ~name:"platform-cache" plugin_path in
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
    let+ push_repo = init_with_migration ~name switch_path in
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
