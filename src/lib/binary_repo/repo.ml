open Bos
open Rresult

type t = { name : string; path : Fpath.t }

let opam_version = "2.0"
let name t = t.name
let path t = t.path

let init_repo path =
  OS.Dir.create path >>= fun _ ->
  OS.Dir.create (Fpath.add_seg path "packages") >>= fun _ ->
  OS.File.writef
    (Fpath.add_seg path "repo")
    {|
    opam-version: "%s"
  |}
    opam_version

let init ~name path =
  OS.Dir.exists path >>= fun initialized ->
  let repo = { name; path } in
  if initialized then Ok repo else init_repo path >>= fun _ -> Ok repo

let repo_path_of_pkg t pkg =
  Fpath.(t.path / "packages" / Package.name pkg / Package.to_string pkg)

let has_pkg t pkg =
  match OS.Dir.exists (repo_path_of_pkg t pkg) with
  | Ok r -> r
  | Error _ -> false

let add_package t pkg ?(extra_files = []) ?install_file opam =
  let repo_path = repo_path_of_pkg t pkg in
  OS.Dir.create repo_path >>= fun _ ->
  let files_dir = Fpath.(repo_path / "files") in
  let write_extra_file file_name content =
    OS.Dir.create files_dir >>= fun _ ->
    OS.File.write Fpath.(files_dir / file_name) content
  in
  (match install_file with
  | Some f ->
      write_extra_file
        (Package.name pkg ^ ".install")
        (Package.Install_file.to_string f)
  | None -> Ok ())
  >>= fun () ->
  List.fold_left
    (fun acc (path, contents) ->
      acc >>= fun () -> write_extra_file path contents)
    (Ok ()) extra_files
  >>= fun () ->
  OS.File.writef
    Fpath.(repo_path / "opam")
    "%s"
    (Package.Opam_file.to_string opam)
