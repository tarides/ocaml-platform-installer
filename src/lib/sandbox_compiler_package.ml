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
extra-files: ["gen_ocaml_config.ml.in" "md5=093e7bec1ec95f9e4c6a313d73c5d840"]
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
  if Sys.ocaml_version <> "%{_:version}%" then
    (Printf.eprintf
       "ERROR: The compiler found at %%s has version %%s,\n\
        and this package requires %{_:version}%.\n\
        You should use e.g. 'opam switch create %{_:name}%.%%s' \
        instead."
       ocamlc Sys.ocaml_version Sys.ocaml_version;
     exit 1)
  else
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

(** The [~alpha...] suffix needs to be removed when overriding the [ocaml]
    package. *)
let remove_alpha_suffix ver =
  match String.cut ~sep:"~" ver with Some (pre, _) -> pre | None -> ver

(** Lookup in the selected switch. *)
let lookup_ocaml_descr opam_opts = Opam.Show.opam_file opam_opts ~pkg:"ocaml"

(** Fix [ocaml]'s constraint on [ocaml-system], which disallow alpha versions. *)
let fix_ocaml_constraints opam_file ~ocaml_version =
  let open OpamParserTypes.FullPos in
  let with_pos f wp = { wp with pelem = f wp.pelem } in
  let fake_pos pelem =
    { pelem; pos = { filename = ""; start = (0, 0); stop = (0, 0) } }
  in
  let name_is_ocaml t =
    match t.pelem with String "ocaml-system" -> true | _ -> false
  in
  let rec fix_depend = function
    | Option (name, _args) when name_is_ocaml name ->
        let cnstr =
          Prefix_relop (fake_pos `Eq, fake_pos (String ocaml_version))
        in
        Option (name, fake_pos [ fake_pos cnstr ])
    | Logop (op, left, right) ->
        Logop (op, with_pos fix_depend left, with_pos fix_depend right)
    | t -> t
  in
  let fix_depends = function
    | List elems -> List (with_pos (List.map (with_pos fix_depend)) elems)
    | t -> t
  in
  let fix_item = function
    | Variable (({ pelem = "depends"; _ } as name), value) ->
        Variable (name, with_pos fix_depends value)
    | t -> t
  in
  let fix_opamfile t =
    { t with file_contents = List.map (with_pos fix_item) t.file_contents }
  in
  OpamParser.FullPos.string opam_file "ocaml"
  |> fix_opamfile |> OpamPrinter.FullPos.opamfile

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

(** Override the [ocaml] package to fix the dependency it has on [ocaml-system],
    which disallow [~] suffixes. The [ocaml] package itself must not use a [~]
    suffix. *)
let init_pkg_ocaml opam_opts repo ~ocaml_version =
  let pkg = Package.v ~name:"ocaml" ~ver:(remove_alpha_suffix ocaml_version) in
  if Repo.has_pkg repo pkg then Ok ()
  else
    let* opam_file = lookup_ocaml_descr opam_opts in
    let opam_file = fix_ocaml_constraints opam_file ~ocaml_version in
    Repo.add_package repo pkg (Package.Opam_file.of_string opam_file)

let init opam_opts ocaml_version =
  let name = "platform_sandbox_compiler_packages" in
  let path =
    Fpath.(opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform" / name)
  in
  let* repo = Repo.init ~name path in
  let* () = init_pkg_ocaml_system repo ~ocaml_version in
  let* () = init_pkg_ocaml opam_opts repo ~ocaml_version in
  Ok repo
