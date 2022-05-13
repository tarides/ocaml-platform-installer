(** Make a binary package out of a package built in the {!Sandbox_switch}.
    Package definitions and source archives are stored in {!Binary_repo}. *)

open! Import
open Bos

type t

val binary_name : Sandbox_switch.t -> name:string -> ver:string -> t
val name_to_string : t -> string

val has_binary_package : Binary_repo.t -> t -> bool
(** Whether the repository already contain the binary version of a package. *)

val make_binary_package :
  Sandbox_switch.t ->
  Binary_repo.t ->
  t ->
  tool_name:string ->
  (unit, 'e) OS.result
(** Make a binary package from the result of installing a package in the sandbox
    switch. *)
