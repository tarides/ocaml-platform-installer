open! Import
open Astring

type full_name = { name : string; ver : string }

let v ~name ~ver = { name; ver }
let to_string { name; ver } = name ^ "." ^ ver
let name { name; ver = _ } = name
let ver { name = _; ver } = ver

module Opam_file = struct
  type t = unit Fmt.t
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

  let fprintf t = t
end
