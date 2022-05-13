open Bos
open Import

module Opam_file : sig
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
val has_pkg : t -> pkg:string -> ver:string -> bool

val add_package :
  t -> pkg:string -> ver:string -> Opam_file.t -> (unit, 'e) OS.result

val with_repo_enabled : t -> (unit -> (('a, 'e) OS.result as 'r)) -> 'r
