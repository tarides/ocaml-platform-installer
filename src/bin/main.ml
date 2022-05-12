open Cmdliner
open! Platform.Import

module Common = struct
  [@@@ocaml.warning "-32"]

  module Syntax = struct
    let ( let+ ) t f = Term.(const f $ t)
    let ( and+ ) a b = Term.(const (fun x y -> (x, y)) $ a $ b)
  end
end

let install_platform opam_opts =
  let install_res =
    let open Result.Syntax in
    let* () = Platform.Opam.install () in
    let _ = Platform.Opam.check_init ~opts:opam_opts () in
    let* () = Platform.Opam.Switch.install ~opts:opam_opts [] in
    Platform.Tools.(install opam_opts platform)
  in
  match install_res with
  | Ok () -> 0
  | Error (`Msg msg) ->
      Printf.eprintf "%s" msg;
      1

let main () =
  let term =
    let open Common.Syntax in
    let+ log_level =
      let env = Cmd.Env.info "OCAML_PLATFORM_VERBOSITY" in
      Logs_cli.level ~docs:Manpage.s_common_options ~env ()
    in
    let opts =
      let opt_root =
        Bos.OS.Env.var "OPAMROOT" |> Option.map OpamFilename.Dir.of_string
      in
      let default = Platform.Opam.Global.default () in
      { default with yes = Some true; opt_root }
    in
    Fmt_tty.setup_std_outputs ();
    Logs.set_level log_level;
    Logs.set_reporter (Logs_fmt.reporter ~app:Fmt.stdout ());
    install_platform opts
  in
  let info =
    let doc = "Install all OCaml Platform tools in your current switch." in
    Cmd.info "ocaml-platform" ~doc ~version:"%%VERSION%%"
  in
  match Array.to_list Sys.argv with
  | _ocaml_platform :: "opam" :: _rest ->
      (* Very brittle, what if we add options and run `ocaml-platform --opt
         opam`? Seems fine for now though, let's revisit this when it's a
         problem. *)
      Stdlib.exit @@ Cmd.eval' ~catch:false ~argv:Opam.argv Opam.t
  | _ -> Stdlib.exit @@ Cmd.eval' (Cmd.v info term)

let () = main ()
