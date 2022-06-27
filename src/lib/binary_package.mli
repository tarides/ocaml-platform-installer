(** Make a binary package out of a package built in the {!Sandbox_switch}.
    Package definitions and source archives are stored in {!Binary_repo}. *)

open! Import

type t

val binary_name :
  ocaml:OpamPackage.t -> name:string -> ver:string -> pure_binary:bool -> t

val name_to_string : t -> string
val name : t -> string

val has_binary_package : Binary_repo.t -> t -> bool
(** Whether the repository already contain the binary version of a package. *)

val make_binary_package :
  Opam.GlobalOpts.t ->
  ocaml:OpamPackage.t ->
  Sandbox_switch.t ->
  Binary_repo.t ->
  t ->
  name:string ->
  pure_binary:bool ->
  (unit, 'e) Result.or_msg
(** Make a binary package from the result of installing a package in the sandbox
    switch. *)
