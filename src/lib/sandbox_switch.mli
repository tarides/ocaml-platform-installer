open Rresult

type t

val ocaml_version : t -> Ocaml_version.t
val init : ocaml_version:Ocaml_version.t -> (t, [> R.msg ]) result
val pin : t -> pkg:string -> url:string -> (unit, [> R.msg ]) result
val install : t -> pkgs:string list -> (unit, [> R.msg ]) result
val list_files : t -> pkg:string -> (Fpath.t list, [> R.msg ]) result
val switch_path_prefix : t -> Fpath.t
