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

  module List : sig
    val fold_left :
      ('acc -> 'a -> ('acc, 'e) result) -> 'acc -> 'a list -> ('acc, 'e) or_msg

    val filter_map :
      ('a -> ('b option, 'c) or_msg) -> 'a list -> ('b list, 'c) or_msg
  end

  val flatten : (('a, 'b) result, 'b) result -> ('a, 'b) result

  val errorf :
    ('a, Format.formatter, unit, (_, [> `Msg of string ]) t) format4 -> 'a
end
