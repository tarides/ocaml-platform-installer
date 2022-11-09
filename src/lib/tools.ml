open! Import
open Astring
open Rresult
open Bos
module OV = Ocaml_version
open Result.Syntax

type tool = {
  name : string;
  pure_binary : bool;
  required_version : string option;  (** Version required by the project. *)
  ocaml_version_dependent : bool;
}

module Communication = struct
  let list_plural singular plural ppf list =
    match list with
    | [ _ ] -> Format.fprintf ppf "%s" singular
    | _ -> Format.fprintf ppf "%s" plural

  let enter_version_stage () =
    Logs.app (fun m -> m "* Inferring tools version...")

  let enter_building_stage () = Logs.app (fun m -> m "* Building the tools...")

  let enter_creating_sandbox () =
    Logs.app (fun m -> m "  -> Creating a sandbox...")

  let building_tool tool_name i n =
    Logs.app (fun m -> m "  -> [%d/%d] Building %s..." (i + 1) n tool_name)

  let error_in_build tool_name =
    Logs.warn (fun m -> m "There was an error during build of %s." tool_name)

  let conclusion tools_non_installable tools_failed =
    let not_installed = tools_non_installable @ List.map fst tools_failed in
    match not_installed with
    | [] ->
        Logs.app (fun m -> m "* Success.");
        Logs.app (fun m ->
            m
              "* For more information on the platform tools, run \
               `ocaml-platform --help`")
    | tools_not_installed ->
        Logs.app (fun m ->
            m
              "  -> The following %a been installed: %a. Run with `-v` for \
               more information."
              (list_plural "tool hasn't" "tools haven't")
              tools_not_installed
              Fmt.(list ~sep:(any ", ") string)
              tools_not_installed)

  let conclusion_installing = function
    | [] -> Logs.app (fun m -> m "  -> Nothing to install.")
    | tools_to_install ->
        Logs.app (fun m ->
            m "  -> The following %a now installed: %a."
              (list_plural "tool is" "tools are")
              tools_to_install
              Fmt.(list ~sep:(any ", ") string)
              (List.map fst tools_to_install))

  let enter_install_stage () = Logs.app (fun m -> m "* Installing tools...")

  let tell_version_result tool r ocaml_version =
    match r with
    | `Skip -> Logs.app (fun m -> m "  -> %s is already installed" tool.name)
    | `Install (version, Some _, _) ->
        let action_s = "built from source" in
        Logs.app (fun m -> m "  -> %s.%s will be %s" tool.name version action_s)
    | `Install (version, None, _) ->
        let action_s = "installed from cache" in
        Logs.app (fun m -> m "  -> %s.%s will be %s" tool.name version action_s)
    | `Not_available ->
        Logs.warn (fun m ->
            m "%s cannot be installed with OCaml %s" tool.name ocaml_version)
    | `Error _ -> ()
end

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

(** Find the highest version of a package compatible with the given version of
    OCaml. Returns [None] if no version match. *)
let best_available_version opam_opts ocaml_version name =
  let open Result.Syntax in
  let* ocaml_version = OV.of_string ocaml_version in
  let+ versions = Opam.Show.available_versions opam_opts name in
  versions
  |> List.find_opt (fun version ->
         let ocaml_depends =
           let+ depends = Opam.Show.depends opam_opts (name ^ "." ^ version) in
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

(** The version of a tool that should be installed. Might returns the error
    [`Not_found]. *)
let best_version_of_tool opam_opts ocaml_version tool =
  (match tool.required_version with
  | Some _ as ver -> Ok ver
  | None -> best_available_version opam_opts ocaml_version tool.name)
  >>= function
  | Some ver -> Ok ver
  | None -> Error `Not_found

let make_binary_package opam_opts ~ocaml_version sandbox repo bname ~version
    tool =
  let { name; pure_binary; _ } = tool in
  let* () =
    Sandbox_switch.install opam_opts sandbox ~pkg:(tool.name, version)
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

(** This function returns the package corresponding to the current compiler. The
    package name will be used to check if we can use the cache. The version will
    be used to select the highest available version of the tools and also to
    override the [ocaml-system] package declaration in the sandbox. *)
let get_compiler_pkg opam_opts =
  let* name = Opam.List_.compiler opam_opts () in
  match name with
  | Some (("ocaml-system" | "ocaml-variants" | "ocaml-base-compiler") as name)
    ->
      let* ver = Opam.Show.version opam_opts name in
      let* pin = Opam.Show.pin opam_opts name in
      Ok (Package.v ~name ~ver, pin <> "")
  | Some name ->
      R.error_msgf "Installing tools for compiler '%s' is not supported." name
  | None -> R.error_msgf "No compiler installed in your current switch."

let should_install_pkg opam_opts ~version_list ~ocaml_version ~cache tool =
  let { name; pure_binary; ocaml_version_dependent; required_version } = tool in
  let already_installed =
    match (List.assoc_opt name version_list, required_version) with
    | Some installed, Some required -> installed = required
    | Some _, None -> true
    | None, _ -> false
  in
  if already_installed then `Skip
  else
    match best_version_of_tool opam_opts ocaml_version tool with
    | Ok version ->
        let bname =
          Binary_package.binary_name ~ocaml_version ~name ~ver:version
            ~pure_binary ~ocaml_version_dependent
        in
        let build =
          if Cache.has_binary_pkg cache ~ocaml_version_dependent bname then None
          else
            let build sandbox =
              let ocaml_version =
                if ocaml_version_dependent then Some ocaml_version else None
              in
              make_binary_package opam_opts ~ocaml_version sandbox
                (Cache.push_repo cache) bname ~version tool
            in
            Some build
        in
        `Install (version, build, Binary_package.to_string bname)
    | Error `Not_found -> `Not_available
    | Error (`Msg _ as err) -> `Error err

let install opam_opts tools =
  let* compiler_pkg, pinned = get_compiler_pkg opam_opts in
  let ocaml_version = Package.ver compiler_pkg in
  Cache.load opam_opts ~pinned @@ fun cache ->
  (* [tools_to_build] is the list of tools that need to be built and placed in
     the cache. [tools_to_install] is the names of the packages to install into
     the user's switch, each string is a suitable argument to [opam install]. *)
  Communication.enter_version_stage ();
  let* tools_to_build, tools_in_cache, tools_non_installable =
    let* version_list =
      Opam.Show.installed_versions opam_opts
        (List.map (fun tool -> tool.name) tools)
    in
    Result.List.fold_left
      (fun ((to_build, in_cache, non_installable) as acc) tool ->
        let action =
          should_install_pkg opam_opts ~version_list ~ocaml_version ~cache tool
        in
        Communication.tell_version_result tool action ocaml_version;
        match action with
        | `Skip -> Ok acc
        | `Install (_, Some build, install) ->
            let to_build = ((tool.name, install), build) :: to_build in
            Ok (to_build, in_cache, non_installable)
        | `Install (_, None, install) ->
            let in_cache = (tool.name, install) :: in_cache in
            Ok (to_build, in_cache, non_installable)
        | `Not_available -> Ok (to_build, in_cache, tool.name :: non_installable)
        | `Error err -> Error err)
      ([], [], []) tools
  in
  (if tools_to_build <> [] then (
   Communication.enter_building_stage ();
   Communication.enter_creating_sandbox ();
   Sandbox_switch.with_sandbox_switch opam_opts ~ocaml_version (fun sandbox ->
       let n = List.length tools_to_build in
       Ok
         (List.fold_left
            (fun (tools_built, tools_failed)
                 (i, ((tool_name, tool_version), build)) ->
              Communication.building_tool tool_name i n;
              match build sandbox with
              | Ok () -> ((tool_name, tool_version) :: tools_built, tools_failed)
              | Error e ->
                  Communication.error_in_build tool_name;
                  (tools_built, (tool_name, e) :: tools_failed))
            ([], [])
            (List.mapi (fun i s -> (i, s)) tools_to_build))))
  else Ok ([], []))
  >>= fun (tools_built, tools_failed) ->
  (Communication.enter_install_stage ();
   let tools_to_install = tools_in_cache @ tools_built in
   let* () =
     Cache.with_repos_enabled opam_opts cache @@ fun () ->
     Opam.install
       { opam_opts with log_height = Some 10 }
       (List.map snd tools_to_install)
   in
   Communication.conclusion_installing tools_to_install;
   Ok tools_failed)
  >>= fun tools_failed ->
  Communication.conclusion tools_non_installable tools_failed;
  if tools_failed <> [] then Error (`Multi (List.map snd tools_failed))
  else Ok ()

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
  let tool ?(pure_binary = false) ?(required_version = None)
      ?(ocaml_version_dependent = true) name =
    { name; pure_binary; required_version; ocaml_version_dependent }
  in
  [
    tool ~pure_binary:true "dune";
    tool ~ocaml_version_dependent:false "dune-release";
    tool "merlin";
    tool "ocaml-lsp-server";
    tool "odoc";
    tool ~ocaml_version_dependent:false
      ~required_version:(find_ocamlformat_version ())
      "ocamlformat";
  ]
