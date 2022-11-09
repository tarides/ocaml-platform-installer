open Astring
open Bos
open Import
open Result.Syntax

type t = {
  sandbox_opts : Opam.GlobalOpts.t;
      (** Opam options to use when running command targeting the switch. *)
  prefix : Fpath.t;
      (** Root directory of the switch, containing [bin/], [lib/], etc.. *)
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
let with_compiler_path parent_prefix f =
  with_tmp_dir "system-compiler" @@ fun compiler_path ->
  let ( / ) = Fpath.( / ) in
  let parent_prefix = parent_prefix / "bin" in
  let* () =
    Result.List.fold_left
      (fun () fname ->
        Result.List.fold_left
          (fun () suffix ->
            let fname = fname ^ suffix in
            let target = parent_prefix / fname
            and dst = compiler_path / fname in
            let* exists = OS.File.exists target in
            if exists then OS.Path.symlink ~target dst else Ok ())
          () compiler_suffixes)
      () compiler_tools
  in
  f compiler_path

(** The [switch] field will be passed with [--switch] and [env] is used to set
    the [PATH] variable. *)
let make_sandbox_opts opam_opts ~compiler_path ~sandbox_root =
  let+ env =
    let+ env = OS.Env.current () in
    let path =
      match String.Map.find "PATH" env with Some p -> p | None -> ""
    in
    let path = Fpath.to_string compiler_path ^ ":" ^ path in
    String.Map.add "PATH" path env
  in
  let switch = Some (Fpath.to_string sandbox_root) in
  { opam_opts with Opam.GlobalOpts.switch; env = Some env }

let with_opam_switch ~ocaml_version opam_opts name f =
  (* Remove the sandbox switch from Opam's state. It's not a big deal if this
     fails or is never run due to a Ctrl+C, Opam will cleanup its state the next
     time it does a read-write operation. *)
  let* () = Opam.Switch.create ~ocaml_version opam_opts name in
  let finally () = ignore (Opam.Switch.remove opam_opts name) in
  Fun.protect ~finally f

let with_sandbox_switch opam_opts ~ocaml_version f =
  (* Directory in which to create the switch. *)
  with_tmp_dir "sandbox" @@ fun sandbox_root ->
  let* parent_prefix = Opam.Config.Var.get opam_opts "prefix" in
  (* PATH containing the parent compiler. *)
  with_compiler_path (Fpath.v parent_prefix) @@ fun compiler_path ->
  Logs.info (fun l -> l "Creating sandbox switch for building the tools");
  with_opam_switch ~ocaml_version:None opam_opts (Fpath.to_string sandbox_root)
  @@ fun () ->
  (* Options for running commands inside the new switch. *)
  let* sandbox_opts =
    make_sandbox_opts opam_opts ~compiler_path ~sandbox_root
  in
  (* Patched compiler package description. *)
  Sandbox_compiler_package.with_sandbox_compiler_repo sandbox_opts ocaml_version
  @@ fun compiler_package ->
  let* () = Opam.install sandbox_opts [ compiler_package ] in
  let* prefix = Opam.Config.Var.get sandbox_opts "prefix" >>| Fpath.v in
  f { sandbox_opts; prefix }

let pkg_to_string (pkg_name, pkg_ver) = pkg_name ^ "." ^ pkg_ver

let install _opam_opts t ~pkg =
  let pkg = pkg_to_string pkg in
  Opam.install { t.sandbox_opts with log_height = Some 10 } [ pkg ]

let list_files _opam_opts t ~pkg =
  let+ files = Opam.Show.list_files t.sandbox_opts pkg in
  List.map Fpath.v files

let switch_path_prefix t = t.prefix
