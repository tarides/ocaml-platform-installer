(** Make a binary package out of a package built in the {!Sandbox_switch}.
    Package definitions and source archives are stored in {!Binary_repo}. *)

open Bos

type full_name

val binary_name :
  ocaml_version:string ->
  name:string ->
  ver:string ->
  pure_binary:bool ->
  full_name

val to_string : full_name -> string
val name : full_name -> string
val ver : full_name -> string
val package : full_name -> Package.full_name

type binary_pkg = Package.Install_file.t * Package.Opam_file.t

val make_binary_package :
  ocaml_version:string ->
  arch:string ->
  os_distribution:string ->
  prefix:Fpath.t ->
  files:Fpath.t list ->
  archive_path:Fpath.t ->
  full_name ->
  name:string ->
  pure_binary:bool ->
  (binary_pkg, 'e) OS.result
(** Make a binary package from the result of installing a package in the sandbox
    switch. *)
