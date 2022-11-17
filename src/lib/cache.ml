open! Import
open Result.Syntax

type t = {
  global_repo : Binary_repo.t;
  push_repo : Binary_repo.t option;
      (** [Some _] in case of a pinned compiler, [None] otherwise. *)
}

let load opam_opts ~pinned =
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
    let* switch_path =
      let+ switch_prefix = Opam.Config.Var.get opam_opts "prefix" in
      Fpath.(v switch_prefix / "var" / "cache" / "ocaml-platform")
    in
    let hash = Hashtbl.hash switch_path in
    let name = Printf.sprintf "ocaml-platform-pinned-cache-%d" hash in
    let+ push_repo = Binary_repo.init ~name switch_path in
    { global_repo; push_repo = Some push_repo })
  else
    (* Otherwise, use the global cache. *)
    Ok { global_repo; push_repo = None }

let has_binary_pkg t ~ocaml_version_dependent bname =
  if ocaml_version_dependent && Option.is_some t.push_repo then false
  else Binary_repo.has_binary_pkg t.global_repo bname

let push_repo t = Option.value t.push_repo ~default:t.global_repo

let enable_repos opam_opts t =
  (* Add the global repository first. The last repo added will be looked up
     first. *)
  let repos = t.global_repo :: Option.to_list t.push_repo in
  Result.List.fold_left
    (fun () repo ->
      let repo = Binary_repo.repo repo in
      let* () = Installed_repo.enable_repo opam_opts repo in
      Installed_repo.update opam_opts repo)
    () repos
