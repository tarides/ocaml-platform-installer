let compiler_independent = [ "dune"; "utop"; "dune-release" ]
let compiler_dependent = [ "merlin"; "ocaml-lsp-server"; "odoc"; "ocamlformat" ]

type tool = { name : string }
(* FIXME: Once we use the opam library, let's use something like
   [OpamPackage.Name.t] for the type of [name] and something like ... for the
   type of [compiler_constr].*)

let parse_pkg_name_ver s =
  match String.cut ~sep:"." s with
  | Some (n, v) -> (n, Some v)
  | None -> (s, None)

let binary_name_of_tool sandbox tool =
  let name, ver = parse_pkg_name_ver tool in
  (match ver with
  | Some ver -> Ok ver
  | None ->
      Exec.run_opam_s Cmd.(v "show" % "-f" % "available-versions" % name)
      >>| fun versions ->
      let version =
        String.cuts ~sep:"  " versions
        |> List.rev
        |> List.find (fun version ->
               let ocaml_depends =
                 Exec.run_opam_l
                   Cmd.(v "show" % "-f" % "depends:" % (name ^ "." ^ version))
                 >>| List.find_opt (String.is_prefix ~affix:"\"ocaml\"")
               in
               match ocaml_depends with
               | Ok (Some ocaml_constraint) ->
                   let result =
                     parse_constraints ocaml_constraint >>= fun constraints ->
                     OV.of_string @@ Sandbox_switch.ocaml_version sandbox
                     >>| fun sandbox_version ->
                     verify_constraints sandbox_version constraints
                   in
                   Result.value ~default:false result
               | Ok None -> true
               | _ -> false)
      in
      version)
  >>| fun ver -> Binary_package.binary_name sandbox ~name ~ver

let make_binary_package sandbox repo bname tool =
  if Binary_package.has_binary_package repo bname then Ok ()
  else
    Sandbox_switch.install sandbox ~pkgs:[ tool.name ] >>= fun () ->
    Binary_package.make_binary_package sandbox repo bname ~original_name

let install_binary_tool sandbox repo tool =
  binary_name_of_tool sandbox tool.name >>= fun bname ->
  make_binary_package sandbox repo bname tool >>= fun () ->
  Repo.with_repo_enabled repo (fun () ->
      Exec.run_opam
        Cmd.(v "install" % "-y" % Binary_package.name_to_string bname))

let install opam_opts ~ocaml_version tools =
  Repo.init () >>= fun repo ->
  Sandbox_switch.init ~ocaml_version >>= fun sandbox ->
  Exec.iter (install_binary_tool sandbox repo) tools

let install_one opam_opts { name; compiler_constr = _; description } =
  (* TODO: check first if the tool is already installed before installing it *)
  let descr = Option.default "" description in
  Printf.printf "We're currently installing %s. %s\n" name descr;
  (* FIXME: implement a caching and sandboxing workflow. for the sandboxing,
     take [compiler_constr] into account *)
  Opam.Switch.install ~opts:opam_opts
    [ `Atom (OpamFormula.atom_of_string name) ]

let install opam_opts tools =
  let iterate res tools =
    List.fold_left
      (fun last_res tool ->
        match (last_res, install_one opam_opts tool) with
        | Ok (), Ok () -> Ok ()
        | Error l, Ok () -> Error l
        | Ok (), Error err -> Error [ err ]
        | Error l, Error err -> Error (err :: l))
      res tools
  in
  iterate (Ok ()) tools

(** TODO: This should be moved to an other module to for example do automatic
    recognizing of ocamlformat's version. *)
let platform =
  (* FIXME: should take an argument of type [OpamStateTypes.switch_state] from
     the opam library or something like that and use that argument for the
     [compiler_constr] field of the compiler dependent tools *)
  (* FIXME: should add a brief description for each tool *)
  let independent =
    List.map (fun tool -> { name = tool }) compiler_independent
  in
  List.fold_left
    (fun acc tool -> { name = tool } :: acc)
    independent compiler_dependent
