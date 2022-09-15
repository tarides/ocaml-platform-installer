open Import
open Result.Syntax
open Astring

let opam_file () =
  {|opam-version: "2.0"
synopsis: "The OCaml compiler (system version, from outside of opam)"
maintainer: "platform@lists.ocaml.org"
license: "LGPL-2.1-or-later WITH OCaml-LGPL-linking-exception"
authors: "Xavier Leroy and many contributors"
homepage: "https://ocaml.org"
bug-reports: "https://github.com/ocaml/opam-repository/issues"
dev-repo: "git+https://github.com/ocaml/ocaml"
depends: [
  "ocaml" {post}
  "base-unix" {post}
  "base-threads" {post}
  "base-bigarray" {post}
]
conflict-class: "ocaml-core-compiler"
flags: compiler
build: ["ocaml" "gen_ocaml_config.ml"]
substs: "gen_ocaml_config.ml"
extra-files: ["gen_ocaml_config.ml.in" "md5=c2a459eda2f5a95e67cd4114447b8a1b"]
|}

let extra_file =
  {|let () =
  let exe = ".exe" in
  let ocamlc =
    let (base, suffix) =
      let s = Sys.executable_name in
      if Filename.check_suffix s exe then
        (Filename.chop_suffix s exe, exe)
      else
        (s, "") in
    base ^ "c" ^ suffix in
  let ocamlc_digest = Digest.to_hex (Digest.file ocamlc) in
  let libdir =
    if Sys.command (ocamlc^" -where > %{_:name}%.config") = 0 then
      let ic = open_in "%{_:name}%.config" in
      let r = input_line ic in
      close_in ic;
      Sys.remove "%{_:name}%.config";
      r
    else
      failwith "Bad return from 'ocamlc -where'"
  in
  let graphics = Filename.concat libdir "graphics.cmi" in
  let graphics_digest =
    if Sys.file_exists graphics then
      Digest.to_hex (Digest.file graphics)
    else
      String.make 32 '0'
  in
  let oc = open_out "%{_:name}%.config" in
  Printf.fprintf oc "opam-version: \"2.0\"\n\
                     file-depends: [ [ %%S %%S ] [ %%S %%S ] ]\n\
                     variables { path: %%S }\n"
    ocamlc ocamlc_digest graphics graphics_digest (Filename.dirname ocamlc);
  close_out oc
|}

(** The [~alpha...+...] suffix needs to be removed when overriding the [ocaml]
    package. *)
let remove_alpha_plus_suffix ver =
  let cut sep s = match String.cut ~sep s with Some (s, _) -> s | None -> s in
  cut "+" (cut "~" ver)

(** Override the [ocaml-system] package to drop the [sys-ocaml-version]
    constraint and to specify the right version for it, for example
    [ocaml-system.5.0.0~alpha0] doesn't exist. *)
let init_pkg_ocaml_system repo ~ocaml_version =
  let pkg = Package.v ~name:"ocaml-system" ~ver:ocaml_version in
  if Repo.has_pkg repo pkg then Ok ()
  else
    let opam_file = Package.Opam_file.of_string @@ opam_file () in
    let install_file =
      Package.Install_file.v String.Map.empty ~pkg_name:(Package.name pkg)
    in
    let extra_files = [ ("gen_ocaml_config.ml.in", extra_file) ] in
    Repo.add_package repo pkg ~extra_files ~install_file opam_file

let init opam_opts ocaml_version =
  let ocaml_version = remove_alpha_plus_suffix ocaml_version in
  let name = "platform_sandbox_compiler_packages" in
  let path =
    Fpath.(opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform" / name)
  in
  let* repo = Repo.init ~name path in
  let* () = init_pkg_ocaml_system repo ~ocaml_version in
  Ok (repo, "ocaml-system." ^ ocaml_version)
