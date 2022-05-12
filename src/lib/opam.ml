open! Import
open Bos_setup

type opam_options = { yes : bool; root : Fpath.t }

let is_installed () = OS.Cmd.exists (Cmd.v "opam")

let install () =
  let open Result.Monad in
  let* installed = is_installed () in
  if installed then Error (`Msg "Already installed")
  else
    (* FIXME: implement this in OCaml instead of running the opam script and
       adapt it to our ideas. In particular, take [yes] into account instead of
       ignoring it :P *)
    let install_sh =
      "bash -c \"sh <(curl -fsSL \
       https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)\""
    in
    let exit = Sys.command install_sh in
    if exit = 0 then Ok ()
    else Error (`Msg "Something went wrong trying to install opam.")

let opam_cmd { yes; root } cmd =
  let open Cmd in
  v "opam" % cmd %% (if yes then v "--yes" else empty) % "--root" % p root

let init opts () =
  let cmd = opam_cmd opts "init" in
  OS.Cmd.run_io cmd OS.Cmd.in_stdin |> OS.Cmd.to_stdout

let is_initialized _ =
  (* FIXME *)
  false
