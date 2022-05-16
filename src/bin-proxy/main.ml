let () =
  let sys_argv =
    match Array.to_list Sys.argv with
    | _argv0 :: argv -> argv
    | _ -> failwith "Unexpected error while interpretting argv."
  in
  let argv = Array.of_list ("ocaml-platform" :: "opam" :: sys_argv) in
  Unix.execv "/usr/local/bin/ocaml-platform" argv
