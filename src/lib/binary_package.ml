open Import
open Result.Syntax
open Astring
open Bos

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

let generate_opam_file original_name pure_binary archive_path ocaml_version =
  let conflicts = if pure_binary then None else Some [ original_name ] in
  Package.Opam_file.v
    ~install:[ [ "cp"; "-pPR"; "."; "%{prefix}%" ] ]
    ~depends:[ ("ocaml", Some ("=", Ocaml_version.to_string ocaml_version)) ]
    ?conflicts ~url:archive_path

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
    >>| List.map Fpath.to_string >>| String.concat ~sep:"\n"
  in
  OS.Cmd.(
    in_string paths
    |> run_in
         Cmd.(
           v "tar" % "czf" % p archive_path % "-C"
           % p (Fpath.parent prefix)
           % "-T" % "-"))
  >>= fun () ->
  OS.File.exists archive_path >>= fun archive_created ->
  if not archive_created then
    Error (`Msg "Couldn't generate the package archive for unknown reason.")
  else
    Ok
      (generate_opam_file query_name pure_binary archive_path ocaml_version
         ~opam_version:"2.0" ~pkg_name:(name bname))
