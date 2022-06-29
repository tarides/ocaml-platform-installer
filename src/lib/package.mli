open Astring

type full_name

val v : name:string -> ver:string -> full_name
val to_string : full_name -> string
val name : full_name -> string
val ver : full_name -> string

module Opam_file : sig
  (** Package description. *)

  type t
  type cmd = string list

  type dep = string * ([ `Eq | `Geq | `Gt | `Leq | `Lt | `Neq ] * string) list
  (** [name * (operator * constraint) option]. *)

  val v :
    ?install:cmd list ->
    ?depends:dep list ->
    ?conflicts:string list ->
    ?url:Fpath.t ->
    pkg_name:string ->
    unit ->
    t

  val to_string : t -> string
end

module Install_file : sig
  type t

  val v : (string * string option) list String.Map.t -> pkg_name:string -> t
  val to_string : t -> string
end
