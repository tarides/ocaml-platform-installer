open Bos_setup

module Global : sig
  type t = OpamArg.global_options = {
    debug_level : int option;
    verbose : int;
    quiet : bool;
    color : OpamStd.Config.when_ option;
    opt_switch : string option;
    confirm_level : OpamStd.Config.answer option;
    yes : bool option;
    strict : bool;
    opt_root : OpamPath.t option;
    git_version : bool;
    external_solver : string option;
    use_internal_solver : bool;
    cudf_file : string option;
    solver_preferences : string option;
    best_effort : bool;
    safe_mode : bool;
    json : string option;
    no_auto_upgrade : bool;
    working_dir : bool;
    ignore_pin_depends : bool;
    cli : OpamCLIVersion.t;
  }

  val default : unit -> t
  val apply : t -> unit
end

module Switch : sig
  val install :
    ?opts:Global.t ->
    [ `Atom of OpamFormula.atom
    | `Dirname of OpamTypes.dirname
    | `Filename of OpamFilename.t ]
    list ->
    (unit, [> `Msg of string ]) result
  (** [install atoms] installs the [atoms] into the current local switch. If
      opam has not been initialised, or if their is no local switch this
      function will also create those too. *)

  val remove :
    ?opts:Global.t ->
    [ `Atom of OpamTypes.atom | `Dirname of OpamTypes.dirname ] list ->
    (OpamTypes.atom list, [> `Msg of string ]) result
  (** [remove atoms] removes the [atoms] from the current local switch. Returns
      the list of package removed. *)

  val update :
    ?opts:Global.t -> string list -> (unit, [> `Msg of string ]) result
  (** [update names] updates the repositories by their [names] that the current
      local switch has set. *)

  val upgrade :
    ?opts:Global.t ->
    [ `Atom of OpamFormula.atom | `Dirname of OpamPath.t ] list ->
    (unit, [> `Msg of string ]) result
  (** [upgrade atoms] will try to upgrade the packages whilst keeping [atoms]
      installed. *)
end

(* TODO: Abstract the switch_state into [Switch.t] and pass it to every
   functions of [Switch]. To avoid internally calling [check_init] and
   [Global.apply] many times. *)
val check_init :
  ?opts:OpamArg.global_options ->
  unit ->
  OpamStateTypes.rw OpamStateTypes.global_state
  * OpamStateTypes.unlocked OpamStateTypes.repos_state
  * OpamStateTypes.rw OpamStateTypes.switch_state

val install : unit -> (unit, [> `Msg of string ]) result
(** Installs opam (currently by executing the opam shell script). *)

val is_installed : unit -> (bool, [> `Msg of string ]) result
(** Checks if opam is already installed or not. *)

val opam_cmd : Cmd.t -> Cmd.t
(** A [Bos.Cmd] for calling Opam, the second argument is the sub-command to
    call. *)

val opam_run_s : Cmd.t -> (string, [> R.msg ]) result
(** A [Bos.Cmd] for calling Opam, the second argument is the sub-command to
    call. *)

val opam_run_l : Cmd.t -> (string list, [> R.msg ]) result
(** A [Bos.Cmd] for calling Opam, the second argument is the sub-command to
    call. *)

val opam_run : Cmd.t -> (unit, [> R.msg ]) result
(** A [Bos.Cmd] for calling Opam, the second argument is the sub-command to
    call. *)
