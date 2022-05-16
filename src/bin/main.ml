open Cmdliner
open! Platform.Import

let install_platform _opam_opts =
  let install_res =
    let open Result.Syntax in
    let* () = Platform.Opam.install () in
    (* let _ = Platform.Opam.check_init ~opts:opam_opts () in *)
    (* match Platform.Tools.(install opam_opts platform) with *)
    match Ok () with
    | Ok () -> Ok ()
    | Error errs ->
        let err = List.map (fun (`Msg msg) -> msg) errs |> String.concat "\n" in
        Error (`Msg err)
  in
  match install_res with
  | Ok () -> 0
  | Error (`Msg msg) ->
      Printf.eprintf "%s" msg;
      1

let main () =
  let term =
    let opt_root =
      Bos.OS.Env.var "OPAMROOT" |> Option.map OpamFilename.Dir.of_string
    in
    let opts =
      let default = Platform.Opam.Global.default () in
      { default with yes = Some true; opt_root }
    in
    Term.(const install_platform $ const opts)
  in
  let info =
    let doc = "Install all OCaml Platform tools in your current switch." in
    Cmd.info "ocaml-platform" ~doc ~version:"%%VERSION%%"
  in
  match Array.to_list Sys.argv with
  | _ocaml_platform :: "opam" :: _rest ->
      (* Very brittle, what if we add options and run `ocaml-platform --opt
         opam`? Seems fine for now though, let's revisit this when it's a
         problem. *)
      Stdlib.exit @@ Cmd.eval' ~catch:false ~argv:Opam.argv Opam.t
  | _ -> Stdlib.exit @@ Cmd.eval' (Cmd.v info term)

let () = main ()
