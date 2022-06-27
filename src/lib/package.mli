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
    opam_version:string ->
    pkg_name:string ->
    unit ->
    t

  val to_string : t -> string
end

module Install_file : sig
  type t

  val v :
    ?lib:(string * string option) list ->
    ?lib_root:(string * string option) list ->
    ?libexec:(string * string option) list ->
    ?libexec_root:(string * string option) list ->
    ?bin:(string * string option) list ->
    ?sbin:(string * string option) list ->
    ?toplevel:(string * string option) list ->
    ?share:(string * string option) list ->
    ?share_root:(string * string option) list ->
    ?etc:(string * string option) list ->
    ?doc:(string * string option) list ->
    ?stublibs:(string * string option) list ->
    ?man:(string * string option) list ->
    ?misc:(string * string option) list ->
    pkg_name:string ->
    unit ->
    t

  val to_string : t -> string
end
