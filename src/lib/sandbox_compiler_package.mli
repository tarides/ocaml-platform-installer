open Import

val init : Opam.GlobalOpts.t -> string -> (Repo.t, 'e) Result.or_msg
(** [init opam_opts ocaml_version] creates (if needed) a repo containing a
    patched version of [ocaml-system] working well with the sandbox switch. *)
