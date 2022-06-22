open! Import
open ANSITerminal

external sigwinch : unit -> int option = "ocaml_sigwinch"

let sigwinch = sigwinch ()

let read_and_print ~log_height ic ic_err (out_init, out_acc, out_finish) =
  let out_acc_err acc l = l :: acc in
  let ic = Lwt_io.of_unix_fd (Unix.descr_of_in_channel ic) ~mode:Lwt_io.input
  and ic_err =
    Lwt_io.of_unix_fd (Unix.descr_of_in_channel ic_err) ~mode:Lwt_io.input
  in
  let isatty = !isatty Unix.stdout in
  let terminal_size = ref (if isatty then fst @@ size () else 0) in
  Option.iter
    (fun sigwinch ->
      Sys.set_signal sigwinch
        (Sys.Signal_handle
           (fun i ->
             if i = sigwinch then terminal_size := fst @@ size () else ())))
    sigwinch;
  let printf = printf [ Foreground Blue ] in
  let print_history h i =
    match log_height with
    | Some log_height when isatty && Option.is_some sigwinch ->
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
  let clean i =
    match log_height with
    | None -> ()
    | Some log_height ->
        for _ = 0 to Int.min i log_height do
          move_bol ();
          erase Eol;
          move_cursor 0 (-1)
        done;
        move_cursor 0 1
  in
  let open Lwt.Syntax in
  let read_line () =
    let+ l = Lwt_io.read_line_opt ic in
    (`Std, l)
  and read_err_line () =
    let+ l = Lwt_io.read_line_opt ic_err in
    (`Err, l)
  in
  let next_lines promises =
    let+ lines, promises = Lwt.nchoose_split promises in
    List.fold_left
      (fun (lines, promises) res ->
        match res with
        | _, None -> (lines, promises)
        | `Std, Some l -> ((`Std, l) :: lines, read_line () :: promises)
        | `Err, Some l -> ((`Err, l) :: lines, read_err_line () :: promises))
      ([], promises) lines
  in
  let add_lines h acc acc_err lines =
    let add_line (acc, acc_err, history) line =
      match line with
      | `Std, l -> (out_acc acc l, acc_err, l :: history)
      | `Err, l -> (acc, out_acc_err acc_err l, l :: history)
    in
    List.fold_left add_line (acc, acc_err, h) lines
  in
  let rec process_new_line acc acc_err history promises i =
    let* lines, promises = next_lines promises in
    let acc, acc_err, history = add_lines history acc acc_err lines in
    match lines with
    | [] ->
        clean i;
        Lwt.return (acc, acc_err)
    | _ ->
        let i = i + List.length lines in
        print_history history i;
        process_new_line acc acc_err history promises i
  in
  Lwt_main.run
  @@ process_new_line out_init [] [] [ read_line (); read_err_line () ] 0
  |> fun (acc, acc_err) -> (out_finish acc, acc_err)
