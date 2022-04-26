(** Opam options common to every commands. *)
type opam_options = { yes : bool; root : Fpath.t }

val install : unit -> (unit, [> `Msg of string ]) result
(** Installs opam (currently by executing the opam shell script). Returns an
    error if Opam is already installed. *)

val is_installed : unit -> (bool, [> `Msg of string ]) result
(** Checks if opam is already installed or not. *)

val init : opam_options -> unit -> (unit, [> `Msg of string ]) result
(** Initializes opam without setting up a switch *)

val is_initialized : opam_options -> bool
(** Checks if opam is already initialized or not.*)

(** A [Bos.Cmd] for calling Opam, the second argument is the sub-command to
    call. Takes care of passing [opam_options]. *)
val opam_cmd : opam_options -> string -> Bos.Cmd.t

type switch = Local of string | Global of string
(* FIXME: use Fpath.t for the parameter of [Local] and something like ... for the parameter of [Global]. *)

val make_switch :
  opam_options -> switch -> unit -> (unit, [> `Msg of string ]) result
(** [make_switch switch] creates a switch [switch]. If the switch is local, it
    also installs the project dependencies, including test dependencies. *)

val switch_exists : opam_options -> switch -> bool
(** Checks if the given switch already exists. *)
