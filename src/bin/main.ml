open! Platform.Import
open Cmdliner

let main =
  let doc = "Set-up everything you need to hack in OCaml." in
  (* Show the help when no argument is passed. *)
  let show_help = Term.ret (Term.const (`Help (`Auto, None))) in
  Cmd.group ~default:show_help
    (Cmd.info "ocaml-platform" ~version:"%%VERSION%%"
       ~doc (* ~sdocs ~exits ~man *))
    [ Setup.local_cmd; Setup.global_cmd ]

let main () = Stdlib.exit @@ Cmd.eval' main
let () = main ()
