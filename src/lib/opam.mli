type opam_options = { yes : bool; root : Fpath.t }
(** Opam options common to every commands. *)

val install : unit -> (unit, [> `Msg of string ]) result
(** Installs opam (currently by executing the opam shell script). Returns an
    error if Opam is already installed. *)

val is_installed : unit -> (bool, [> `Msg of string ]) result
(** Checks if opam is already installed or not. *)

val init : opam_options -> unit -> (unit, [> `Msg of string ]) result
(** Initializes opam without setting up a switch *)

val is_initialized : opam_options -> bool
(** Checks if opam is already initialized or not.*)

val opam_cmd : opam_options -> string -> Bos.Cmd.t
(** A [Bos.Cmd] for calling Opam, the second argument is the sub-command to
    call. Takes care of passing [opam_options]. *)
