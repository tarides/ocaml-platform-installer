(** A repository for binary packages. Stores the repository files and the
    sources archives. *)

open Import

type t

val init : Opam.GlobalOpts.t -> Fpath.t -> (t, 'e) Result.or_msg
val repo : t -> Repo.t

val archive_path : t -> unique_name:string -> Fpath.t
(** A path to write an archve to. *)

val has_binary_pkg : t -> Binary_package.full_name -> bool
(** Whether the repository already contain the binary version of a package. *)

val add_binary_package :
  Opam.GlobalOpts.t ->
  ocaml_version:Ocaml_version.t ->
  Sandbox_switch.t ->
  t ->
  Binary_package.full_name ->
  name:string ->
  pure_binary:bool ->
  (unit, 'e) Result.or_msg
(** Make a binary package from the result of installing a package in the sandbox
    switch. *)
