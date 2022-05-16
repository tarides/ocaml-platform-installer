open Stdlib
open Import

module Global = struct
  type t = OpamArg.global_options = {
    debug_level : int option;
    verbose : int;
    quiet : bool;
    color : OpamStd.Config.when_ option;
    opt_switch : string option;
    confirm_level : OpamStd.Config.answer option;
    yes : bool option;
    strict : bool;
    opt_root : OpamTypes.dirname option;
    git_version : bool;
    external_solver : string option;
    use_internal_solver : bool;
    cudf_file : string option;
    solver_preferences : string option;
    best_effort : bool;
    safe_mode : bool;
    json : string option;
    no_auto_upgrade : bool;
    working_dir : bool;
    ignore_pin_depends : bool;
    cli : OpamCLIVersion.t;
  }

  let infer_debug_level_from_logs () =
    match Logs.level () with
    | None -> None
    | Some App | Some Error | Some Warning | Some Info -> Some 0
    | Some Debug -> Some 1

  let infer_verbose_level_from_logs () =
    match Logs.level () with
    | None | Some App | Some Error | Some Warning -> 0
    | Some Info -> 1
    | Some Debug -> 2

  let default () : t =
    let debug_level = infer_debug_level_from_logs () in
    let verbose_level = infer_verbose_level_from_logs () in
    {
      debug_level;
      verbose = verbose_level;
      quiet = false;
      color = None;
      opt_switch = None;
      confirm_level = None;
      yes = None;
      strict = false;
      opt_root = None;
      git_version = false;
      external_solver = None;
      use_internal_solver = true;
      cudf_file = None;
      solver_preferences = None;
      best_effort = true;
      safe_mode = false;
      json = None;
      no_auto_upgrade = true;
      working_dir = false;
      ignore_pin_depends = false;
      cli = OpamCLIVersion.current;
    }

  let apply t =
    let cli = OpamCLIVersion.Sourced.current in
    OpamArg.apply_global_options cli t
end

let is_installed () = Bos.OS.Cmd.exists (Bos.Cmd.v "opam")

let install () =
  let open Result.Syntax in
  let+ is_installed = is_installed () in
  if is_installed then
    Printf.printf "Opam is already installed, skipping installation.\n"
  else
    let path =
      match Sys.os_type with
      | "Unix" -> "/usr/local/bin/opam"
      | "Win32" | "Cygwin" -> failwith "What's the binary path on Windows?"
      | _ -> assert false
    in
    Printf.printf "Installing opam in %s.\n" path;
    Bin_proxy.write_to path

let check_init ?opts () =
  let root =
    Option.value
      ~default:OpamStateConfig.(!r.root_dir)
      (Option.bind opts (fun x -> x.Global.opt_root))
  in
  let config_f = OpamPath.config root in
  let global_state, repo_state, default_compiler =
    if OpamFile.exists config_f then
      let global_state = OpamGlobalState.load `Lock_write in
      (* XXX(patricoferris): Loading repository state when it hasn't been cached
         by opam can take 20+ seconds. If the opam library version is not the
         same as your machine it will have to rebuild the cache! *)
      let repo_state = OpamRepositoryState.load `Lock_none global_state in
      (global_state, repo_state, [])
    else
      let shell = OpamStd.Sys.guess_shell_compat () in
      (* TODO: we should pass sandboxing:true when the environment allows it
         (i.e. in most cases when we're not running in Docker). *)
      let init_config = OpamInitDefaults.init_config ~sandboxing:false () in
      (* Handling already init-ed, if yes should we `opam update` ? *)
      OpamClient.init ~interactive:false ~init_config ~update_config:false shell
  in
  (global_state, repo_state, default_compiler)

let check_switch (global_state : OpamStateTypes.rw OpamStateTypes.global_state)
    repo_state =
  match OpamStateConfig.get_current_switch_from_cwd global_state.root with
  | Some switch_state ->
      Ok (OpamSwitchState.load `Lock_write global_state repo_state switch_state)
  | None ->
      Error
        (`Msg "The current directory does not have an initialized opam switch.")

let check_switch_or_create
    (global_state : OpamStateTypes.rw OpamStateTypes.global_state) repo_state
    default_compiler =
  match OpamStateConfig.get_current_switch_from_cwd global_state.root with
  | Some switch_state ->
      OpamSwitchState.load `Lock_write global_state repo_state switch_state
  | None ->
      let invariant = OpamFile.Config.default_invariant global_state.config in
      let _, ret =
        OpamSwitchCommand.create global_state ~rt:repo_state
          ~invariant
            (* Be carefl changing this, [update] assumes this is [true] *)
          ~update_config:true
          (* Local switch in current-directory *)
          (OpamSwitch.of_dirname (OpamFilename.Dir.of_string "."))
          (fun switch_state ->
            (* Better compiler heuristics not just default - system compiler? -
               latest compatible compiler (with opam files in cwd)? - later,
               relocatable compilers? *)
            ( (),
              OpamSwitchCommand.install_compiler switch_state
                ~additional_installs:default_compiler ))
      in
      ret

module Switch = struct
  (* Prelude applies global options and checks for a local switch and that opam
     is initalised. *)
  let install ?opts pkgs =
    Global.apply (Option.value ~default:(Global.default ()) opts);
    let global_state, repo_state, default_compiler = check_init () in
    (* TODO:patrick Should probably check for opam files in cwd, if none don't
       create switch ? *)
    let switch_state =
      check_switch_or_create global_state repo_state default_compiler
    in
    let switch_state, atoms = OpamAuxCommands.autopin switch_state pkgs in
    OpamSwitchState.drop @@ OpamClient.install switch_state atoms;
    Ok ()

  let remove ?opts pkgs =
    let open Result.Syntax in
    Global.apply (Option.value ~default:(Global.default ()) opts);
    let global_state, repo_state, _ = check_init () in
    let+ switch_state = check_switch global_state repo_state in
    let pure_atoms, pin_atoms =
      List.partition (function `Atom _ -> true | _ -> false) pkgs
    in
    let pin_atoms =
      OpamAuxCommands.resolve_locals_pinned switch_state ~recurse:false
        ?subpath:None pin_atoms
    in
    let switch_state =
      OpamPinCommand.unpin switch_state (List.map fst pin_atoms)
    in
    let atoms =
      List.map (function `Atom a -> a | _ -> assert false) pure_atoms
      @ pin_atoms
    in
    OpamSwitchState.drop
    @@ OpamClient.remove switch_state ~autoremove:true ~force:false atoms;
    atoms

  let update ?opts names =
    (* Not calling OpamStateConfig.update as we don't pass [jobs] (yet?) *)
    (* Not calling OpamClientConfig.update -- apply_global_options does this? *)
    Global.apply (Option.value ~default:(Global.default ()) opts);
    let global_state, repo_state, default_compiler = check_init () in
    (* OpamClient.update calls [get_switch_opt] so is switch-based, ensure there
       is a switch and that the config is updated *)
    let _switch_state =
      check_switch_or_create global_state repo_state default_compiler
    in
    let success, _changed, _rt =
      OpamClient.update global_state ~repos_only:false
        ~dev_only:false
          (* We only want to update repositories that the current switch
             tracks *)
        ~all:false names
    in
    if success then Ok () else Error (`Msg "The update failed")

  (* Opam upgrade is complicated, a few points to be wary of:

     - The `only_installed` argument when set to true tells opam to NOT install
     packages which are currently pinned but not installed. By default we pass
     in the CWD so if packages are pinned to it and uninstalled they would be
     installed by upgrade. Currently when we `ocaml-platform install` we pin and
     install so that's not too much of an issue.

     - We want to take into account the current local directory packages to
     ensure we don't upgrade ourselves into a non-functioning state.

     - `opam upgrade` has a "fixup" mode which could be reported as a possible
     solution to the end-user but we don't support that.

     - The `atoms` passed to `OpamClient.upgrade` are kept installed (or
     reinstalled with confirmation). *)
  let upgrade ?opts atom_locs =
    Global.apply (Option.value ~default:(Global.default ()) opts);
    OpamGlobalState.with_ `Lock_none @@ fun gt ->
    OpamSwitchState.with_ `Lock_write gt @@ fun st ->
    (* TODO: Do we want to allow `recurse` and/or `subpath` *)
    let atoms = OpamAuxCommands.resolve_locals_pinned st atom_locs in
    OpamSwitchState.drop @@ OpamClient.upgrade st ~all:false atoms;
    Ok ()
end
