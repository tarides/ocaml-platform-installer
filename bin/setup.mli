val local_cmd : int Cmdliner.Cmd.t
(** The command that does the full set-up of installing and initializing opam,
    creating a local switch and populating it with all platform tools and
    installing all project dependencies in there. The project directory the
    switch is for can be speficied as an argument; if none is specified, we use
    the current working directory. Each of the mentioned steps is only realized
    if its result doesn't already exist. *)

val global_cmd : int Cmdliner.Cmd.t
(** The command that does the full set-up of installing and initializing opam,
    creating a global switch and populating it with all platform tools. The
    compiler for the switch can be specified as an argument; if none is
    specified, we use the latest stable compiler. Each of the mentioned steps is
    only realized if its result doesn't already exist. *)
