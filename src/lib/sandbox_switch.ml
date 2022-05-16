open Bos
open Import
open Result.Syntax
module OV = Ocaml_version

type t = { ocaml_version : OV.t; prefix : Fpath.t }

let switch_name ov = Fmt.str "opam-tools-%s" (OV.to_string ov)
let ocaml_version t = t.ocaml_version

let init ~ocaml_version =
  Opam.opam_run_l Cmd.(v "switch" % "list" % "-s") >>= fun all_sw ->
  let sw = switch_name ocaml_version in
  (match List.exists (( = ) sw) all_sw with
  | true -> Ok ()
  | false ->
      Logs.info (fun l -> l "Creating switch %s to use for tools" sw);
      Opam.opam_run
        Cmd.(
          v "switch" % "create" % sw % OV.to_string ocaml_version
          % "--no-switch"))
  >>= fun _ ->
  Opam.opam_run_s Cmd.(v "config" % "--switch" % sw % "var" % "prefix")
  >>| fun prefix -> { ocaml_version; prefix = Fpath.v @@ String.trim prefix }

let remove t =
  Opam.opam_run_s Cmd.(v "switch" % "remove" % switch_name t.ocaml_version)

let a_switch t = Cmd.(v "--switch" % switch_name t.ocaml_version)

let pin t ~pkg ~url =
  Opam.opam_run Cmd.(v "pin" %% a_switch t % "add" % "-ny" % pkg % url)

let pkg_to_string (pkg_name, pkg_ver) =
  match pkg_ver with None -> pkg_name | Some ver -> pkg_name ^ "." ^ ver

let install t ~pkg =
  let pkg = pkg_to_string pkg in
  Opam.opam_run Cmd.(v "install" %% a_switch t % "-y" % pkg)

let list_files t ~pkg =
  Opam.opam_run_l Cmd.(v "show" %% a_switch t % "--list-files" % pkg)
  >>| fun files -> List.map Fpath.v files

let switch_path_prefix t = t.prefix

let with_sandbox_switch ~ocaml_version f =
  let* sandbox = init ~ocaml_version in
  Fun.protect
    ~finally:(fun () -> ignore @@ remove sandbox)
    (fun () -> f sandbox)
