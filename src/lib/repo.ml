open Bos
open Import

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

type t = { name : string; path : Fpath.t }

let opam_version = "2.0"

let init_repo path =
  let open Result.Syntax in
  let* _ = OS.Dir.create path in
  OS.Dir.create (Fpath.add_seg path "packages") >>= fun _ ->
  OS.File.writef
    (Fpath.add_seg path "repo")
    {|
    opam-version: "%s"
  |}
    opam_version

let init ~name path =
  let open Result.Syntax in
  let* initialized = OS.Dir.exists path in
  let repo = { name; path } in
  if initialized then Ok repo
  else
    let* _ = init_repo path in
    let* () = Opam.Repository.add ~url:(Fpath.to_string path) name in
    Ok repo

let repo_path_of_pkg t ~pkg ~ver =
  Fpath.(t.path / "packages" / pkg / (pkg ^ "." ^ ver))

let has_pkg t ~pkg ~ver =
  match OS.Dir.exists (repo_path_of_pkg t ~pkg ~ver) with
  | Ok r -> r
  | Error _ -> false

let add_package t ~pkg ~ver opam =
  let open Result.Syntax in
  let repo_path = repo_path_of_pkg t ~pkg ~ver in
  let* _ = OS.Dir.create repo_path in
  let* () =
    OS.File.writef
      Fpath.(repo_path / "opam")
      "%a"
      (opam ~opam_version ~pkg_name:pkg)
      ()
  in
  Opam.update [ t.name ]

let with_repo_enabled t f =
  let open Result.Syntax in
  let unselect_repo () = ignore @@ Opam.Repository.remove t.name in
  let* () = Opam.Repository.add ~url:(Fpath.to_string t.path) t.name in
  Fun.protect ~finally:unselect_repo f
