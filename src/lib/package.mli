type full_name

val v : name:string -> ver:string -> full_name
val to_string : full_name -> string
val name : full_name -> string
val ver : full_name -> string

module FilesGenerator : sig
  val field :
    Format.formatter -> string -> (Format.formatter -> 'a -> unit) -> 'a -> unit

  val field_opt :
    Format.formatter ->
    string ->
    (Format.formatter -> 'a -> unit) ->
    'a option ->
    unit

  val gen_list :
    (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a list -> unit

  val gen_string : Format.formatter -> string -> unit

  val gen_option :
    (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a option -> unit

  val gen_field_with_opt :
    (Format.formatter -> 'a -> unit) ->
    (Format.formatter -> 'b -> unit) ->
    Format.formatter ->
    'a * 'b option ->
    unit
end

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
    unit ->
    t

  val fprintf : t -> unit Fmt.t
end
