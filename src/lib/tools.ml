open! Import
open Astring
open Bos
module OV = Ocaml_version
open Result.Syntax

type tool = { name : string; pure_binary : bool; version : string option }
(* FIXME: Once we use the opam library, let's use something like
   [OpamPackage.Name.t] for the type of [name] and something like ... for the
   type of [compiler_constr].*)

let parse_constraints s =
  let open Angstrom in
  let is_whitespace = function
    | '\x20' | '\x0a' | '\x0d' | '\x09' -> true
    | _ -> false
  in
  let whitespace = take_while is_whitespace in
  let whitespaced p = whitespace *> p <* whitespace in
  let quoted p = whitespaced @@ (char '"' *> p) <* char '"' in
  let bracketed p = whitespaced @@ (char '{' *> p) <* char '}' in
  let quoted_ocaml = quoted @@ string "ocaml" in
  let quoted_version =
    quoted @@ take_till (( = ) '"') >>| fun version_string ->
    OV.of_string_exn version_string
  in
  let comparator =
    whitespaced @@ take_till is_whitespace >>= function
    | "<" -> return `Lt
    | "<=" -> return `Le
    | ">" -> return `Gt
    | ">=" -> return `Ge
    | "=" -> return `Eq
    | _ -> fail "not a comparator"
  in
  let constraint_ = both comparator quoted_version in
  let constraints = sep_by (whitespaced @@ char '&') constraint_ in
  let finally = quoted_ocaml *> bracketed constraints <* end_of_input in
  match parse_string ~consume:Consume.All finally s with
  | Ok a -> Ok a
  | Error m -> Error (`Msg m)

let verify_constraint version (op, constraint_version) =
  let d = OV.compare version constraint_version in
  match op with
  | `Le -> d <= 0
  | `Lt -> d < 0
  | `Ge -> d >= 0
  | `Gt -> d > 0
  | `Eq -> d = 0

let verify_constraints version constraints =
  List.for_all (verify_constraint version) constraints

let best_available_version opam_opts ocaml_version name =
  let open Result.Syntax in
  let* ocaml_version = OV.of_string ocaml_version in
  let+ versions = Opam.Show.available_versions opam_opts name in
  let version =
    versions
    |> List.find (fun version ->
           let ocaml_depends =
             let+ depends =
               Opam.Show.depends opam_opts (name ^ "." ^ version)
             in
             List.find_opt (String.is_prefix ~affix:"\"ocaml\"") depends
           in
           match ocaml_depends with
           | Ok (Some ocaml_constraint) ->
               let result =
                 parse_constraints ocaml_constraint >>| fun constraints ->
                 verify_constraints ocaml_version constraints
               in
               Result.value ~default:false result
           | Ok None -> true
           | _ -> false)
  in
  version

let best_version_of_tool opam_opts ocaml_version tool =
  (match tool.version with
  | Some ver -> Ok ver
  | None -> best_available_version opam_opts ocaml_version tool.name)
  >>| fun ver ->
  Binary_package.binary_name ~ocaml_version ~name:tool.name ~ver
    ~pure_binary:tool.pure_binary

let make_binary_package opam_opts ~ocaml_version sandbox repo bname tool =
  let { name; pure_binary; _ } = tool in
  let* () =
    Sandbox_switch.install opam_opts sandbox ~pkg:(tool.name, tool.version)
  in
  let* arch = Opam.Config.Var.get opam_opts "arch" in
  let* os_distribution = Opam.Config.Var.get opam_opts "os-distribution" in
  let archive_path = Binary_repo.archive_path repo bname in
  let prefix = Sandbox_switch.switch_path_prefix sandbox in
  let* files = Sandbox_switch.list_files opam_opts sandbox ~pkg:name in
  let* bpkg =
    Binary_package.make_binary_package ~ocaml_version ~arch ~os_distribution
      ~prefix ~files ~archive_path bname ~name ~pure_binary
  in
  Binary_repo.add_binary_package repo bname bpkg

(** This version is used to select the highest available version of the tools
    and also to override the [ocaml-system] package declaration in the sandbox. *)
let installed_ocaml_version opam_opts =
  Opam.Config.Var.get opam_opts "ocaml:compiler"

let install opam_opts tools =
  let binary_repo_path =
    Fpath.(
      opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform" / "cache")
  in
  let* ocaml_version = installed_ocaml_version opam_opts in
  let* repo = Binary_repo.init binary_repo_path in
  (* [tools_to_build] is the list of tools that need to be built and placed in
     the cache. [tools_to_install] is the names of the packages to install into
     the user's switch, each string is a suitable argument to [opam install]. *)
  Logs.app (fun m -> m "* Inferring tools version...");
  let* tools_to_build, tools_to_install =
    let* version_list =
      Opam.Show.installed_versions opam_opts
        (List.map (fun tool -> tool.name) tools)
    in
    Result.List.fold_left
      (fun (to_build, to_install) tool ->
        let pkg_version = List.assoc_opt tool.name version_list in
        match pkg_version with
        | Some (Some _) ->
            Logs.app (fun m -> m "  -> %s is already installed" tool.name);
            Ok (to_build, to_install)
        | _ ->
            let+ bname = best_version_of_tool opam_opts ocaml_version tool in
            Logs.app (fun m ->
                m "  -> %s will be installed as %s" tool.name
                  (Binary_package.to_string bname));
            let to_build =
              if Binary_repo.has_binary_pkg repo bname then to_build
              else (tool, bname) :: to_build
            in
            (to_build, Binary_package.to_string bname :: to_install))
      ([], []) tools
  in
  (match tools_to_build with
  | [] -> Ok ()
  | _ :: _ ->
      Logs.app (fun m -> m "* Building the tools...");
      Logs.app (fun m -> m "  -> Creating a sandbox...");
      Sandbox_switch.with_sandbox_switch opam_opts ~ocaml_version
        (fun sandbox ->
          let n = List.length tools_to_build in
          Result.List.fold_left
            (fun () (i, (tool, bname)) ->
              Logs.app (fun m ->
                  m "  -> [%d/%d] Building %s..." (i + 1) n tool.name);
              make_binary_package opam_opts ~ocaml_version sandbox repo bname
                tool)
            ()
            (List.mapi (fun i s -> (i, s)) tools_to_build)))
  >>= fun () ->
  match tools_to_install with
  | [] ->
      Logs.app (fun m -> m "  -> All tools are already installed");
      Ok ()
  | _ ->
      let+ () =
        let repo = Binary_repo.repo repo in
        Installed_repo.with_repo_enabled opam_opts repo (fun () ->
            let* () = Installed_repo.update opam_opts repo in
            Logs.app (fun m -> m "* Installing tools...");
            Opam.install
              { opam_opts with log_height = Some 10 }
              tools_to_install)
      in
      Logs.app (fun m ->
          m
            "  -> All tools installed. For more information on the platform \
             tools, run `ocaml-platform --help`");
      Logs.app (fun m -> m "* Success.")

let find_ocamlformat_version () =
  match OS.File.read_lines (Fpath.v ".ocamlformat") with
  | Ok f ->
      List.filter_map
        (fun s ->
          Astring.String.cut ~sep:"=" s |> function
          | Some (a, b) -> Some (String.trim a, String.trim b)
          | None -> None)
        f
      |> List.assoc_opt "version"
  | Error (`Msg _) -> None

(** TODO: This should be moved to an other module to for example do automatic
    recognizing of ocamlformat's version. *)
let platform () =
  [
    { name = "dune"; pure_binary = true; version = None };
    { name = "dune-release"; pure_binary = false; version = None };
    { name = "merlin"; pure_binary = false; version = None };
    { name = "ocaml-lsp-server"; pure_binary = false; version = None };
    { name = "odoc"; pure_binary = false; version = None };
    {
      name = "ocamlformat";
      pure_binary = false;
      version = find_ocamlformat_version ();
    };
  ]
