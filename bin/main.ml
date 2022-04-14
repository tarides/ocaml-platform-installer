open Cmdliner

let doc = "Install opam"

let man =
  [
    `S Manpage.s_description;
    `P "$(tname) installs opam, if it isn't already installed.";
  ]

let install () = ignore @@ Platform.Opam_installer.install_opam ()
let term = Term.(const install $ const ())
let info = Cmd.info "install opam" ~doc ~man
let cmd = Cmd.v info term
let () = exit (Cmd.eval cmd)
