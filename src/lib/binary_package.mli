open Bos

type name

val binary_name : Sandbox_switch.t -> name:string -> ver:string -> name
val name_to_string : name -> string

val has_binary_package : Repo.t -> name -> bool
(** Whether the repository already contain the binary version of a package. *)

val make_binary_package :
  Sandbox_switch.t -> Repo.t -> name -> tool_name:string -> (unit, 'e) OS.result
(** Make a binary package from the result of installing a package in the sandbox
    switch. *)
