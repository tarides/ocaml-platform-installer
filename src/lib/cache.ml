open! Import
open Bos
open Result.Syntax

type t = { global_repo : Binary_repo.t; push_repo : Binary_repo.t option }

let load opam_opts ~pinned f =
  let global_binary_repo_path =
    Fpath.(
      opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform" / "cache")
  in
  let* global_repo =
    Binary_repo.init ~name:"platform-cache" global_binary_repo_path
  in
  if pinned then (
    (* Pinned compiler: don't actually cache the result by using a temporary
       repository. *)
    Logs.app (fun m -> m "* Pinned compiler detected. Caching is disabled.");
    Result.join
    @@ OS.Dir.with_tmp "ocaml-platform-pinned-cache-%s"
         (fun tmp_path () ->
           let name =
             "ocaml-platform-pinned-cache-" ^ Fpath.to_string tmp_path
           in
           let* push_repo = Binary_repo.init ~name tmp_path in
           f { global_repo; push_repo = Some push_repo })
         ())
  else (* Otherwise, use the global cache. *)
    f { global_repo; push_repo = None }

let push_repo t = Option.value t.push_repo ~default:t.global_repo

let pull_repo ~ocaml_version_dependent t =
  if ocaml_version_dependent then push_repo t else t.global_repo

let with_repos_enabled opam_opts t f =
  (* Add the global repository first. The last repo added will be looked up
     first. *)
  let repos = t.global_repo :: Option.to_list t.push_repo in
  List.fold_left
    (fun k repo () ->
      let repo = Binary_repo.repo repo in
      Installed_repo.with_repo_enabled opam_opts repo @@ fun () ->
      let* () = Installed_repo.update opam_opts repo in
      k ())
    f repos ()
