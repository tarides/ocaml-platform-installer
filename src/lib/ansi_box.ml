open! Import
open ANSITerminal

external sigwinch : unit -> int option = "ocaml_sigwinch"

let sigwinch = sigwinch ()

(** Write to a [ref] before calling [f] and restore its previous value after. *)
let with_ref_set ref value f =
  let old_value = !ref in
  ref := value;
  Fun.protect ~finally:(fun () -> ref := old_value) f

let read_and_print ~log_height ic ic_err (out_init, out_acc, out_finish) =
  let err_acc acc l = l :: acc in
  let ic = Lwt_io.of_unix_fd (Unix.descr_of_in_channel ic) ~mode:Lwt_io.input
  and ic_err =
    Lwt_io.of_unix_fd (Unix.descr_of_in_channel ic_err) ~mode:Lwt_io.input
  in
  let isatty = Unix.isatty Unix.stdout in
  let terminal_size = ref (if isatty then fst @@ size () else 0) in
  let old_signal =
    Option.map
      (fun sigwinch ->
        ( Sys.signal sigwinch
            (Sys.Signal_handle
               (fun i ->
                 if i = sigwinch then terminal_size := fst @@ size () else ())),
          sigwinch ))
      sigwinch
  in
  let ansi_enabled = isatty && Option.is_some sigwinch in
  let printf = printf [ Foreground Blue ] in
  let print_history h i =
    match log_height with
    | Some log_height when ansi_enabled ->
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
    | _ -> ()
  in
  let history = ref [] in
  let history_length = ref 0 in
  let add_log_line line =
    history := line :: !history;
    incr history_length;
    print_history !history !history_length
  in
  let clean_logs () =
    match log_height with
    | Some log_height when ansi_enabled ->
        for _ = 0 to Int.min !history_length log_height do
          move_bol ();
          erase Eol;
          move_cursor 0 (-1)
        done;
        move_cursor 0 1
    | _ -> ()
  in
  let open Lwt.Syntax in
  let rec process_stdout acc =
    let* line = Lwt_io.read_line_opt ic in
    match line with
    | Some line ->
        add_log_line line;
        process_stdout (out_acc acc line)
    | None -> Lwt.return acc
  in
  let rec process_stderr acc =
    let* line = Lwt_io.read_line_opt ic_err in
    match line with
    | Some line ->
        add_log_line line;
        process_stderr (err_acc acc line)
    | None -> Lwt.return acc
  in
  (* Restore previous sigwinch handler. *)
  Fun.protect ~finally:(fun () ->
      Option.iter
        (fun (old_signal, sigwinch) -> Sys.set_signal sigwinch old_signal)
        old_signal)
  @@ fun () ->
  with_ref_set ANSITerminal.isatty (fun _ -> isatty) @@ fun () ->
  Fun.protect ~finally:clean_logs @@ fun () ->
  Lwt_main.run
    (let+ acc = process_stdout out_init and+ acc_err = process_stderr [] in
     (out_finish acc, acc_err))
