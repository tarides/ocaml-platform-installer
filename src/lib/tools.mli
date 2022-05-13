open Import

type tool

val install : Opam.Global.t -> tool list -> (unit, 'e) Result.or_msg
(** [install tools] installs each tool in [tools] inside the current switch, if
    it isn't already installed *)

val platform : tool list
(** All tools in the current state of the OCaml Platform. (TODO: For the
    compiler version dependent tools, the [compiler_constr] should be the
    compiler version of the current swtich.) *)
(* FIXME: should take an argument of type [OpamStateTypes.switch_state] from the
   opam library or something like that instead of unit *)
