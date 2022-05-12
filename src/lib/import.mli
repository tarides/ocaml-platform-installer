(** Adding convenience functions to the standard library to favor a consistent
    code style throughout the project. Let's [open!] this in every module. *)

module Result : sig
  include module type of Result

  module Syntax : sig
    val ( let+ ) : ('a, 'b) t -> ('a -> 'c) -> ('c, 'b) t
    val ( let* ) : ('a, 'b) t -> ('a -> ('c, 'b) t) -> ('c, 'b) t
    val ( >>| ) : ('a, 'b) t -> ('a -> 'c) -> ('c, 'b) t
    val ( >>= ) : ('a, 'b) t -> ('a -> ('c, 'b) t) -> ('c, 'b) t
  end

  val iter_until : ('a -> (unit, 'b) result) -> 'a list -> (unit, 'b) result
end
