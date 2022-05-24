open Bos_setup

module Config : sig
  module Var : sig
    val get : ?switch:string -> string -> (string, [> `Msg of string ]) result
  end
end

module Switch : sig
  val list : unit -> (string list, [> Rresult.R.msg ]) result

  val create :
    ?ocaml_version:string -> string -> (unit, [> `Msg of string ]) result

  val remove : string -> (string, [> `Msg of string ]) result
end

module Repository : sig
  val add : url:string -> string -> (unit, [> `Msg of string ]) result
  val remove : string -> (unit, [> `Msg of string ]) result
end

module Show : sig
  val list_files :
    ?switch:string -> string -> (string list, [> `Msg of string ]) result

  val available_versions :
    ?switch:string -> string -> (string list, [> `Msg of string ]) result

  val installed_version :
    ?switch:string -> string -> (string, [> `Msg of string ]) result

  val depends :
    ?switch:string -> string -> (string list, [> `Msg of string ]) result

  val version :
    ?switch:string -> string -> (string list, [> `Msg of string ]) result
end

val install :
  ?switch:string -> string list -> (unit, [> `Msg of string ]) result
(** [install atoms] installs the [atoms] into the current local switch. If opam
    has not been initialised, or if their is no local switch this function will
    also create those too. *)

val remove : ?switch:string -> string list -> (unit, [> `Msg of string ]) result
(** [remove atoms] removes the [atoms] from the current local switch. Returns
    the list of package removed. *)

val update : ?switch:string -> string list -> (unit, [> `Msg of string ]) result
(** [update names] updates the repositories by their [names] that the current
    local switch has set. *)

val upgrade :
  ?switch:string -> string list -> (unit, [> `Msg of string ]) result
(** [upgrade atoms] will try to upgrade the packages whilst keeping [atoms]
    installed. *)

val root : Fpath.t
val check_init : unit -> (unit, [> `Msg of string ]) result
