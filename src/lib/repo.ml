open Bos
open Import

type t = { name : string; path : Fpath.t }

let opam_version = "2.0"

let init_repo path =
  let open Result.Syntax in
  let* _ = OS.Dir.create path in
  OS.Dir.create (Fpath.add_seg path "packages") >>= fun _ ->
  OS.File.writef
    (Fpath.add_seg path "repo")
    {|
    opam-version: "%s"
  |}
    opam_version

let init opam_opts ~name path =
  let open Result.Syntax in
  let* initialized = OS.Dir.exists path in
  let repo = { name; path } in
  if initialized then Ok repo
  else
    let* _ = init_repo path in
    let* () = Opam.Repository.add opam_opts ~url:(Fpath.to_string path) name in
    Ok repo

let repo_path_of_pkg t pkg =
  Fpath.(t.path / "packages" / Package.name pkg / Package.to_string pkg)

let has_pkg t pkg =
  match OS.Dir.exists (repo_path_of_pkg t pkg) with
  | Ok r -> r
  | Error _ -> false

let add_package opam_opts t pkg install opam =
  let open Result.Syntax in
  let repo_path = repo_path_of_pkg t pkg in
  let* _ = OS.Dir.create repo_path in
  let* _ = OS.Dir.create Fpath.(repo_path / "files") in
  let* () =
    match install with
    | None -> Ok ()
    | Some install ->
        OS.File.writef
          Fpath.(repo_path / "files" / (Package.name pkg ^ ".install"))
          "%s"
          (Package.Install_file.to_string install)
  in
  let* () =
    OS.File.writef
      Fpath.(repo_path / "opam")
      "%s"
      (Package.Opam_file.to_string opam)
  in

  Opam.update opam_opts [ t.name ]

let with_repo_enabled opam_opts t f =
  let open Result.Syntax in
  let unselect_repo () = ignore @@ Opam.Repository.remove opam_opts t.name in
  let* () =
    Opam.Repository.add opam_opts ~url:(Fpath.to_string t.path) t.name
  in
  Fun.protect ~finally:unselect_repo f
