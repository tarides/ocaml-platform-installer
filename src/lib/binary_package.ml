open Import
open Result.Syntax
open Astring
open Bos

type t = { name : string; ver : string }

(** Name and version of the binary package corresponding to a given package. *)
let binary_name ~ocaml ~name ~ver ~pure_binary =
  let name = if pure_binary then name else name ^ "+bin+platform" in
  let ocaml_version = Opam.Conversions.version_of_pkg ocaml in
  { name; ver = ver ^ "-ocaml" ^ ocaml_version }

let name_to_string { name; ver } = name ^ "." ^ ver
let name { name; ver = _ } = name

let has_binary_package repo { name; ver } =
  Repo.has_pkg (Binary_repo.repo repo) ~pkg:name ~ver

let generate_opam_file original_name pure_binary archive_path ocaml =
  let conflicts = if pure_binary then None else Some [ original_name ] in
  Repo.Opam_file.v
    ~install:[ [ "cp"; "-pPR"; "."; "%{prefix}%" ] ]
    ~depends:[ ("ocaml", Some ("=", Opam.Conversions.version_of_pkg ocaml)) ]
    ?conflicts ~url:archive_path

let should_remove = Fpath.(is_prefix (v "lib"))

let process_path prefix path =
  match Fpath.of_string path with
  | Error (`Msg s) -> Error (`Msg s)
  | Ok path -> (
      let+ ex = Bos.OS.File.exists path in
      if not ex then None
      else
        match Fpath.rem_prefix prefix path with
        | None -> None
        | Some path ->
            if should_remove path then None
            else Some Fpath.(base prefix // path))

(** Binary is already in the sandbox. Add this binary as a package in the local
    repo *)
let make_binary_package opam_opts ~ocaml sandbox repo ({ name; ver } as bname)
    ~name:query_name ~pure_binary =
  let prefix = Sandbox_switch.switch_path_prefix sandbox in
  let archive_path =
    Binary_repo.archive_path repo ~unique_name:(name_to_string bname ^ ".tar.gz")
  in
  Opam.Queries.(
    with_switch_state
      ~dir_name:(Sandbox_switch.get_sandbox_root sandbox)
      (files_installed_by_pkg query_name))
  >>= fun paths ->
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
    let opam = generate_opam_file query_name pure_binary archive_path ocaml in
    Repo.add_package opam_opts (Binary_repo.repo repo) ~pkg:name ~ver opam
