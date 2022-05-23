open Import
open Result.Syntax
module OV = Ocaml_version

type t = { ocaml_version : OV.t; prefix : Fpath.t }

let switch_name ov = Fmt.str "opam-tools-%s" (OV.to_string ov)
let ocaml_version t = t.ocaml_version

let init ~ocaml_version =
  let* all_sw = Opam.Switch.list () in
  let sw = switch_name ocaml_version in
  let* _ =
    match List.exists (( = ) sw) all_sw with
    | true -> Ok ()
    | false ->
        Logs.info (fun l -> l "Creating switch %s to use for tools" sw);
        Opam.Switch.create ~ocaml_version:(OV.to_string ocaml_version) sw
  in
  let* prefix = Opam.Config.Var.get ~switch:sw "prefix" in
  Ok { ocaml_version; prefix = Fpath.v @@ String.trim prefix }

let remove t = Opam.Switch.remove (switch_name t.ocaml_version)

let pkg_to_string (pkg_name, pkg_ver) =
  match pkg_ver with None -> pkg_name | Some ver -> pkg_name ^ "." ^ ver

let install t ~pkg =
  let pkg = pkg_to_string pkg in
  Opam.install ~switch:(switch_name t.ocaml_version) [ pkg ]

let list_files t ~pkg =
  let+ files = Opam.Show.list_files ~switch:(switch_name t.ocaml_version) pkg in
  List.map Fpath.v files

let switch_path_prefix t = t.prefix

let with_sandbox_switch ~ocaml_version f =
  let* sandbox = init ~ocaml_version in
  Fun.protect
    ~finally:(fun () -> ignore @@ remove sandbox)
    (fun () -> f sandbox)
