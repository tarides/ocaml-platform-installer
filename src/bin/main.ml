open Cmdliner
open! Platform.Import

let () = Sys.catch_break true

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
    try install_platform ()
    with Sys.Break ->
      Logs.app (fun m -> m "User interruption");
      130
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
          "You can install the OCaml Platform tools in your current $(b,opam) \
           switch by running $(mname).";
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
\$ eval \$(opam env)
\$ dune init proj demo .|};
        `S Manpage.s_commands;
        `S Manpage.s_bugs;
        `P "Report them, see $(i,%%PKG_HOMEPAGE%%) for contact information.";
        `S "DETAILS";
        `P
          "Under the hood, $(mname) uses several mechanisms to install and \
           cache the platform tools.";
        `I
          ( "The sandbox switch",
            "The sandbox switch is a switch in which the tools will be \
             compiled. The platform tools are normally installed into the \
             sandbox switch. Then, the installed files, except for the \
             libraries, are grouped into new opam packages in the local binary \
             repository (see below)." );
        `I
          ( "The local binary opam repository",
            "All built tools are cached in a local opam repository. The \
             packages in this repository consists of pre-compiled packages \
             with no libraries. When the original package contains libraries, \
             it differs from the binary package. In this case, the name of the \
             binary package is suffixed with $(b,+bin+platform), and \
             installing the original package (for instance to have the \
             library) will replace the platform one. In any case, the version \
             of a package in the local repository contains both the original \
             version and the ocaml version they were compiled with, as this \
             may be important for some tools." );
        `I
          ( "The overall logic",
            "When prompted to install the platform tools, for a given switch, \
             $(mname) first finds for each tool the latest version compatible \
             with the $(b,ocaml) version of the switch. Then, it checks in the \
             local binary repo which tools have their version already \
             available, and which tools need to be built. Only if needed, it \
             creates the sandbox switch, to builds the missing tools, and adds \
             corresponding packages to the local repository. Finally, it \
             installs all tools from the local binary repository." );
        `S Manpage.s_authors;
        `P "Jules Aguillon, $(i,https://github.com/Julow)";
        `P "Paul-Elliot Anglès d'Auriac, $(i,https://github.com/panglesd)";
        `P "Sonja Heinze, $(i,https://github.com/pitag-ha)";
        `P "Thibaut Mattio, $(i,https://github.com/tmattio)";
        `S Manpage.s_see_also;
        `P
          "Consult the project repository on \
           $(i,https://github.com/tarides/ocaml-platform) for more information \
           on the tool and the Platform.";
      ]
    in
    Cmd.info "ocaml-platform" ~man ~doc ~version:"%%VERSION%%"
  in
  Stdlib.exit @@ Cmd.eval' (Cmd.v info term)

let () =
  Platform.Opam.Queries.init ();
  main ()
