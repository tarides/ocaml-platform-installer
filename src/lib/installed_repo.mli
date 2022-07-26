(** Register a {!Repo} into Opam. *)

open Bos

val update : Opam.GlobalOpts.t -> Repo.t -> (unit, 'e) OS.result
(** Notify Opam that the repository has been updated. *)

val with_repo_enabled :
  Opam.GlobalOpts.t -> Repo.t -> (unit -> (('a, 'e) OS.result as 'r)) -> 'r
(** Temporarily enable a repository in the selected switch. *)
