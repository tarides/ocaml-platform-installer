open Import
open Result.Syntax

module GlobalOpts = struct
  type t = { root : Fpath.t; switch : string option }

  let v ~root ?switch () = { root; switch }

  let default =
    let root =
      Bos.OS.Env.var "OPAMROOT" |> Option.map Fpath.v
      |> Option.value
           ~default:Fpath.(v (Bos.OS.Env.opt_var "HOME" ~absent:".") / ".opam")
    in
    v ~root ()
end

module Cmd = struct
  let t opam_opts cmd =
    let open Bos.Cmd in
    let switch_cmd =
      match opam_opts.GlobalOpts.switch with
      | None -> empty
      | Some switch -> v "--switch" % switch
    in
    let root_cmd = v "--root" % p opam_opts.root in
    Bos.Cmd.(
      v "opam" %% cmd % "--yes" % "-q" % "--color=never" %% switch_cmd
      %% root_cmd)

  let run_gen opam_opts out_f cmd =
    let cmd = t opam_opts cmd in
    Logs.debug (fun f -> f "Running command '%a'..." Bos.Cmd.pp cmd);
    let* result, (_, status) = Bos.OS.Cmd.(run_out cmd |> out_f) in
    Logs.debug (fun f ->
        f "Running command '%a': %a" Bos.Cmd.pp cmd Bos.OS.Cmd.pp_status status);
    match status with
    | `Exited 0 -> Ok result
    | _ ->
        Result.errorf "Command '%a' failed: %a" Bos.Cmd.pp cmd
          Bos.OS.Cmd.pp_status status

  let run_s opam_opts cmd = run_gen opam_opts Bos.OS.Cmd.out_string cmd
  let run_l opam_opts cmd = run_gen opam_opts Bos.OS.Cmd.out_lines cmd
  let run opam_opts cmd = run_gen opam_opts Bos.OS.Cmd.out_null cmd
end

let cmd_with_pos_args args cmd =
  List.fold_left (fun acc el -> Bos.Cmd.(acc % el)) cmd args

module Config = struct
  module Var = struct
    let get opam_opts name =
      Cmd.run_s opam_opts Bos.Cmd.(v "config" % "var" % name)
  end
end

module Switch = struct
  let list opam_opts =
    Cmd.run_l opam_opts Bos.Cmd.(v "switch" % "list" % "--short")

  let create ?ocaml_version opam_opts switch_arg =
    let cmd =
      match ocaml_version with
      | Some ocaml_version ->
          Bos.Cmd.(
            v "switch" % "create" % switch_arg % ocaml_version % "--no-switch")
      | None -> Bos.Cmd.(v "switch" % "create" % switch_arg % "--no-switch")
    in
    Cmd.run opam_opts cmd

  let remove opam_opts name =
    Cmd.run_s opam_opts Bos.Cmd.(v "switch" % "remove" % name)
end

module Repository = struct
  let add opam_opts ~url name =
    Cmd.run opam_opts
      Bos.Cmd.(
        v "repository" % "add" % "--this-switch" % "-k" % "local" % name % url)

  let remove opam_opts name =
    Cmd.run opam_opts Bos.Cmd.(v "repository" % "remove" % name)
end

module Show = struct
  let list_files opam_opts pkg_name =
    Cmd.run_l opam_opts Bos.Cmd.(v "show" % "--list-files" % pkg_name)

  let available_versions opam_opts pkg_name =
    let open Result.Syntax in
    let+ output =
      Cmd.run_s opam_opts
        Bos.Cmd.(v "show" % "-f" % "available-versions" % pkg_name)
    in
    Astring.String.cuts ~sep:"  " output |> List.rev

  let installed_version opam_opts pkg_name =
    Cmd.run_s opam_opts
      Bos.Cmd.(v "show" % pkg_name % "-f" % "installed-version" % "--normalise")

  let depends opam_opts pkg_name =
    Cmd.run_l opam_opts Bos.Cmd.(v "show" % "-f" % "depends:" % pkg_name)

  let version opam_opts pkg_name =
    Cmd.run_l opam_opts Bos.Cmd.(v "show" % "-f" % "version" % pkg_name)
end

let install opam_opts pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "install") in
  Cmd.run opam_opts cmd

let remove opam_opts pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "remove") in
  Cmd.run opam_opts cmd

let update opam_opts pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "update" % "--no-auto-upgrade") in
  Cmd.run opam_opts cmd

let upgrade opam_opts pkgs =
  let cmd = cmd_with_pos_args pkgs Bos.Cmd.(v "upgrade") in
  Cmd.run opam_opts cmd

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
    Cmd.run GlobalOpts.default cmd
