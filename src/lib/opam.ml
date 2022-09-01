open Bos_setup
open Import
open Result.Syntax

module GlobalOpts = struct
  type t = {
    root : Fpath.t;
    switch : string option;
    env : string String.map option;
    log_height : int option;
  }

  let v ~root ?switch ?env ?log_height () = { root; switch; env; log_height }

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

  let run_gen opam_opts (out_acc, out_wrap) cmd =
    let cmd = t opam_opts cmd in
    let cmd_s = Bos.Cmd.to_string cmd in
    Logs.debug (fun m -> m "Running: %s" cmd_s);
    let* env =
      let+ env =
        match opam_opts.env with
        | None -> OS.Env.current ()
        | Some env -> Ok env
      in
      env |> String.Map.to_seq
      |> Seq.map (fun (a, b) -> a ^ "=" ^ b)
      |> Array.of_seq
    in
    let ((ic, _, ic_err) as channels) = Unix.open_process_full cmd_s env in
    let log_height = opam_opts.log_height in
    let res, res_err = Ansi_box.read_and_print ~log_height ic ic_err out_acc in
    let s_err = String.concat ~sep:"\n" res_err in
    (match s_err with
    | "" -> ()
    | s -> Logs.info (fun m -> m "Error in %s:\n%s" cmd_s s));
    let result, status, success =
      (res, Unix.close_process_full channels) |> out_wrap
    in
    let pp_process_status ppf = function
      | Unix.WEXITED c -> Fmt.pf ppf "exited with %d" c
      | Unix.WSIGNALED s -> Fmt.pf ppf "killed by signal %a" Fmt.Dump.signal s
      | Unix.WSTOPPED s -> Fmt.pf ppf "stopped by signal %a" Fmt.Dump.signal s
    in
    if success then Ok result
    else
      Result.errorf "Command '%a' failed: %a" Bos.Cmd.pp cmd pp_process_status
        status

  let out_strict (result, status) =
    let success = match status with Unix.WEXITED 0 -> true | _ -> false in
    (result, status, success)

  (** Handle Opam's "not found" exit status, which is [5]. Returns [None]
      instead of failing in this case. *)
  let out_opt (result, status) =
    match status with
    | Unix.WEXITED 0 -> (Some result, status, true)
    | Unix.WEXITED 5 -> (None, status, true)
    | _ -> (None, status, false)

  let out_acc acc line = line :: acc

  let out_s =
    ([], out_acc, fun l -> String.trim @@ String.concat ~sep:"\n" @@ List.rev l)

  let out_l = ([], out_acc, List.rev)
  let out_ignore = ((), (fun () _line -> ()), fun () -> ())
  let run_s opam_opts cmd = run_gen opam_opts (out_s, out_strict) cmd
  let run_l opam_opts cmd = run_gen opam_opts (out_l, out_strict) cmd
  let run opam_opts cmd = run_gen opam_opts (out_ignore, out_strict) cmd

  (** Like [run_s] but handle the "not found" status. *)
  let run_s_opt opam_opts cmd = run_gen opam_opts (out_s, out_opt) cmd
end

module Config = struct
  module Var = struct
    (* TODO: 'opam config' is deprecated in Opam 2.1 in favor of 'opam var'. *)
    let get opam_opts name =
      (* 2.1: "var" % name *)
      Cmd.run_s opam_opts Bos.Cmd.(v "config" % "var" % name)

    let get_opt opam_opts name =
      (* 2.1: "var" % name *)
      Cmd.run_s_opt opam_opts Bos.Cmd.(v "config" % "var" % name)

    let set opam_opts ~global name value =
      (* 2.1: "var" % "--global" % (name ^ "=" ^ value) *)
      let verb = if global then "set-global" else "set" in
      Cmd.run opam_opts Bos.Cmd.(v "config" % verb % name % value)

    let unset opam_opts ~global name =
      (* 2.1: "var" % "--global" % (name ^ "=") *)
      let verb = if global then "unset-global" else "unset" in
      Cmd.run opam_opts Bos.Cmd.(v "config" % verb % name)
  end
end

module Switch = struct
  let list opam_opts =
    Cmd.run_l opam_opts Bos.Cmd.(v "switch" % "list" % "--short")

  let create ~ocaml_version opam_opts switch_name =
    let invariant_args =
      match ocaml_version with
      | Some ocaml_version ->
          Bos.Cmd.(v ("ocaml-base-compiler." ^ ocaml_version))
      | None -> Bos.Cmd.(v "--empty")
    in
    Cmd.run opam_opts
      Bos.Cmd.(
        v "switch" % "create" % "--no-switch" % switch_name %% invariant_args)

  let remove opam_opts name =
    Cmd.run_s opam_opts Bos.Cmd.(v "switch" % "remove" % name)
end

module Repository = struct
  let add opam_opts ~url name =
    Cmd.run opam_opts
      Bos.Cmd.(
        v "repository" % "add" % "--this-switch" % "-k" % "local" % name % url)

  let remove opam_opts name =
    Cmd.run opam_opts
      Bos.Cmd.(v "repository" % "--this-switch" % "remove" % name)
end

module Show = struct
  let list_files opam_opts pkg_name =
    Cmd.run_l opam_opts Bos.Cmd.(v "show" % "--list-files" % pkg_name)
    >>| List.filter (fun l -> not (String.equal "" l))

  let available_versions opam_opts pkg_name =
    let open Result.Syntax in
    let+ output =
      Cmd.run_s opam_opts
        Bos.Cmd.(v "show" % "-f" % "available-versions" % pkg_name)
    in
    Astring.String.cuts ~sep:"  " output |> List.rev

  let installed_version opam_opts pkg_name =
    match
      Cmd.run_s opam_opts
        Bos.Cmd.(
          v "show" % pkg_name % "-f" % "installed-version" % "--normalise")
    with
    | Ok "--" -> Ok None
    | Ok s -> Ok (Some s)
    | Error e -> Error e

  let installed_versions opam_opts pkg_names =
    let parse =
      let open Angstrom in
      let is_whitespace = function
        | '\x20' | '\x0a' | '\x0d' | '\x09' -> true
        | _ -> false
      in
      let whitespace = take_while is_whitespace in
      let word = whitespace *> take_till is_whitespace in
      let field f = whitespace *> string f *> word in
      let parse_double_line = both (field "name") (field "installed-version") in
      let parse = many parse_double_line in
      fun s ->
        match parse_string ~consume:Consume.All parse s with
        | Ok e -> Ok e
        | Error e -> Result.errorf "Error in parsing installed versions: %s" e
    in
    let* res =
      Cmd.run_s opam_opts
        Bos.Cmd.(
          v "show" %% of_list pkg_names % "-f" % "name,installed-version"
          % "--normalise")
    in
    let+ res = parse res in
    List.map (function a, "--" -> (a, None) | a, s -> (a, Some s)) res

  let depends opam_opts pkg_name =
    Cmd.run_l opam_opts Bos.Cmd.(v "show" % "-f" % "depends:" % pkg_name)

  let version opam_opts pkg_name =
    Cmd.run_l opam_opts Bos.Cmd.(v "show" % "-f" % "version" % pkg_name)
end

let install opam_opts pkgs =
  Cmd.run opam_opts Bos.Cmd.(v "install" %% of_list pkgs)

let remove opam_opts pkgs =
  Cmd.run opam_opts Bos.Cmd.(v "remove" %% of_list pkgs)

let update opam_opts pkgs =
  Cmd.run opam_opts Bos.Cmd.(v "update" % "--no-auto-upgrade" %% of_list pkgs)

let upgrade opam_opts pkgs =
  Cmd.run opam_opts Bos.Cmd.(v "upgrade" %% of_list pkgs)

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
