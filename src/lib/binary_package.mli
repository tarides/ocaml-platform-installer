open Import
open Bos

module Binary_repo : sig
  type t

  val init : Fpath.t -> (t, 'e) Result.or_msg
  val repo : t -> Repo.t
end

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
