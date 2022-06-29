open! Import

external sigwinch : unit -> int option = "ocaml_sigwinch"

let sigwinch = sigwinch ()

module Ring = struct
  type 'a t = {
    buf : 'a array;
    mutable wrapped : bool;
        (** Whether the history was filled once and don't contain an
            uninitialised part. When [false], indexes between [head] and
            [Array.length buf] are invalid. *)
    mutable head : int;
  }

  let create capacity dummy_elt =
    if capacity <= 0 then invalid_arg "Ring.create";
    { buf = Array.make capacity dummy_elt; wrapped = false; head = 0 }

  (** Override the oldest element if the buffer is full. *)
  let append ({ buf; head; _ } as t) x =
    buf.(head) <- x;
    if head + 1 >= Array.length buf then (
      t.head <- 0;
      t.wrapped <- true)
    else t.head <- head + 1

  (** [min capacity n_added_element] *)
  let length t = if t.wrapped then Array.length t.buf else t.head

  (** From oldest to newest. *)
  let iter t f =
    let buf = t.buf in
    if t.wrapped then
      for i = t.head to Array.length buf - 1 do
        f buf.(i)
      done;
    for i = 0 to t.head - 1 do
      f buf.(i)
    done
end

let setup_box ~log_height f =
  let run_with_logs_disabled f = f (fun _ -> ()) in
  match log_height with
  | None -> run_with_logs_disabled f
  | _ when (not (Unix.isatty Unix.stdout)) || Option.is_none sigwinch ->
      run_with_logs_disabled f
  | Some log_height ->
      let open ANSITerminal in
      let terminal_size = ref (fst (size ())) in
      let history = Ring.create log_height "" in
      let print_line line =
        printf [ Foreground Blue ] "%s\n"
          (String.sub line 0 @@ min (String.length line) (!terminal_size - 1))
      in
      let print_history () =
        Ring.iter history print_line;
        flush_all ()
      in
      let clear_logs () =
        for _ = 1 to Ring.length history do
          move_cursor 0 (-1);
          erase Eol
        done
      in
      let log_line line =
        clear_logs ();
        Ring.append history line;
        print_history ()
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
        clear_logs ()
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
