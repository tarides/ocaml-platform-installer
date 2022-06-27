open! Import
open Astring
open Bos
open Result.Syntax

type tool = { name : string; pure_binary : bool; version : string option }
(* FIXME: Once we use the opam library, let's use something like
   [OpamPackage.Name.t] for the type of [name] and something like ... for the
   type of [compiler_constr].*)

let best_version ~metadata_universe ~pkg_universe ~ocaml tool =
  (match tool.version with
  | Some ver -> Ok ver
  | None -> (
      match
        Opam.Queries.latest_version ~metadata_universe ~pkg_universe:(Lazy.force pkg_universe) ~ocaml
          tool.name
      with
      | Some ver -> Ok (Opam.Conversions.version_of_pkg ver)
      | None ->
          Result.errorf
            "Something went wrong trying to find the best version for %s"
            tool.name))
  >>| fun ver ->
  Binary_package.binary_name ~ocaml ~name:tool.name ~ver
    ~pure_binary:tool.pure_binary

let make_binary_package opam_opts ~ocaml sandbox repo bname tool =
  let { name; pure_binary; _ } = tool in
  Sandbox_switch.install opam_opts sandbox ~pkg:(tool.name, tool.version)
  >>= fun () ->
  Binary_package.make_binary_package opam_opts ~ocaml sandbox repo bname ~name
    ~pure_binary

let install opam_opts tools =
  let binary_repo_path =
    Fpath.(
      opam_opts.Opam.GlobalOpts.root / "plugins" / "ocaml-platform" / "cache")
  in
  let tools_names = List.map (fun tool -> tool.name) tools in
  let installed =
    Opam.Queries.(
      with_switch_state_sel (installed_versions ("ocaml" :: tools_names)))
  in
  (match List.assoc_opt "ocaml" installed with
  | Some (Some s) -> Ok s
  | _ ->
      Result.errorf "Cannot install tools: No switch with compiler is selected.")
  >>= fun ocaml ->
  Binary_repo.init opam_opts binary_repo_path >>= fun repo ->
  (* [tools_to_build] is the list of tools that need to be built and placed in
     the cache. [tools_to_install] is the names of the packages to install into
     the user's switch, each string is a suitable argument to [opam install]. *)
  Logs.app (fun m -> m "Inferring tools version...");
  let* tools_to_build, tools_to_install =
    let pkg_universe, metadata_universe =
      Opam.Queries.(
        with_virtual_state (fun state ->
            (get_pkg_universe state, get_metadata_universe state)))
    in
    Result.List.fold_left
      (fun (to_build, to_install) tool ->
        let pkg_version = List.assoc_opt tool.name installed in
        match pkg_version with
        | Some (Some _) ->
            Logs.info (fun m -> m "%s is already installed" tool.name);
            Ok (to_build, to_install)
        | _ ->
            let+ bname =
              best_version ~metadata_universe ~pkg_universe ~ocaml tool
            in
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
      Sandbox_switch.with_sandbox_switch opam_opts ~ocaml (fun sandbox ->
          Result.List.fold_left
            (fun () (tool, bname) ->
              Logs.app (fun m -> m "Building %s..." tool.name);
              make_binary_package opam_opts ~ocaml sandbox repo bname tool)
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
