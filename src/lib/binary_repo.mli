(** A repository for binary packages. Stores the repository files and the
    sources archives. *)

open Import

type t

val init : Fpath.t -> (t, 'e) Result.or_msg
val repo : t -> Repo.t

val archive_path : t -> unique_name:string -> Fpath.t
(** A path to write an archve to. *)
