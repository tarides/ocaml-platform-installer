open Bos_setup
open Import

module GlobalOpts : sig
  type t = {
    root : Fpath.t;
    switch : string option;  (** Whether to pass the [--switch] option. *)
    env : string String.map option;
        (** Environment to use when calling commands. *)
  }

  val v : root:Fpath.t -> ?switch:string -> ?env:string String.map -> unit -> t
  val default : t
end

module Config : sig
  module Var : sig
    val get : GlobalOpts.t -> string -> (string, 'e) Result.or_msg
    val get_opt : GlobalOpts.t -> string -> (string option, 'e) Result.or_msg

    val set :
      GlobalOpts.t ->
      global:bool ->
      string ->
      string ->
      (unit, 'e) Result.or_msg

    val unset :
      GlobalOpts.t -> global:bool -> string -> (unit, 'e) Result.or_msg
  end
end

module Switch : sig
  val list : GlobalOpts.t -> (string list, [> Rresult.R.msg ]) result

  val create :
    ocaml_version:string option ->
    GlobalOpts.t ->
    string ->
    (unit, [> `Msg of string ]) result
  (** When [ocaml_version] is [None], create a switch with no compiler
      installed. *)

  val remove : GlobalOpts.t -> string -> (string, [> `Msg of string ]) result
end

module Repository : sig
  val add :
    GlobalOpts.t -> url:string -> string -> (unit, [> `Msg of string ]) result

  val remove : GlobalOpts.t -> string -> (unit, [> `Msg of string ]) result
end

module Queries : sig
  val init : unit -> unit

  val files_installed_by_pkg :
    string ->
    'lock OpamStateTypes.switch_state ->
    (string list, [> `Msg of string ]) result

  val get_pkg_universe :
    'lock OpamStateTypes.switch_state -> OpamTypes.package_set lazy_t

  val get_metadata_universe :
    'lock OpamStateTypes.switch_state -> OpamFile.OPAM.t OpamTypes.package_map

  val latest_version :
    metadata_universe:OpamFile.OPAM.t OpamTypes.package_map ->
    pkg_universe:OpamTypes.package_set ->
    ocaml:OpamPackage.t ->
    string ->
    OpamPackage.t option

  val installed_versions :
  string list ->
    OpamTypes.switch_selections -> (string * OpamPackage.t option) list

  val with_switch_state :
    ?dir_name:Fpath.t ->
    ([< OpamStateTypes.unlocked > `Lock_read `Lock_write ]
     OpamStateTypes.switch_state ->
    'a) ->
    'a

  val with_switch_state_sel :  ?dir_name:Fpath.t -> (OpamTypes.switch_selections -> 'a) -> 'a

  val with_virtual_state :
    (OpamStateTypes.unlocked OpamStateTypes.switch_state -> 'a) -> 'a
end

module Conversions : sig
  val version_of_pkg : OpamPackage.t -> string
end

val install : GlobalOpts.t -> string list -> (unit, [> `Msg of string ]) result
(** [install atoms] installs the [atoms] into the current local switch. If opam
    has not been initialised, or if their is no local switch this function will
    also create those too. *)

val remove : GlobalOpts.t -> string list -> (unit, [> `Msg of string ]) result
(** [remove atoms] removes the [atoms] from the current local switch. Returns
    the list of package removed. *)

val update : GlobalOpts.t -> string list -> (unit, [> `Msg of string ]) result
(** [update names] updates the repositories by their [names] that the current
    local switch has set. *)

val upgrade : GlobalOpts.t -> string list -> (unit, [> `Msg of string ]) result
(** [upgrade atoms] will try to upgrade the packages whilst keeping [atoms]
    installed. *)

val check_init : unit -> (unit, [> `Msg of string ]) result
