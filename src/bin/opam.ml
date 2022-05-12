open Cmdliner

let command_to_cmd (term, info) =
  let f cmd =
    cmd;
    0
  in
  let term = Term.(const f $ term) in
  Cmd.v info term

let t =
  let argv =
    match Array.to_list Sys.argv with
    | _ocaml_platform :: "opam" :: argv -> Array.of_list ("opam" :: argv)
    | _ -> [|"opam"|]
  in
  let cli, argv = OpamCliMain.check_and_run_external_commands argv in
  let (default, commands), argv1 =
    match argv with
    | prog :: command :: argv when OpamCommands.is_admin_subcommand command ->
        (OpamAdminCommand.get_cmdliner_parser cli, prog :: argv)
    | _ -> (OpamCommands.get_cmdliner_parser cli, argv)
  in
  let _argv = Array.of_list argv1 in
  let term, info = default in
  let term =
    let f cmd =
      cmd;
      0
    in
    Term.(const f $ term)
  in
  let cmds = List.map command_to_cmd commands in
  Cmd.group ~default:term info cmds
