open! Platform.Import
open Cmdliner

let main =
  let doc = "Set-up everything you need to hack in OCaml." in
  Cmd.group
    (Cmd.info "ocaml-platform" ~version:"%%VERSION%%"
       ~doc (* ~sdocs ~exits ~man *))
    [ Setup.local_cmd; Setup.global_cmd ]

let main () = Stdlib.exit @@ Cmd.eval' main
let () = main ()
