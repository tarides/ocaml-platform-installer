open Import
open Result.Syntax
module OV = Ocaml_version

type t = { ocaml_version : OV.t; prefix : Fpath.t }

let switch_name ov = Fmt.str "opam-tools-%s" (OV.to_string ov)
let ocaml_version t = t.ocaml_version

let init opam_opts ~ocaml_version =
  let* all_sw = Opam.Switch.list opam_opts in
  let sw = switch_name ocaml_version in
  let* _ =
    match List.exists (( = ) sw) all_sw with
    | true -> Ok ()
    | false ->
        Logs.info (fun l -> l "Creating switch %s to use for tools" sw);
        Opam.Switch.create opam_opts
          ~ocaml_version:(OV.to_string ocaml_version)
          sw
  in
  let* prefix =
    Opam.Config.Var.get { opam_opts with switch = Some sw } "prefix"
  in
  Ok { ocaml_version; prefix = Fpath.v @@ String.trim prefix }

let remove opam_opts t =
  Opam.Switch.remove opam_opts (switch_name t.ocaml_version)

let pkg_to_string (pkg_name, pkg_ver) =
  match pkg_ver with None -> pkg_name | Some ver -> pkg_name ^ "." ^ ver

let install opam_opts t ~pkg =
  let pkg = pkg_to_string pkg and switch = Some (switch_name t.ocaml_version) in
  Opam.install { opam_opts with switch } [ pkg ]

let list_files opam_opts t ~pkg =
  let switch = Some (switch_name t.ocaml_version) in
  let+ files = Opam.Show.list_files { opam_opts with switch } pkg in
  List.map Fpath.v files

let switch_path_prefix t = t.prefix

let with_sandbox_switch opam_opts ~ocaml_version f =
  let* sandbox = init opam_opts ~ocaml_version in
  Fun.protect
    ~finally:(fun () -> ignore @@ remove opam_opts sandbox)
    (fun () -> f sandbox)
