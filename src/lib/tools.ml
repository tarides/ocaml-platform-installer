open! Import
open Bos_setup

let compiler_independent = [ "dune"; "utop"; "dune-release" ]
let compiler_dependent = [ "merlin"; "ocaml-lsp-server"; "odoc"; "ocamlformat" ]

type t = {
  name : string;
  compiler_constr : string option;
  description : string option;
}
(* FIXME: Once we use the opam library, let's use something like [OpamPackage.Name.t] for the type of [name] and something like ... for the type of [compiler_constr].*)

let install_one ~yes { name; compiler_constr = _; description } =
  (* TODO: check first if the tool is already installed before installing it *)
  let descr = Option.value ~default:"" description in
  UserInteractions.logf "We're currently installing %s. %s\n" name descr;
  (* FIXME: implement a caching and sandboxing workflow. for the sandboxing, take [compiler_constr] into account *)
  let base_cmd = Cmd.(v "opam" % "install" % name) in
  let cmd = if yes then Cmd.(base_cmd % "--yes") else base_cmd in
  OS.Cmd.run_io cmd OS.Cmd.in_stdin |> OS.Cmd.to_stdout

let install ~yes tools =
  let iterate res tools =
    List.fold_left
      (fun last_res tool ->
        match (last_res, install_one ~yes tool) with
        | Ok (), Ok () -> Ok ()
        | Error l, Ok () -> Error l
        | Ok (), Error err -> Error [ err ]
        | Error l, Error err -> Error (err :: l))
      res tools
  in
  iterate (Ok ()) tools

let platform =
  (* FIXME: should take an argument of type [OpamStateTypes.switch_state] from the opam library or something like that and use that argument for the [compiler_constr] field of the compiler dependent tools *)
  (* FIXME: should add a brief description for each tool *)
  let independent =
    List.map
      (fun tool -> { name = tool; compiler_constr = None; description = None })
      compiler_independent
  in
  List.fold_left
    (fun acc tool ->
      { name = tool; compiler_constr = None; description = None } :: acc)
    independent compiler_dependent
