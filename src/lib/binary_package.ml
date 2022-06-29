open Import
open Result.Syntax
open Astring
open Bos

module Binary_install_file = struct
  type classified_files = {
    bin : (Fpath.t * Fpath.t) list;
    sbin : (Fpath.t * Fpath.t) list;
    share : (Fpath.t * Fpath.t) list;
    share_root : (Fpath.t * Fpath.t) list;
    etc : (Fpath.t * Fpath.t) list;
    doc : (Fpath.t * Fpath.t) list;
    man : (Fpath.t * Fpath.t) list;
    other : Fpath.t list;
  }

  let classify_file pkg_name cf f =
    let open Fpath in
    let f = v f in
    let f = match rem_prefix (v "_opam") f with None -> f | Some f -> f in
    let l =
      (* prefix, setter *)
      [
        (v "bin", fun cf v -> { cf with bin = v :: cf.bin });
        (v "sbin", fun cf v -> { cf with sbin = v :: cf.sbin });
        (v "share" / pkg_name, fun cf v -> { cf with share = v :: cf.share });
        (v "share_root", fun cf v -> { cf with share_root = v :: cf.share_root });
        (v "doc" / pkg_name, fun cf v -> { cf with doc = v :: cf.doc });
        (v "etc" / pkg_name, fun cf v -> { cf with etc = v :: cf.etc });
        (v "man" / pkg_name, fun cf v -> { cf with man = v :: cf.man });
      ]
    in
    Option.value ~default:{ cf with other = f :: cf.other }
    @@ List.find_map
         (fun (value, setter) ->
           Option.map (fun p -> setter cf (f, p)) (rem_prefix value f))
         l

  let from_file_list pkg_name fl =
    match
      List.fold_left (classify_file pkg_name)
        {
          bin = [];
          sbin = [];
          share = [];
          share_root = [];
          etc = [];
          doc = [];
          man = [];
          other = [];
        }
        fl
    with
    | { bin; sbin; share; share_root; etc; doc; man; other = _ } ->
        let process =
          List.map (fun (n, f) -> (Fpath.to_string n, Some (Fpath.to_string f)))
        in
        let bin = process bin
        and sbin = process sbin
        and share = process share
        and share_root = process share_root
        and etc = process etc
        and doc = process doc
        and man = process man in
        Package.Install_file.v ~bin ~sbin ~share ~share_root ~etc ~doc ~man
          ~pkg_name ()
end

type full_name = Package.full_name

(** Name and version of the binary package corresponding to a given package. *)
let binary_name ~ocaml_version ~name ~ver ~pure_binary =
  let name = if pure_binary then name else name ^ "+bin+platform" in
  let ver = ver ^ "-ocaml" ^ Ocaml_version.to_string ocaml_version in
  Package.v ~name ~ver

let name = Package.name
let ver = Package.ver
let package t = t
let to_string = Package.to_string

let generate_opam_file original_name bname pure_binary archive_path
    ocaml_version =
  let conflicts = if pure_binary then None else Some [ original_name ] in
  Package.Opam_file.v
    ~depends:[ ("ocaml", [ (`Eq, Ocaml_version.to_string ocaml_version) ]) ]
    ?conflicts ~url:archive_path ~pkg_name:(name bname) ()

let should_remove = Fpath.(is_prefix (v "lib"))

let process_path prefix path =
  let+ ex = Bos.OS.File.exists path in
  if not ex then None
  else
    match Fpath.rem_prefix prefix path with
    | None -> None
    | Some path ->
        if should_remove path then None else Some Fpath.(base prefix // path)

(** Binary is already in the sandbox. Add this binary as a package in the local
    repo *)
let make_binary_package opam_opts ~ocaml_version sandbox archive_path bname
    ~name:query_name ~pure_binary =
  let prefix = Sandbox_switch.switch_path_prefix sandbox in
  Sandbox_switch.list_files opam_opts sandbox ~pkg:query_name >>= fun paths ->
  let* paths =
    paths
    |> Result.List.filter_map (process_path prefix)
    >>| List.map Fpath.to_string
  in
  let tar_input = paths |> String.concat ~sep:"\n" in
  OS.Cmd.(
    in_string tar_input
    |> run_in
         Cmd.(
           v "tar" % "czf" % p archive_path % "-C"
           % p (Fpath.parent prefix)
           % "-T" % "-"))
  >>= fun () ->
  OS.File.exists archive_path >>= fun archive_created ->
  let install = Binary_install_file.from_file_list query_name paths in
  let opam_file =
    generate_opam_file query_name bname pure_binary archive_path ocaml_version
  in
  if not archive_created then
    Error (`Msg "Couldn't generate the package archive for unknown reason.")
  else Ok (install, opam_file)
