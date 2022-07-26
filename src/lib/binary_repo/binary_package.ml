open Astring
open Bos
open Rresult

module Binary_install_file = struct
  let classify_file pkg_name cf f =
    let open Fpath in
    let f = match rem_prefix (v "_opam") f with None -> f | Some f -> f in
    let l =
      (* prefix, category *)
      [
        (v "bin", "bin");
        (v "sbin", "sbin");
        (v "share" / pkg_name, "share");
        (v "share_root", "share_root");
        (v "doc" / pkg_name, "doc");
        (v "etc" / pkg_name, "etc");
        (v "man" / pkg_name, "man");
      ]
    in
    Option.value ~default:cf
    @@ List.find_map
         (fun (value, category) ->
           Option.map
             (fun p ->
               match String.Map.find category cf with
               | None -> String.Map.add category [ (f, p) ] cf
               | Some l -> String.Map.add category ((f, p) :: l) cf)
             (rem_prefix value f))
         l

  let from_file_list pkg_name fl =
    let empty = String.Map.empty in
    let classified_files = List.fold_left (classify_file pkg_name) empty fl in
    let process =
      List.map (fun (n, f) -> (Fpath.to_string n, Some (Fpath.to_string f)))
    in
    let classified_files = String.Map.map process classified_files in
    Package.Install_file.v ~pkg_name classified_files
end

type full_name = Package.full_name

(** Name and version of the binary package corresponding to a given package. *)
let binary_name ~ocaml_version ~name ~ver ~pure_binary =
  let name = if pure_binary then name else name ^ "+bin+platform" in
  let ver = ver ^ "-ocaml" ^ Ocaml_version.to_string ocaml_version in
  Package.v ~name ~ver

let name = Package.name
let ver = Package.ver
let package t = t
let to_string = Package.to_string

let generate_opam_file ~arch ~os_distribution original_name bname pure_binary
    archive_path ocaml_version =
  let conflicts = if pure_binary then None else Some [ original_name ] in
  let available =
    let open Package.Opam_file in
    Package.Opam_file.Formula
      ( `And,
        Atom (`Eq, "arch", arch),
        Atom (`Eq, "os-distribution", os_distribution) )
  in
  let depends =
    [ ("ocaml", [ (`Eq, Ocaml_version.to_string ocaml_version) ]) ]
  in
  Package.Opam_file.v ~depends ~available ?conflicts ~url:archive_path
    ~pkg_name:(name bname) ()

(** Ignore files that do not exist. *)
let filter_exists files =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | hd :: tl ->
        Bos.OS.File.exists hd >>= fun ex ->
        let acc = if ex then hd :: acc else acc in
        loop acc tl
  in
  loop [] files

(** Remove paths starting with [lib/]. *)
let remove_lib ~prefix paths = List.filter Fpath.(is_prefix (prefix / "lib")) paths

type binary_pkg = Package.Install_file.t * Package.Opam_file.t

(** Binary is already in the sandbox. Add this binary as a package in the local
    repo *)
let make_binary_package ~ocaml_version ~arch ~os_distribution ~prefix ~files
    ~archive_path bname ~name:query_name ~pure_binary =
  filter_exists files >>= fun files ->
  let paths = remove_lib ~prefix files in
  let tar_input = List.map Fpath.to_string paths |> String.concat ~sep:"\n" in
  OS.Cmd.(
    in_string tar_input
    |> run_in
         Cmd.(
           v "tar" % "czf" % p archive_path % "-C"
           % p (Fpath.parent prefix)
           % "-T" % "-"))
  >>= fun () ->
  OS.File.exists archive_path >>= fun archive_created ->
  let install = Binary_install_file.from_file_list query_name paths in
  let opam_file =
    generate_opam_file ~arch ~os_distribution query_name bname pure_binary
      archive_path ocaml_version
  in
  if not archive_created then
    Error (`Msg "Couldn't generate the package archive for unknown reason.")
  else Ok (install, opam_file)
