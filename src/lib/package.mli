type full_name

val v : name:string -> ver:string -> full_name
val to_string : full_name -> string
val name : full_name -> string
val ver : full_name -> string

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
    opam_version:string ->
    pkg_name:string ->
    t

  val fprintf : t -> unit Fmt.t
end
