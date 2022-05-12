open Rresult

type t

val ocaml_version : t -> string
val init : ocaml_version:string -> (t, [> R.msg ]) result
val pin : t -> pkg:string -> url:string -> (unit, [> R.msg ]) result
val install : t -> pkgs:string list -> (unit, [> R.msg ]) result
val list_files : t -> pkg:string -> (Fpath.t list, [> R.msg ]) result
val switch_path_prefix : t -> Fpath.t
