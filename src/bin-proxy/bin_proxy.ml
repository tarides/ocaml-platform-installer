let write_to fpath =
  let oc = open_out_gen [Open_wronly; Open_creat; Open_trunc; Open_binary] 0o755 fpath in
  Fun.protect
    (fun () -> output_string oc Asset.t)
    ~finally:(fun () -> close_out oc)
