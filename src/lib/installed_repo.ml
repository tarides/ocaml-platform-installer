open Rresult

let update opam_opts t = Opam.update opam_opts [ Repo.name t ]

let with_repo_enabled opam_opts t f =
  let repo_name = Repo.name t and repo_path = Repo.path t in
  let unselect_repo () = ignore @@ Opam.Repository.remove opam_opts repo_name in
  Opam.Repository.add opam_opts ~url:(Fpath.to_string repo_path) repo_name
  >>= fun () -> Fun.protect ~finally:unselect_repo f
