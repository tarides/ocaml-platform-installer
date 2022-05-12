open Bos
open Rresult

module Opam_file = struct
  type t = opam_version:string -> pkg_name:string -> unit Fmt.t
  type cmd = string list
  type dep = string * (string * string) option

  let fpf = Format.fprintf
  let field ppf name pp_a a = fpf ppf "%s @[<v>%a@]@\n" name pp_a a

  let field_opt ppf name pp_a = function
    | Some a -> field ppf name pp_a a
    | None -> ()

  let gen_list pp_a ppf lst =
    let pp_a ppf a = fpf ppf "@[<hov>%a@]" pp_a a in
    fpf ppf "[@ %a@ ]" (Format.pp_print_list pp_a) lst

  let gen_string ppf s = fpf ppf "%S" s

  let gen_dep_filter ppf = function
    | Some (op, cons) -> fpf ppf "{%s %S}" op cons
    | None -> ()

  let gen_dep ppf (name, filter) = fpf ppf "%S%a" name gen_dep_filter filter
  let gen_url ppf url = fpf ppf "{@ src: %S@ }" (Fpath.to_string url)

  let v ?install ?depends ?conflicts ?url ~opam_version ~pkg_name ppf () =
    field ppf "opam-version:" gen_string opam_version;
    field ppf "name:" gen_string pkg_name;
    field_opt ppf "install:" (gen_list (gen_list gen_string)) install;
    field_opt ppf "depends:" (gen_list gen_dep) depends;
    field_opt ppf "conflicts:" (gen_list gen_string) conflicts;
    field_opt ppf "url" gen_url url
end

type t = Fpath.t

let opam_version = "2.0"

let init_repo path =
  OS.Dir.create path >>= fun _ ->
  OS.Dir.create (Fpath.add_seg path "packages") >>= fun _ ->
  OS.File.writef
    (Fpath.add_seg path "repo")
    {|
    opam-version: "%s"
  |}
    opam_version

let repo_name = "platform-cache"
let repo_path = Fpath.v "./cache_repo"

let init () =
  OS.Dir.exists repo_path >>= fun initialized ->
  if initialized then Ok repo_path
  else
    init_repo repo_path >>= fun _ ->
    Exec.run_opam
      Cmd.(
        v "repository" % "add" % "--dont-select" % "-k" % "local" % "-y"
        % repo_name % p repo_path)
    >>= fun () -> Ok repo_path

let repo_path_of_pkg t ~pkg ~ver =
  Fpath.(t / "packages" / pkg / (pkg ^ "." ^ ver))

let has_pkg t ~pkg ~ver =
  match OS.Dir.exists (repo_path_of_pkg t ~pkg ~ver) with
  | Ok r -> r
  | Error _ -> false

let add_package t ~pkg ~ver opam =
  let repo_path = repo_path_of_pkg t ~pkg ~ver in
  OS.Dir.create repo_path >>= fun _ ->
  OS.File.writef
    Fpath.(repo_path / "opam")
    "%a"
    (opam ~opam_version ~pkg_name:pkg)
    ()
  >>= fun () -> Exec.run_opam Cmd.(v "update" % "--no-auto-upgrade" % repo_name)

let with_repo_enabled _ f =
  let unselect_repo () =
    ignore (Exec.run_opam Cmd.(v "repository" % "remove" % repo_name))
  in
  Exec.run_opam Cmd.(v "repository" % "add" % repo_name % p repo_path)
  >>= fun () -> Fun.protect ~finally:unselect_repo f
