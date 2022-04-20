open! Platform.Import
open Cmdliner
open Result.Direct

let exec ~skip ~err f =
  if skip then Ok ()
  else
    f ()
    |> Result.map_error (fun (`Msg msg) ->
           Platform.UserInteractions.errorf "%s" msg;
           err)

let handle_errs =
  Result.map_error (fun l ->
      List.iter (fun (`Msg msg) -> Platform.UserInteractions.errorf "%s" msg) l;
      List.length l)

let do_all ~yes switch =
  let setup_res =
    let open Platform.Opam in
    let* () = exec ~skip:(is_installed ()) ~err:30 (install ~yes) in
    let* () = exec ~skip:(is_initialized ()) ~err:31 (init ~yes) in
    let* () =
      exec ~skip:(switch_exists switch) ~err:32 (make_switch ~yes switch)
    in
    Platform.Tools.(install ~yes platform) |> handle_errs
  in
  match setup_res with Ok () -> 0 | Error st -> st

let local_setup yes = function
  | None -> do_all ~yes (Local ".")
  | Some dir -> do_all ~yes (Local dir)

let global_setup yes = function
  | None ->
      (* FIXME: this should be the latest stable compiler, not a hard-coded 4.14.0 *)
      do_all ~yes (Global "4.14.0")
  | Some compiler -> do_all ~yes (Global compiler)

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

let yes =
  let doc = "Just keep going without stopping to prompt for confirmation" in
  Arg.(value & flag & info [ "y"; "yes" ] ~doc)

let local_cmd =
  let term = Term.(const local_setup $ yes $ local_arg) in
  (* FIXME: let's find something shorter *)
  let info = Cmd.info "setup-local" in
  Cmd.v info term

let global_cmd =
  let term = Term.(const global_setup $ yes $ global_arg) in
  (* FIXME: let's find something shorter *)
  let info = Cmd.info "setup-global" in
  Cmd.v info term
