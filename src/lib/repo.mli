(** Manage an Opam repository and create package descriptions. The repository is
    registered into Opam. *)

open Bos
open Import

type t

val init : Opam.GlobalOpts.t -> name:string -> Fpath.t -> (t, 'e) Result.or_msg
(** If the repository already exists, simply return a value of {!t}. If it
    doesn't exist, it is initialized and registered into Opam. The repository
    isn't added to the selection of any switch. *)

val has_pkg : t -> Package.full_name -> bool
(** Whether a specific version of a package exists in the repository. *)

val add_package :
  Opam.GlobalOpts.t ->
  t ->
  Package.full_name ->
  Package.Install_file.t option ->
  Package.Opam_file.t ->
  (unit, 'e) OS.result

val with_repo_enabled :
  Opam.GlobalOpts.t -> t -> (unit -> (('a, 'e) OS.result as 'r)) -> 'r
