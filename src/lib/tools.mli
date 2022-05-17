type t = {
  name : string;
  compiler_constr : string option;
  description : string option;
}
(* FIXME: Once we use the opam library, let's use something like
   [OpamPackage.Name.t] for the type of [name] and something like ... for the
   type of [compiler_constr].*)

val install : Opam.Global.t -> t list -> (unit, [> `Msg of string ] list) result
(** [install tools] installs each tool in [tools] inside the current switch, if
    it isn't already installed *)

val platform : t list
(** All tools in the current state of the OCaml Platform. (TODO: For the
    compiler version dependent tools, the [compiler_constr] should be the
    compiler version of the current swtich.) *)
(* FIXME: should take an argument of type [OpamStateTypes.switch_state] from the
   opam library or something like that instead of unit *)
