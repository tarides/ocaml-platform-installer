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
  let opam_opts = Platform.Opam.GlobalOpts.default in
  let install_res =
    let _ = Platform.Opam.check_init () in
    Platform.Tools.(install opam_opts (platform ()))
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
    let doc = "Install all OCaml Platform tools in your opam switch." in
    let man =
      [
        `S Manpage.s_description;
        `P
          "The OCaml Platform represents the best way for developers to write \
           software in OCaml. It combines the core OCaml compiler with a \
           coherent set of tools, documentation, and resources.";
        `P
          "The $(mname) command line is an installer for the OCaml Platform. \
           It will install the Platform tools on your system. The list of \
           tools that are managed by $(mname) are:";
        `P "- Package manager: $(b,opam)";
        `Noblank;
        `P "- Build system: $(b,dune)";
        `Noblank;
        `P "- Documentation generator: $(b,odoc)";
        `Noblank;
        `P "- Code formatter: $(b,ocamlformat)";
        `Noblank;
        `P "- Release helper: $(b,dune-release)";
        `Noblank;
        `P "- LSP server: $(b,ocaml-lsp)";
        `Noblank;
        `P "- REPL: $(b,utop)";
        `Noblank;
        `P "- Editor helper: $(b,merlin)";
        `P
          "The normal way of interacting with the $(mname) installer for the \
           first time is through the installation script, which will also \
           install the latest $(b,opam) distribution on your system.";
        `P
          "You can install the OCaml \
           Platform tools in your current $(b,opam) switch by running \
           $(mname).";
        `P
          "For more information on how to get running with OCaml, you can \
           refer to the official Get Up and Running With OCaml guide: \
           $(i,https://ocaml.org/docs/up-and-running).";
        `S Manpage.s_examples;
        `P
          "The following commands will create a new project with a local opam \
           switch and install the OCaml Platform tools in it:";
        `Noblank;
        `Pre
          {|
\$ mkdir my-project && cd my-project/
\$ opam switch create . ocaml-base-compiler.4.14.0
\$ ocaml-platform
\$ eval $(opam env)
\$ dune init proj demo .|};
        `S Manpage.s_commands;
        `S Manpage.s_bugs;
        `P "Report them, see $(i,%%PKG_HOMEPAGE%%) for contact information.";
        `S Manpage.s_authors;
        `P "Jules Aguillon, $(i,https://github.com/Julow)";
        `P "Paul-Elliot Anglès d'Auriac, $(i,https://github.com/panglesd)";
        `P "Sonja Heinze, $(i,https://github.com/pitag-ha)";
        `P "Thibaut Mattio, $(i,https://github.com/tmattio)";
      ]
    in
    Cmd.info "ocaml-platform" ~man ~doc ~version:"%%VERSION%%"
  in
  Stdlib.exit @@ Cmd.eval' (Cmd.v info term)

let () = main ()
