open! Platform.Import
open Cmdliner

let handle_err ~err =
  Result.map_error (fun (`Msg msg) ->
      Platform.User_interactions.errorf "%s" msg;
      err)

let exec ~skip ~err f = if skip then Ok () else handle_err ~err (f ())

let handle_errs ~err =
  Result.map_error (fun l ->
      List.iter (fun (`Msg msg) -> Platform.User_interactions.errorf "%s" msg) l;
      err)

let install_platform opam_opts =
  let install_res =
    let open Platform.Opam in
    let open Result.Syntax in
    let* () = exec ~skip:skip_install ~err:30 install in
    let* () = exec ~skip:(is_initialized opam_opts) ~err:31 (init opam_opts) in
    Platform.Tools.(install opam_opts platform) |> handle_errs ~err:32
  in
  match install_res with Ok () -> 0 | Error st -> st

let cmd =
  let yes = true
  and root =
    Bos.OS.Env.var "OPAMROOT" |> Option.map Fpath.v
    |> Option.value
         ~default:Fpath.(v (Bos.OS.Env.opt_var "HOME" ~absent:".") / ".opam")
  in
  let term =
    Term.(const install_platform $ const { Platform.Opam.yes; root })
  in
  let info =
    let doc = "Install all OCaml Platform tools in your current switch." in
    Cmd.info "ocaml-platform" ~doc
      ~version:"%%VERSION%%" (* ~sdocs ~exits ~man *)
  in
  Cmd.v info term

let main () = Stdlib.exit @@ Cmd.eval' cmd
let () = main ()
