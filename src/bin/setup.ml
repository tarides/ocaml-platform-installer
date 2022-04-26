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

let do_all opam_opts switch =
  let setup_res =
    let open Platform.Opam in
    let* skip_install = is_installed () |> handle_err ~err:1 in
    let* () = exec ~skip:skip_install ~err:30 install in
    let* () = exec ~skip:(is_initialized opam_opts) ~err:31 (init opam_opts) in
    let* () =
      exec ~skip:(switch_exists opam_opts switch) ~err:32 (make_switch opam_opts switch)
    in
    Platform.Tools.(install opam_opts platform) |> handle_errs
  in
  match setup_res with Ok () -> 0 | Error st -> st

let local_setup opam_opts = function
  | None -> do_all opam_opts (Local ".")
  | Some dir -> do_all opam_opts (Local dir)

let global_setup opam_opts = function
  | None ->
      (* FIXME: this should be the latest stable compiler, not a hard-coded 4.14.0 *)
      do_all opam_opts (Global "4.14.0")
  | Some compiler -> do_all opam_opts (Global compiler)

let local_arg =
  let doc =
    "The project directory for the local switch. Defaults to the current \
     working directory."
  in
  Arg.(value & opt (some' string) None & info [ "d"; "dir" ] ~docv:"DIR" ~doc)

let global_arg =
  let doc =
    "The compiler you'd like to have in your global switch. Defaults to the \
     latest stable compiler."
  in
  Arg.(
    value
    & opt (some' string) None
    & info [ "c"; "compiler" ] ~docv:"COMPILER" ~doc)

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

let local_cmd =
  let term = Term.(const local_setup $ opam_options $ local_arg) in
  (* FIXME: let's find something shorter *)
  let info = Cmd.info "setup-local" in
  Cmd.v info term

let global_cmd =
  let term = Term.(const global_setup $ opam_options $ global_arg) in
  (* FIXME: let's find something shorter *)
  let info = Cmd.info "setup-global" in
  Cmd.v info term
