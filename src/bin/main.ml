open Cmdliner
open! Platform.Import

module Common = struct
  [@@@ocaml.warning "-32"]

  module Syntax = struct
    let ( let+ ) t f = Term.(const f $ t)
    let ( and+ ) a b = Term.(const (fun x y -> (x, y)) $ a $ b)
  end
end

let rec log_error = function
  | `Msg msg -> Logs.err (fun f -> f "%s" msg)
  | `Multi errs -> List.iter log_error errs

let install_platform () =
  let install_res =
    let _ = Platform.Opam.check_init () in
    Platform.Tools.(install (platform ()))
  in
  match install_res with
  | Ok () -> 0
  | Error e ->
      log_error e;
      1

let main () =
  let term =
    let open Common.Syntax in
    let+ log_level =
      let env = Cmd.Env.info "OCAML_PLATFORM_VERBOSITY" in
      Logs_cli.level ~docs:Manpage.s_common_options ~env ()
    in
    Fmt_tty.setup_std_outputs ();
    Logs.set_level log_level;
    Logs.set_reporter (Logs_fmt.reporter ~app:Fmt.stdout ());
    install_platform ()
  in
  let info =
    let doc = "Install all OCaml Platform tools in your current switch." in
    Cmd.info "ocaml-platform" ~doc ~version:"%%VERSION%%"
  in
  Stdlib.exit @@ Cmd.eval' (Cmd.v info term)

let () = main ()
