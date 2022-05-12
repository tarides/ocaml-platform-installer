open! Import
open Bos_setup

type opam_options = { yes : bool; root : Fpath.t }

let is_installed () = 
  OS.Cmd.exists (Cmd.v "opam-test")

let install () =
  let open Result.Syntax in
  let+ is_installed = is_installed () in
  if not is_installed then Bin_proxy.write_to "/usr/local/bin/opam-test"

let opam_cmd { yes; root } cmd =
  let open Cmd in
  v "opam" % cmd %% (if yes then v "--yes" else empty) % "--root" % p root

let is_initialized _ =
  (* FIXME *)
  false

let init opts =
  let is_initialized = is_initialized () in
  if not is_initialized then
    let cmd = opam_cmd opts "init" in
    OS.Cmd.run_io cmd OS.Cmd.in_stdin |> OS.Cmd.to_stdout
  else Ok ()
