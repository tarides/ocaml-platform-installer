open Bos
open Rresult

type t = { repo : Repo.t; archive : Fpath.t }

let init base_path =
  let repo_path = Fpath.(base_path / "repo") in
  Repo.init ~name:"platform-cache" repo_path >>= fun repo ->
  let archive = Fpath.( / ) base_path "archives" in
  OS.Dir.create archive >>= fun _ -> Ok { repo; archive }

let repo t = t.repo

let archive_path t bname =
  Fpath.( / ) t.archive (Binary_package.to_string bname ^ ".tar.gz")

let has_binary_pkg repo pack =
  Repo.has_pkg repo.repo (Binary_package.package pack)

(** Binary is already in the sandbox. Add this binary as a package in the local
    repo *)
let add_binary_package repo bpack (install_file, opam) =
  Repo.add_package repo.repo (Binary_package.package bpack) ~install_file opam
