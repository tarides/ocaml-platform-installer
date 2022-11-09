open Rresult

type t
(** Represent the cache repositories for binary packages. The global cache is
    stored inside the Opam root. There can be a second, temporary repository for
    packages that can't be stored in the global cache (eg. because building for
    a pinned compiler). *)

val load :
  Opam.GlobalOpts.t ->
  pinned:bool ->
  (t -> ('a, ([> R.msg ] as 'e)) result) ->
  ('a, 'e) result
(** Manage initialisation of the cache repository. When building for a pinned
    compiler (indicated by [~pinned:true]), an ephemeral repository is used
    instead of the global cache for storing the new packages. *)

val pull_repo : ocaml_version_dependent:bool -> t -> Binary_repo.t
(** The repository from which to check whether a package is installed. For a
    non-pinned compiler, this is always the global repository.

    In the case of a pinned compiler, packages that depend on the version of
    OCaml will get the [push_repo] here, which will certainly not contain the
    package. Such package can't be cached. *)

val push_repo : t -> Binary_repo.t
(** The repository in which to add newly built packages. *)

val with_repos_enabled :
  Opam.GlobalOpts.t ->
  t ->
  (unit -> ('a, ([> R.msg ] as 'e)) result) ->
  ('a, 'e) result
(** [with_repos_enabled cache f] calls [f] with the global and the push repo
    enabled. *)
