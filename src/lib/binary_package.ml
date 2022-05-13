open Import
open Result.Syntax
open Astring
open Bos

module Binary_repo = struct
  type t = { repo : Repo.t; archive : Fpath.t }

  let init base_path =
    let repo_path = Fpath.( / ) base_path "repo" in
    let+ repo = Repo.init ~name:"platform-cache" repo_path in
    let archive = Fpath.( / ) base_path "archives" in
    { repo; archive }

  let repo t = t.repo
end

type name = string * string

(** Name and version of the binary package corresponding to a given package. *)
let binary_name sandbox ~name ~ver =
  let ocaml_version = Sandbox_switch.ocaml_version sandbox in
  (name ^ "+cached", ver ^ "-ocaml" ^ Ocaml_version.to_string ocaml_version)

let name_to_string (name, ver) = name ^ "." ^ ver

let has_binary_package repo (name, ver) =
  Repo.has_pkg repo.Binary_repo.repo ~pkg:name ~ver

let generate_opam_file original_name archive_path ocaml_version =
  Repo.Opam_file.v
    ~install:[ [ "cp"; "-aT"; "."; "%{prefix}%" ] ]
    ~depends:[ ("ocaml", Some ("=", Ocaml_version.to_string ocaml_version)) ]
    ~conflicts:[ original_name ] ~url:archive_path

let should_remove = Fpath.(is_prefix (v "lib"))

let process_path prefix path =
  match Fpath.rem_prefix prefix path with
  | None -> None
  | Some path ->
      if should_remove path then None else Some Fpath.(base prefix // path)

(** Binary is already in the sandbox. Add this binary as a package in the local
    repo *)
let make_binary_package sandbox repo ((pkg, ver) as bname) ~tool_name =
  let prefix = Sandbox_switch.switch_path_prefix sandbox in
  (* TODO *)
  let archive_path =
    Fpath.( / ) repo.Binary_repo.archive (name_to_string bname ^ ".tar.gz")
  in
  Sandbox_switch.list_files sandbox ~pkg:tool_name >>= fun paths ->
  let paths =
    List.filter_map (process_path prefix) paths
    |> List.map Fpath.to_string |> String.concat ~sep:"\n"
  in
  OS.Dir.create (Fpath.parent archive_path) >>= fun _ ->
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
    let opam =
      generate_opam_file tool_name archive_path
        (Sandbox_switch.ocaml_version sandbox)
    in
    Repo.add_package repo.Binary_repo.repo ~pkg ~ver opam
