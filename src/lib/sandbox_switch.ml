open Bos_setup
open Import
open Result.Syntax

type t = {
  sandbox_opts : Opam.GlobalOpts.t;
      (** Opam options to use when running command targeting the switch. *)
  switch_name : string;
  prefix : Fpath.t;
      (** Root directory of the switch, containing [bin/], [lib/], etc.. *)
  compiler_path : Fpath.t;
      (** A folder containing symlinks to the compiler tools. Created during
          [init] and removed during [deinit]. *)
}

let compiler_tools =
  [
    "ocaml";
    "ocamlc";
    "ocamlcmt";
    "ocamlcp";
    "ocamldebug";
    "ocamldep";
    "ocamldoc";
    "ocamllex";
    "ocamlmklib";
    "ocamlmktop";
    "ocamlobjinfo";
    "ocamlopt";
    "ocamloptp";
    "ocamlprof";
    "ocamlrun";
    "ocamlrund";
    "ocamlruni";
    "ocamlyacc";
  ]

let compiler_suffixes = [ ""; ".opt"; ".byte" ]

(** Make the [compiler_path] directory. [parent_prefix] is the prefix of the
    switch from which we reuse the compiler. *)
let make_compiler_path parent_prefix =
  let* compiler_path = OS.Dir.tmp "ocaml-platform-system-compiler-%s" in
  let ( / ) = Fpath.( / ) in
  let parent_prefix = parent_prefix / "bin" in
  let+ () =
    Result.fold_list
      (fun () fname ->
        Result.fold_list
          (fun () suffix ->
            let fname = fname ^ suffix in
            let target = parent_prefix / fname
            and dst = compiler_path / fname in
            let* exists = OS.File.exists target in
            if exists then OS.Path.symlink ~target dst else Ok ())
          compiler_suffixes ())
      compiler_tools ()
  in
  compiler_path

(** The [ocaml-system] package requires this option to be set to the right
    version of OCaml to be installable (it has a solver constraint on it). *)
let with_var_sys_ocaml_version opam_opts ~ocaml_version f =
  let var = "sys-ocaml-version" and global = true in
  let* prev_value = Opam.Config.Var.get_opt opam_opts var in
  let restore_var () =
    ignore
      (match prev_value with
      | Some x -> Opam.Config.Var.set opam_opts ~global var x
      | None -> Opam.Config.Var.unset opam_opts ~global var)
  in
  let* () = Opam.Config.Var.set opam_opts ~global var ocaml_version in
  Fun.protect ~finally:restore_var f

let init opam_opts ~ocaml_version =
  let ocaml_version = Ocaml_version.to_string ocaml_version in
  let* all_sw = Opam.Switch.list opam_opts in
  let sw = Fmt.str "opam-tools-%s" ocaml_version in
  let* compiler_path =
    let* parent_prefix = Opam.Config.Var.get opam_opts "prefix" in
    make_compiler_path (Fpath.v parent_prefix)
  in
  let* sandbox_opts =
    (* The [switch] field will be passed with [--switch] and [env] is used to
       set the [PATH] variable. *)
    let+ env =
      let+ env = OS.Env.current () in
      let path =
        match String.Map.find "PATH" env with Some p -> p | None -> ""
      in
      let path = Fpath.to_string compiler_path ^ ":" ^ path in
      String.Map.add "PATH" path env
    in
    { opam_opts with switch = Some sw; env = Some env }
  in
  let* prefix = Opam.Config.Var.get sandbox_opts "prefix" >>| Fpath.v in
  let* () =
    if List.exists (( = ) sw) all_sw then Ok ()
    else (
      Logs.info (fun l -> l "Creating switch %s to use for tools" sw);
      let* () = Opam.Switch.create ~ocaml_version:None opam_opts sw in
      with_var_sys_ocaml_version opam_opts ~ocaml_version (fun () ->
          Opam.install sandbox_opts [ "ocaml-system" ]))
  in
  Ok { sandbox_opts; switch_name = sw; prefix; compiler_path }

let deinit opam_opts t =
  (* Ignore errors, don't stop deiniting. *)
  ignore (Opam.Switch.remove opam_opts t.switch_name);
  (* Deleting [compiler_path] is not strictly necessary, it will also be done at
     [at_exit]. *)
  ignore (OS.Dir.delete ~recurse:true t.compiler_path);
  ()

let pkg_to_string (pkg_name, pkg_ver) =
  match pkg_ver with None -> pkg_name | Some ver -> pkg_name ^ "." ^ ver

let install _opam_opts t ~pkg =
  let pkg = pkg_to_string pkg in
  Opam.install t.sandbox_opts [ pkg ]

let list_files _opam_opts t ~pkg =
  let+ files = Opam.Show.list_files t.sandbox_opts pkg in
  List.map Fpath.v files

let switch_path_prefix t = t.prefix

let with_sandbox_switch opam_opts ~ocaml_version f =
  let* sandbox = init opam_opts ~ocaml_version in
  Fun.protect
    ~finally:(fun () -> deinit opam_opts sandbox)
    (fun () -> f sandbox)
