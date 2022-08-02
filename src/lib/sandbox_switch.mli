open Import

type t

val install :
  Opam.GlobalOpts.t ->
  t ->
  pkg:string * string option ->
  (unit, 'e) Result.or_msg

val list_files :
  Opam.GlobalOpts.t -> t -> pkg:string -> (Fpath.t list, 'e) Result.or_msg

val switch_path_prefix : t -> Fpath.t

val with_sandbox_switch :
  Opam.GlobalOpts.t ->
  ocaml_version:string ->
  (t -> ('a, 'e) Result.or_msg) ->
  ('a, 'e) Result.or_msg
(** Create a sandbox switch, call the passed function and finally remove the
    switch. The version of OCaml is the same as the current switch. The
    [ocaml_version] argument must correspond to the version installed in the
    current switch. *)
