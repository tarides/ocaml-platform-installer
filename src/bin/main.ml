open! Platform.Import
open Cmdliner

let cmds = [ Opam.t ]

let install_platform opam_opts =
  let install_res =
    let open Platform.Opam in
    let open Result.Syntax in
    let* () = install () in
    let* () = init opam_opts in
    match Platform.Tools.(install opam_opts platform) with
    | Ok () -> Ok ()
    | Error errs ->
        let err = List.map (fun (`Msg msg) -> msg) errs |> String.concat "\n" in
        Error (`Msg err)
  in
  match install_res with
  | Ok () -> 0
  | Error (`Msg msg) ->
      Platform.User_interactions.errorf "%s" msg;
      1

let main () =
  let term =
    let yes = true
    and root =
      Bos.OS.Env.var "OPAMROOT" |> Option.map Fpath.v
      |> Option.default
           Fpath.(v (Bos.OS.Env.opt_var "HOME" ~absent:".") / ".opam")
    in
    Term.(const install_platform $ const { Platform.Opam.yes; root })
  in
  let info =
    let doc = "Install all OCaml Platform tools in your current switch." in
    Cmd.info "ocaml-platform" ~doc ~version:"%%VERSION%%"
  in
  let group = Cmd.group ~default:term info cmds in
  Stdlib.exit @@ Cmd.eval' group

let () = main ()
