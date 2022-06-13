open! Import
open ANSITerminal

let read_and_print_ic ~log_height ic =
  let printf = printf [ Foreground Blue ] in
  let print_history h =
    match log_height with
    | None -> ()
    | Some log_height ->
        let rec refresh_history h n =
          match h with
          | a :: q when n <= log_height ->
              erase Eol;
              printf "%s"
                (String.sub a 0 @@ min (String.length a) ((fst @@ size ()) - 1));
              move_cursor 0 (-1);
              move_bol ();
              refresh_history q (n + 1)
          | _ ->
              move_cursor 0 n;
              move_bol ()
        in
        let i = List.length h in
        if i <= log_height then
          match h with
          | [] -> ()
          | line :: _ ->
              printf "%s\n"
                (String.sub line 0
                @@ min (String.length line) ((fst @@ size ()) - 1))
        else refresh_history h 0;
        flush_all ()
  in
  let clean history =
    match log_height with
    | None -> ()
    | Some log_height ->
        for _ = 0 to Int.min (List.length history) log_height do
          move_bol ();
          erase Eol;
          move_cursor 0 (-1)
        done;
        move_cursor 0 1
  in
  let rec process_new_line history =
    let line = try Some (input_line ic) with End_of_file -> None in
    match line with
    | Some line ->
        let history = line :: history in
        print_history history;
        process_new_line history
    | None ->
        clean history;
        List.rev history
  in
  process_new_line []
