open Import
open Result.Syntax

module Cmd = struct
  let with_switch_opt switch_name cmd =
    match switch_name with
    | Some switch_name -> Bos.Cmd.(cmd % "--switch" % switch_name)
    | None -> cmd

  let t ?switch cmd =
    let open Bos.Cmd in
    v "opam" %% cmd % "--yes" % "-q" % "--color=never" |> with_switch_opt switch

  let run_gen ?switch out_f cmd =
    let cmd = t ?switch cmd in
    Logs.debug (fun f -> f "Running command '%a'..." Bos.Cmd.pp cmd);
    let* result, (_, status) = Bos.OS.Cmd.(run_out cmd |> out_f) in
    Logs.debug (fun f ->
        f "Running command '%a': %a" Bos.Cmd.pp cmd Bos.OS.Cmd.pp_status status);
    match status with
    | `Exited 0 -> Ok result
    | _ ->
        Result.errorf "Command '%a' failed: %a" Bos.Cmd.pp cmd
          Bos.OS.Cmd.pp_status status

  let run_s ?switch cmd = run_gen ?switch Bos.OS.Cmd.out_string cmd
  let run_l ?switch cmd = run_gen ?switch Bos.OS.Cmd.out_lines cmd
  let run ?switch cmd = run_gen ?switch Bos.OS.Cmd.out_null cmd
end

let cmd_with_pos_args args cmd =
  List.fold_left (fun acc el -> Bos.Cmd.(acc % el)) cmd args

module Config = struct
  module Var = struct
    let get ?switch name = Cmd.run_s ?switch Bos.Cmd.(v "config" % "var" % name)
  end
end

module Switch = struct
  let list () = Cmd.run_l (Bos.Cmd.(v "switch" % "list" % "--short"))

  let create ?ocaml_version switch_arg =
    let cmd =
      match ocaml_version with
      | Some ocaml_version ->
          Bos.Cmd.(
            v "switch" % "create" % switch_arg % ocaml_version % "--no-switch")
      | None -> Bos.Cmd.(v "switch" % "create" % switch_arg % "--no-switch")
    in
    Cmd.run cmd

  let remove name = Cmd.run_s Bos.Cmd.(v "switch" % "remove" % name)
end

module Repository = struct
  let add ~url name =
    Cmd.run
      Bos.Cmd.(
        v "repository" % "add" % "--dont-select" % "-k" % "local" % name % url)

  let remove name = Cmd.run Bos.Cmd.(v "repository" % "remove" % name)
end

module Show = struct
  let list_files ?switch pkg_name =
    Cmd.run_l ?switch Bos.Cmd.(v "show" % "--list-files" % pkg_name)

  let available_versions ?switch pkg_name =
    let open Result.Syntax in
    let+ output =
      Cmd.run_s ?switch
        Bos.Cmd.(v "show" % "-f" % "available-versions" % pkg_name)
    in
    Astring.String.cuts ~sep:"  " output |> List.rev

  let installed_version ?switch pkg_name =
    Cmd.run_s ?switch
      Bos.Cmd.(v "show" % pkg_name % "-f" % "installed-version" % "--normalise")

  let depends ?switch pkg_name =
    Cmd.run_l ?switch Bos.Cmd.(v "show" % "-f" % "depends:" % pkg_name)

  let version ?switch pkg_name =
    Cmd.run_l ?switch Bos.Cmd.(v "show" % "-f" % "version" % pkg_name)
end

let install ?switch pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "install" % "-y") in
  Cmd.run ?switch cmd

let remove ?switch pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "remove") in
  Cmd.run ?switch cmd

let update ?switch pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "update" % "--no-auto-upgrade") in
  Cmd.run ?switch cmd

let upgrade ?switch pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "upgrade") in
  Cmd.run ?switch cmd

let root =
  Bos.OS.Env.var "OPAMROOT" |> Option.map Fpath.v
  |> Option.value
       ~default:Fpath.(v (Bos.OS.Env.opt_var "HOME" ~absent:".") / ".opam")

let check_init () =
  let open Result.Syntax in
  let* exists = Bos.OS.Dir.exists root in
  if exists then Ok ()
  else
    let cmd = Bos.Cmd.(v "init") in
    Cmd.run cmd
