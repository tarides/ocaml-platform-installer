(** Adding convenience functions to the standard library to favor a consistent
    code style throughout the project. Let's [open!] this in every module. *)

module Result : sig
  include module type of Result

  type ('a, 'e) or_msg = ('a, ([> `Msg of string | `Multi of 'e list ] as 'e)) t

  module Syntax : sig
    val ( let+ ) : ('a, 'b) t -> ('a -> 'c) -> ('c, 'b) t
    val ( let* ) : ('a, 'b) t -> ('a -> ('c, 'b) t) -> ('c, 'b) t
    val ( >>| ) : ('a, 'b) t -> ('a -> 'c) -> ('c, 'b) t
    val ( >>= ) : ('a, 'b) t -> ('a -> ('c, 'b) t) -> ('c, 'b) t
  end

  val fold_list :
    ('acc -> 'a -> ('acc, 'e) result) -> 'acc -> 'a list -> ('acc, 'e) or_msg

  val flatten : (('a, 'b) result, 'b) result -> ('a, 'b) result
  val iter_until : ('a -> (unit, 'b) result) -> 'a list -> (unit, 'b) result

  val errorf :
    ('a, Format.formatter, unit, (_, [> `Msg of string ]) t) format4 -> 'a
end
