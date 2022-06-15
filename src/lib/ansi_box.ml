open! Import
open ANSITerminal

let read_and_print_ic ~log_height ic (out_init, out_acc, out_finish) =
  let printf = printf [ Foreground Blue ] in
  let print_history h i =
    match log_height with
    | Some log_height when !isatty Unix.stdout ->
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
        if i <= log_height then
          match h with
          | [] -> ()
          | line :: _ ->
              printf "%s\n"
                (String.sub line 0
                @@ min (String.length line) ((fst @@ size ()) - 1))
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
  let rec process_new_line acc history i =
    let line = try Some (input_line ic) with End_of_file -> None in
    match line with
    | Some line ->
        let acc = out_acc acc line
        and history = line :: history
        and i = i + 1 in
        print_history history i;
        process_new_line acc history i
    | None ->
        clean i;
        acc
  in
  process_new_line out_init [] 0 |> out_finish
