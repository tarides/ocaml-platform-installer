(** Manage an Opam repository and create package descriptions. *)

open Bos

type t

val name : t -> string
val path : t -> Fpath.t

val init : name:string -> Fpath.t -> (t, 'e) OS.result
(** If the repository already exists, simply return a value of {!t}. If it
    doesn't exist, it is initialized and registered into Opam. The repository
    isn't added to the selection of any switch. *)

val has_pkg : t -> Package.full_name -> bool
(** Whether a specific version of a package exists in the repository. *)

val add_package :
  t ->
  Package.full_name ->
  ?extra_files:(string * string) list ->
  Package.Install_file.t ->
  Package.Opam_file.t ->
  (unit, 'e) OS.result
(** [add_package opam_opts repo pkg ~extra_files install_file opam_file] adds a
    package to the repo. [extra_files] is a list of [ filename * content] to be
    put under [files/] folder *)
