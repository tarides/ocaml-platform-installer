open Import

type t

val ocaml_version : t -> Ocaml_version.t
val init : ocaml_version:Ocaml_version.t -> (t, 'e) Result.or_msg
val pin : t -> pkg:string -> url:string -> (unit, 'e) Result.or_msg
val install : t -> pkg:string * string option -> (unit, 'e) Result.or_msg
val list_files : t -> pkg:string -> (Fpath.t list, 'e) Result.or_msg
val switch_path_prefix : t -> Fpath.t

val with_sandbox_switch :
  ocaml_version:Ocaml_version.t ->
  (t -> ('a, 'e) Result.or_msg) ->
  ('a, 'e) Result.or_msg
