open Cmdliner

let cmds = [ Opam.t ]

let install_platform opam_opts =
  let install_res =
    let _ = Platform.Opam.check_init ~opts:opam_opts () in
    match Platform.Tools.(install opam_opts platform) with
    | Ok () -> Ok ()
    | Error errs ->
        let err = List.map (fun (`Msg msg) -> msg) errs |> String.concat "\n" in
        Error (`Msg err)
  in
  match install_res with
  | Ok () -> 0
  | Error (`Msg msg) ->
      Printf.eprintf "%s" msg;
      1

let main () =
  let term =
    let opt_root =
      Bos.OS.Env.var "OPAMROOT" |> Option.map OpamFilename.Dir.of_string
    in
    let opts =
      let default = Platform.Opam.Global.default () in
      { default with yes = Some true; opt_root }
    in
    Term.(const install_platform $ const opts)
  in
  let info =
    let doc = "Install all OCaml Platform tools in your current switch." in
    Cmd.info "ocaml-platform" ~doc ~version:"%%VERSION%%"
  in
  let group = Cmd.group ~default:term info cmds in
  Stdlib.exit @@ Cmd.eval' group

let () = main ()
