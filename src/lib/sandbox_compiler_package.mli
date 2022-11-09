open Import

val with_sandbox_compiler_repo :
  Opam.GlobalOpts.t ->
  string ->
  (string -> ('a, ([> Result.msg ] as 'e)) result) ->
  ('a, 'e) result
(** [init opam_opts ocaml_version f] creates a temporary repo containing a
    patched version of [ocaml-system] working well with the sandbox switch. The
    name of the compiler package is given to [f]. *)
