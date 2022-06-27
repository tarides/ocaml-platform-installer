open Bos_setup
open Import
open Result.Syntax

module GlobalOpts = struct
  type t = {
    root : Fpath.t;
    switch : string option;
    env : string String.map option;
  }

  let v ~root ?switch ?env () = { root; switch; env }

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
    Result.flatten
    @@ Bos.OS.File.with_tmp_output "opam-err-log-%s"
         (fun tmp _ () ->
           let* result, status, success =
             Bos.OS.Cmd.(
               run_out ?env:opam_opts.env ~err:(err_file tmp) cmd |> out_f)
           in
           let () =
             let s = Bos.OS.File.read tmp in
             match s with
             | Ok "" -> ()
             | Ok s -> Logs.debug (fun m -> m "%s" s)
             | Error (`Msg e) ->
                 Logs.debug (fun m -> m "Impossible to read opam log: %s" e)
           in
           if success then Ok result
           else
             Result.errorf "Command '%a' failed: %a" Bos.Cmd.pp cmd
               Bos.OS.Cmd.pp_status status)
         ()

  let out_strict out_f out =
    let+ result, (_, status) = out_f out in
    let success = match status with `Exited 0 -> true | _ -> false in
    (result, status, success)

  (** Handle Opam's "not found" exit status, which is [5]. Returns [None]
      instead of failing in this case. *)
  let out_opt out_f out =
    let+ result, (_, status) = out_f out in
    match status with
    | `Exited 0 -> (Some result, status, true)
    | `Exited 5 -> (None, status, true)
    | _ -> (None, status, false)

  let run_s opam_opts cmd =
    run_gen opam_opts (out_strict Bos.OS.Cmd.out_string) cmd

  let run_l opam_opts cmd =
    run_gen opam_opts (out_strict Bos.OS.Cmd.out_lines) cmd

  let run opam_opts cmd = run_gen opam_opts (out_strict Bos.OS.Cmd.out_null) cmd

  (** Like [run_s] but handle the "not found" status. *)
  let run_s_opt opam_opts cmd =
    run_gen opam_opts (out_opt Bos.OS.Cmd.out_string) cmd
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

module Queries = struct
  let init () =
    OpamFormatConfig.init ();
    let root = OpamStateConfig.opamroot () in
    OpamStateConfig.load_defaults root |> ignore;
    OpamStateConfig.init ~root_dir:root ()

  let latest_version ~metadata_universe ~pkg_universe ~ocaml package =
    let package = OpamPackage.Name.of_string package in
    let compatible_ones =
      OpamPackage.Set.filter
        (fun pkg ->
          OpamPackage.Name.equal (OpamPackage.name pkg) package
          &&
          let pkg_opam_file = OpamPackage.Map.find pkg metadata_universe in
          let dependencies = OpamFile.OPAM.depends pkg_opam_file in
          let env _ = None in
          OpamFormula.verifies
            (OpamPackageVar.filter_depends_formula ~env dependencies)
            ocaml)
        pkg_universe
    in
    try Some (OpamPackage.max_version compatible_ones package)
    with Not_found -> None

  let installed_versions pkg_names
      (sel : OpamTypes.switch_selections) =
    let installed_pkgs = sel.sel_installed in
    List.map
      (fun name ->
        let version =
          OpamPackage.package_of_name_opt installed_pkgs
          @@ OpamPackage.Name.of_string name
        in
        (name, version))
      pkg_names

  let files_installed_by_pkg pkg_name
      (switch_state : 'lock OpamStateTypes.switch_state) =
    let changes_f =
      OpamPath.Switch.changes switch_state.switch_global.root
        switch_state.switch
        (OpamPackage.Name.of_string pkg_name)
    in
    match OpamFile.Changes.read_opt changes_f with
    | None ->
        Result.errorf
          "Something went wrong looking for the files installed by %s" pkg_name
    | Some changes ->
        Ok
          (OpamDirTrack.check
             (OpamPath.Switch.root switch_state.switch_global.root
                switch_state.switch)
             changes
          |> List.fold_left
               (fun acc file ->
                 match file with
                 | filename, _ -> OpamFilename.to_string filename :: acc)
               [])

  let get_pkg_universe (switch_state : 'lock OpamStateTypes.switch_state) =
    switch_state.available_packages

  let get_metadata_universe (switch_state : 'lock OpamStateTypes.switch_state) =
    switch_state.opams

let get_switch = function
      | None -> OpamStateConfig.get_switch ()
      | Some dir ->
          OpamSwitch.of_dirname
            (Fpath.to_string dir |> OpamFilename.Dir.of_string)

  let with_switch_state ?dir_name f =
    let switch = get_switch dir_name in
    OpamGlobalState.with_ `Lock_read (fun global_state ->
        OpamSwitchState.with_ `Lock_read global_state ~switch
          (fun switch_state -> f switch_state))

  let with_switch_state_sel ?dir_name f =
    let switch = get_switch dir_name in
    OpamGlobalState.with_ `Lock_read (fun global_state ->
      let sel = OpamSwitchState.load_selections ~lock_kind:`Lock_read global_state switch in
    f sel)

  let with_virtual_state f =
    OpamGlobalState.with_ `Lock_read (fun global_state ->
        OpamRepositoryState.with_ `Lock_read global_state (fun repo_state ->
            let virtual_state =
              OpamSwitchState.load_virtual global_state repo_state
            in
            f virtual_state))
end

module Conversions = struct
  let version_of_pkg pkg =
    OpamPackage.version pkg |> OpamPackage.Version.to_string
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
