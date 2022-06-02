open Bos
open Import
open Result.Syntax

type t = {
  sandbox_opts : Opam.GlobalOpts.t;
  switch_name : string;
  prefix : Fpath.t;
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

(** [parent_prefix] is the path to the current switch and [sandbox_prefix] of
    the newly created sandbox switch. *)
let symlink_parent_compiler parent_prefix sandbox_prefix =
  let ( / ) = Fpath.( / ) in
  let parent_prefix = parent_prefix / "bin"
  and sandbox_prefix = sandbox_prefix / "bin" in
  let* _ = OS.Dir.create ~path:false sandbox_prefix in
  Result.fold_list
    (fun () fname ->
      Result.fold_list
        (fun () suffix ->
          let fname = fname ^ suffix in
          let target = parent_prefix / fname and dst = sandbox_prefix / fname in
          let* exists = OS.File.exists target in
          if exists then OS.Path.symlink ~target dst else Ok ())
        compiler_suffixes ())
    compiler_tools ()

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
  let sandbox_opts = { opam_opts with switch = Some sw } in
  let* parent_prefix = Opam.Config.Var.get opam_opts "prefix" >>| Fpath.v in
  let* prefix = Opam.Config.Var.get sandbox_opts "prefix" >>| Fpath.v in
  let* () =
    if List.exists (( = ) sw) all_sw then Ok ()
    else (
      Logs.info (fun l -> l "Creating switch %s to use for tools" sw);
      let* () = Opam.Switch.create ~ocaml_version:None opam_opts sw in
      let* () = symlink_parent_compiler parent_prefix prefix in
      with_var_sys_ocaml_version opam_opts ~ocaml_version (fun () ->
          Opam.install sandbox_opts [ "ocaml-system" ]))
  in
  Ok { sandbox_opts; switch_name = sw; prefix }

let remove opam_opts t = Opam.Switch.remove opam_opts t.switch_name

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
    ~finally:(fun () -> ignore @@ remove opam_opts sandbox)
    (fun () -> f sandbox)
