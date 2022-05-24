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
