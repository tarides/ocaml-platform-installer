open Import

type t
(** Represent the cache repositories for binary packages. The global cache is
    stored inside the Opam root. There can be a second, temporary repository for
    packages that can't be stored in the global cache (eg. because building for
    a pinned compiler). *)

val load : Opam.GlobalOpts.t -> pinned:bool -> (t, 'e) Result.or_msg
(** Manage initialisation of the cache repository.

    When building for a pinned compiler (indicated by [~pinned:true]), a local
    repository is used instead of the global cache for storing the new packages.
    The repository is stored in [<switch-prefix>/var/cache/ocaml-platform], and
    its name is computed from [<switch-prefix>]. *)

val has_binary_pkg :
  t -> ocaml_version_dependent:bool -> Binary_package.full_name -> bool
(** Whether the given package is already in cache and doesn't need to be
    rebuilt.

    In case of a pinned compiler (indicated by passing [~pinned:true] to
    {!load}), packages that depend on the version of OCaml (indicated by
    [~ocaml_version_dependent:true]) are never cached (always rebuilt). *)

val push_repo : t -> Binary_repo.t
(** The repository in which to add newly built packages. *)

val enable_repos : Opam.GlobalOpts.t -> t -> (unit, 'e) Result.or_msg
(** [with_repos_enabled cache f] calls [f] with the global and the push repo
    enabled. *)
