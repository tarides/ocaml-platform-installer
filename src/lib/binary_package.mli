(** Make a binary package out of a package built in the {!Sandbox_switch}.
    Package definitions and source archives are stored in {!Binary_repo}. *)

open! Import

type full_name

val binary_name :
  ocaml_version:Ocaml_version.t ->
  name:string ->
  ver:string ->
  pure_binary:bool ->
  full_name

val to_string : full_name -> string
val name : full_name -> string
val ver : full_name -> string
val package : full_name -> Package.full_name

val make_binary_package :
  Opam.GlobalOpts.t ->
  ocaml_version:Ocaml_version.t ->
  Sandbox_switch.t ->
  Fpath.t ->
  full_name ->
  name:string ->
  pure_binary:bool ->
  (Package.Opam_file.t, 'e) Result.or_msg
(** Make a binary package from the result of installing a package in the sandbox
    switch. *)
