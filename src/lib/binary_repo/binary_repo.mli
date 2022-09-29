(** A repository for binary packages. Stores the repository files and the
    sources archives. *)

open Bos

type t

val init : name:string -> Fpath.t -> (t, 'e) OS.result
val repo : t -> Repo.t

val archive_path : t -> Binary_package.full_name -> Fpath.t
(** A path to write an archve to. *)

val has_binary_pkg : t -> Binary_package.full_name -> bool
(** Whether the repository already contain the binary version of a package. *)

val add_binary_package :
  t ->
  Binary_package.full_name ->
  Binary_package.binary_pkg ->
  (unit, 'e) OS.result
(** Add a binary package to the repository. See
    {!Binary_package.make_binary_package}. *)
