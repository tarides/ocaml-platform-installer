open Bos_setup

module GlobalOpts : sig
  type t = { root : Fpath.t; switch : string option }

  val v : root:Fpath.t -> ?switch:string -> unit -> t
  val default : t
end

module Config : sig
  module Var : sig
    val get : GlobalOpts.t -> string -> (string, [> `Msg of string ]) result
  end
end

module Switch : sig
  val list : GlobalOpts.t -> (string list, [> Rresult.R.msg ]) result

  val create :
    ?ocaml_version:string ->
    GlobalOpts.t ->
    string ->
    (unit, [> `Msg of string ]) result

  val remove : GlobalOpts.t -> string -> (string, [> `Msg of string ]) result
end

module Repository : sig
  val add :
    GlobalOpts.t -> url:string -> string -> (unit, [> `Msg of string ]) result

  val remove : GlobalOpts.t -> string -> (unit, [> `Msg of string ]) result
end

module Show : sig
  val list_files :
    GlobalOpts.t -> string -> (string list, [> `Msg of string ]) result

  val available_versions :
    GlobalOpts.t -> string -> (string list, [> `Msg of string ]) result

  val installed_version :
    GlobalOpts.t -> string -> (string, [> `Msg of string ]) result

  val depends :
    GlobalOpts.t -> string -> (string list, [> `Msg of string ]) result

  val version :
    GlobalOpts.t -> string -> (string list, [> `Msg of string ]) result
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
