open! Import

external sigwinch : unit -> int option = "ocaml_sigwinch"

let sigwinch = sigwinch ()

let setup_box ~log_height f =
  let run_with_logs_disabled f = f (fun _ -> ()) in
  match log_height with
  | None -> run_with_logs_disabled f
  | _ when (not (Unix.isatty Unix.stdout)) || Option.is_none sigwinch ->
      run_with_logs_disabled f
  | Some log_height ->
      let open ANSITerminal in
      let terminal_size = ref (fst (size ())) in
      let printf = printf [ Foreground Blue ] in
      let print_history h i =
        let rec refresh_history h n =
          match h with
          | a :: q when n <= log_height ->
              erase Eol;
              printf "%s"
                (String.sub a 0 @@ min (String.length a) (!terminal_size - 1));
              move_cursor 0 (-1);
              move_bol ();
              refresh_history q (n + 1)
          | _ ->
              move_cursor 0 n;
              move_bol ()
        in
        if i <= log_height then
          match h with
          | [] -> ()
          | line :: _ ->
              printf "%s\n"
                (String.sub line 0
                @@ min (String.length line) (!terminal_size - 1))
        else refresh_history h 0;
        flush_all ()
      in
      let history = ref [] in
      let history_length = ref 0 in
      let log_line line =
        history := line :: !history;
        incr history_length;
        print_history !history !history_length
      in
      let clean_logs () =
        for _ = 0 to Int.min !history_length log_height do
          move_bol ();
          erase Eol;
          move_cursor 0 (-1)
        done;
        move_cursor 0 1
      in
      (* Setup and teardown. *)
      let old_signal =
        Option.map
          (fun sigwinch ->
            ( Sys.signal sigwinch
                (Sys.Signal_handle
                   (fun i ->
                     if i = sigwinch then terminal_size := fst @@ size ()
                     else ())),
              sigwinch ))
          sigwinch
      in
      let old_isatty = !ANSITerminal.isatty in
      (* Avoid repeated calls to isatty. *)
      (ANSITerminal.isatty := fun _ -> true);
      let finally () =
        (* Restore previous sigwinch handler. *)
        Option.iter
          (fun (old_signal, sigwinch) -> Sys.set_signal sigwinch old_signal)
          old_signal;
        ANSITerminal.isatty := old_isatty;
        clean_logs ()
      in
      Fun.protect ~finally (fun () -> f log_line)

let read_and_print ~log_height ic ic_err (out_init, out_acc, out_finish) =
  let err_acc acc l = l :: acc in
  let ic = Lwt_io.of_unix_fd (Unix.descr_of_in_channel ic) ~mode:Lwt_io.input
  and ic_err =
    Lwt_io.of_unix_fd (Unix.descr_of_in_channel ic_err) ~mode:Lwt_io.input
  in
  let open Lwt.Syntax in
  let rec process_stdout ~log_line acc =
    let* line = Lwt_io.read_line_opt ic in
    match line with
    | Some line ->
        log_line line;
        process_stdout ~log_line (out_acc acc line)
    | None -> Lwt.return acc
  in
  let rec process_stderr ~log_line acc =
    let* line = Lwt_io.read_line_opt ic_err in
    match line with
    | Some line ->
        log_line line;
        process_stderr ~log_line (err_acc acc line)
    | None -> Lwt.return acc
  in
  setup_box ~log_height @@ fun log_line ->
  Lwt_main.run
    (let+ acc = process_stdout ~log_line out_init
     and+ acc_err = process_stderr ~log_line [] in
     (out_finish acc, acc_err))
