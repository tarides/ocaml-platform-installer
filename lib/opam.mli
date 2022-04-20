val install : yes:bool -> unit -> (unit, [> Rresult.R.msg ]) result
(** Installs opam (currently by executing the opam shell script)*)

val is_installed : unit -> bool
(** Checks if opam is already installed or not.*)

val init : yes:bool -> unit -> (unit, [> Rresult.R.msg ]) result
(** Initializes opam without setting up a switch *)

val is_initialized : unit -> bool
(** Checks if opam is already initialized or not.*)

type switch = Local of string | Global of string
(* FIXME: use Fpath.t for the parameter of [Local] and something like ... for the parameter of [Global]. *)

val make_switch :
  yes:bool -> switch -> unit -> (unit, [> Rresult.R.msg ]) result
(** [make_switch switch] creates a switch [switch]. If the switch is local, it
    also installs the project dependencies, including test dependencies. *)

val switch_exists : switch -> bool
(** Checks if the given switch already exists. *)
