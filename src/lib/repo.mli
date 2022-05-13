(** Manage an Opam repository and create package descriptions. The repository is
    registered into Opam. *)

open Bos
open Import

module Opam_file : sig
  (** Package description. *)

  type t
  type cmd = string list

  type dep = string * (string * string) option
  (** [name * (operator * constraint) option]. *)

  val v :
    ?install:cmd list ->
    ?depends:dep list ->
    ?conflicts:string list ->
    ?url:Fpath.t ->
    t
end

type t

val init : name:string -> Fpath.t -> (t, 'e) Result.or_msg
(** If the repository already exists, simply return a value of {!t}. If it
    doesn't exist, it is initialized and registered into Opam. The repository
    isn't added to the selection of any switch. *)

val has_pkg : t -> pkg:string -> ver:string -> bool
(** Whether a specific version of a package exists in the repository. *)

val add_package :
  t -> pkg:string -> ver:string -> Opam_file.t -> (unit, 'e) OS.result

val with_repo_enabled : t -> (unit -> (('a, 'e) OS.result as 'r)) -> 'r
