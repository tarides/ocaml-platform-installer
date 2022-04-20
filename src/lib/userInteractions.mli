val errorf : ('a, out_channel, unit) format -> 'a
(** Prints an error to stderr (well, not yet. currently just prints it) *)

val logf : ('a, out_channel, unit) format -> 'a
(** Logs to stdout *)

val prompt : (unit, out_channel, unit) format -> bool
(** [prompt question] starts a prompt asking the user [question]. It returns
    [true] and [false] if the user answers [yes] and [no], respectively *)
