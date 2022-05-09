open! Platform.Import
open Cmdliner
open Result.Direct

(** A Cmdliner conversion for a path. The path doesn't need to exist on the
    system. *)
let conv_path = Arg.conv ~docv:"PATH" Fpath.(of_string, pp)

let handle_err ~err =
  Result.map_error (fun (`Msg msg) ->
      Platform.UserInteractions.errorf "%s" msg;
      err)

let exec ~skip ~err f = if skip then Ok () else handle_err ~err (f ())

let handle_errs =
  Result.map_error (fun l ->
      List.iter (fun (`Msg msg) -> Platform.UserInteractions.errorf "%s" msg) l;
      List.length l)

let install_platform opam_opts =
  let install_res =
    let open Platform.Opam in
    let* skip_install = is_installed () |> handle_err ~err:1 in
    let* () = exec ~skip:skip_install ~err:30 install in
    let* () = exec ~skip:(is_initialized opam_opts) ~err:31 (init opam_opts) in
    Platform.Tools.(install opam_opts platform) |> handle_errs
  in
  match install_res with Ok () -> 0 | Error st -> st

(** Options that are taken by every commands and passed down to every opam
    commands bundled together. *)
let opam_options =
  let open Term in
  let yes =
    let doc = "Just keep going without stopping to prompt for confirmation" in
    Arg.(value & flag & info [ "y"; "yes" ] ~doc)
  and root =
    (* We need this value to determine whether opam is initialized, so we need
       to handle Opam's env variable and a consistent default value. FIXME:
       Using Opam's library will allow to reuse their cmdliner definitions. *)
    let doc = "Location of Opam's root directory."
    and env = Cmd.Env.info "OPAMROOT"
    and absent = "\"\\$HOME/.opam\"" in
    const (function
      | Some r -> r
      | None -> Fpath.(v (Bos.OS.Env.opt_var "HOME" ~absent:".") / ".opam"))
    $ Arg.(
        value
        & opt (some conv_path) None
        & info [ "opam-root" ] ~absent ~env ~doc)
  in
  const (fun yes root -> { Platform.Opam.yes; root }) $ yes $ root

let cmd =
  let term = Term.(const install_platform $ opam_options) in
  let info =
    let doc = "Install all OCaml Platform tools in your current switch." in
    Cmd.info "ocaml-platform" ~doc
      ~version:"%%VERSION%%" (* ~sdocs ~exits ~man *)
  in
  Cmd.v info term

let main () = Stdlib.exit @@ Cmd.eval' cmd
let () = main ()
