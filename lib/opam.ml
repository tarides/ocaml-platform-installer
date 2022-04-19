open! Import
open Bos_setup

let install ~yes:_ () =
  (* FIXME: implement this in OCaml instead of running the opam script and adapt it to our ideas. In particular, take [yes] into account instead of ignoring it :P *)
  let install_sh =
    "bash -c \"sh <(curl -fsSL \
     https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)\""
  in
  let exit = Sys.command install_sh in
  if exit = 0 then Ok ()
  else Error (`Msg "Something went wrong trying to install opam.")

let is_installed () =
  (*FIXME*)
  false
(* FIXME: implement this in OCaml instead of running the opam script *)

let add_yes ~yes cmd = if yes then Cmd.(cmd % "--yes") else cmd

let init ~yes () =
  (* FIXME: implement this in OCaml instead of running the opam script and adapt it to our ideas. In particular, take [yes] into account instead of ignoring it :P *)
  let base_cmd = Cmd.(v "opam" % "init" % "--bare") in
  let cmd = add_yes ~yes base_cmd in
  OS.Cmd.run_io cmd OS.Cmd.in_stdin |> OS.Cmd.to_stdout

let is_initialized () =
  (* FIXME *)
  false

type switch = Local of string | Global of string
(* FIXME: use Fpath.t for the parameter of [Local] and something like ... for the parameter of [Global] *)

let make_switch ~yes switch () =
  let base_cmd =
    match switch with
    | Local dir ->
        Cmd.(v "opam" % "switch" % "create" % dir % "--deps-only" % "with-test")
    | Global comp -> Cmd.(v "opam" % "switch" % "create" % comp)
  in
  let cmd = add_yes ~yes base_cmd in
  OS.Cmd.run_io cmd OS.Cmd.in_stdin |> OS.Cmd.to_stdout

let switch_exists _switch =
  (* FIXME *)
  false
