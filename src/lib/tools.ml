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
  Sandbox_switch.install opam_opts sandbox ~pkg:(tool.name, tool.version)
  >>= fun () ->
  Binary_package.make_binary_package opam_opts ~ocaml_version sandbox repo bname
    ~name ~pure_binary

let install opam_opts tools =
  let binary_repo_path =
    Fpath.(
      opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform" / "cache")
  in
  let* ovraw = Opam.Show.installed_version opam_opts "ocaml" in
  (match ovraw with
  | None -> Result.errorf "Cannot install tools: No switch is selected."
  | Some s -> OV.of_string s)
  >>= fun ocaml_version ->
  Binary_repo.init opam_opts binary_repo_path >>= fun repo ->
  (* [tools_to_build] is the list of tools that need to be built and placed in
     the cache. [tools_to_install] is the names of the packages to install into
     the user's switch, each string is a suitable argument to [opam install]. *)
  Logs.app (fun m -> m "Inferring tools version...");
  let* tools_to_build, tools_to_install =
    let* version_list =
      Opam.Show.installed_versions opam_opts
        (List.map (fun tool -> tool.name) tools)
    in
    Result.fold_list
      (fun (to_build, to_install) tool ->
        let pkg_version = List.assoc_opt tool.name version_list in
        match pkg_version with
        | Some (Some _) ->
            Logs.info (fun m -> m "%s is already installed" tool.name);
            Ok (to_build, to_install)
        | _ ->
            let+ bname = best_version_of_tool opam_opts ocaml_version tool in
            Logs.info (fun m ->
                m "%s will be installed as %s" tool.name
                  (Binary_package.name_to_string bname));
            let to_build =
              if Binary_package.has_binary_package repo bname then to_build
              else (tool, bname) :: to_build
            in
            (to_build, Binary_package.name_to_string bname :: to_install))
      ([], []) tools
  in
  (match tools_to_build with
  | [] -> Ok ()
  | _ :: _ ->
      Logs.app (fun m -> m "Creating a sandbox to build the tools...");
      Sandbox_switch.with_sandbox_switch opam_opts ~ocaml_version
        (fun sandbox ->
          Result.fold_list
            (fun () (tool, bname) ->
              Logs.app (fun m -> m "Building %s..." tool.name);
              make_binary_package opam_opts ~ocaml_version sandbox repo bname
                tool)
            () tools_to_build))
  >>= fun () ->
  match tools_to_install with
  | [] ->
      Logs.app (fun m -> m "All tools are already installed");
      Ok ()
  | _ ->
      Repo.with_repo_enabled opam_opts (Binary_repo.repo repo) (fun () ->
          Logs.app (fun m -> m "Installing tools...");
          Opam.install opam_opts tools_to_install)

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
