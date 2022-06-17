open Import
open Result.Syntax
open Bos

type t = { repo : Repo.t; archive : Fpath.t }

let init opam_opts base_path =
  let repo_path = Fpath.(base_path / "repo") in
  let* repo = Repo.init opam_opts ~name:"platform-cache" repo_path in
  let archive = Fpath.( / ) base_path "archives" in
  let* _ = OS.Dir.create archive in
  Ok { repo; archive }

let repo t = t.repo
let archive_path t ~unique_name = Fpath.( / ) t.archive unique_name

let has_binary_pkg repo pack =
  Repo.has_pkg repo.repo (Binary_package.package pack)

(** Binary is already in the sandbox. Add this binary as a package in the local
    repo *)
let add_binary_package opam_opts ~ocaml_version sandbox repo bpack
    ~name:query_name ~pure_binary =
  let archive_path =
    archive_path repo ~unique_name:(Binary_package.to_string bpack ^ ".tar.gz")
  in
  let* install, opam =
    Binary_package.make_binary_package opam_opts ~ocaml_version sandbox
      archive_path bpack ~name:query_name ~pure_binary
  in
  Repo.add_package opam_opts repo.repo
    (Binary_package.package bpack)
    install opam
