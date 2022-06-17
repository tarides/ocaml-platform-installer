open! Import
open Astring

type full_name = { name : string; ver : string }

let v ~name ~ver = { name; ver }
let to_string { name; ver } = name ^ "." ^ ver
let name { name; ver = _ } = name
let ver { name = _; ver } = ver

module FilesGenerator = struct
  let fpf = Format.fprintf
  let field ppf name pp_a a = fpf ppf "%s @[<v>%a@]@\n" name pp_a a

  let field_opt ppf name pp_a = function
    | Some a -> field ppf name pp_a a
    | None -> ()

  let gen_list pp_a ppf lst =
    let pp_a ppf a = fpf ppf "@[<hov>%a@]" pp_a a in
    fpf ppf "[@ %a@ ]" (Format.pp_print_list pp_a) lst

  let gen_string ppf s = fpf ppf "%S" s

  let gen_option pp_a ppf = function
    | Some op -> fpf ppf " { %a }" pp_a op
    | None -> ()

  let gen_field_with_opt f_pp_a opt_pp_a ppf (s, opt) =
    fpf ppf "%a%a" f_pp_a s (gen_option opt_pp_a) opt
end

module Opam_file = struct
  open FilesGenerator

  type t = unit Fmt.t
  type cmd = string list
  type dep = string * (string * string) option

  let gen_dep =
    let gen_constraint ppf (op, cons) = fpf ppf "%s %S" op cons in
    gen_list (gen_field_with_opt gen_string gen_constraint)

  let gen_url ppf url = fpf ppf "{@ src: %S@ }" (Fpath.to_string url)

  let v ?install ?depends ?conflicts ?url ~opam_version ~pkg_name ppf () =
    field ppf "opam-version:" gen_string opam_version;
    field ppf "name:" gen_string pkg_name;
    field_opt ppf "install:" (gen_list (gen_list gen_string)) install;
    field_opt ppf "depends:" gen_dep depends;
    field_opt ppf "conflicts:" (gen_list gen_string) conflicts;
    field_opt ppf "url" gen_url url

  let fprintf t = t
end

module Install_file = struct
  open FilesGenerator

  type t = unit Fmt.t

  let v ?lib ?lib_root ?libexec ?libexec_root ?bin ?sbin ?toplevel ?share
      ?share_root ?etc ?doc ?stublibs ?man ?misc () =
    let l =
      [
        ("lib:", lib);
        ("lib_root:", lib_root);
        ("libexec:", libexec);
        ("libexec_root:", libexec_root);
        ("bin:", bin);
        ("sbin:", sbin);
        ("toplevel:", toplevel);
        ("share:", share);
        ("share_root:", share_root);
        ("etc:", etc);
        ("doc:", doc);
        ("stublibs:", stublibs);
        ("man:", man);
        ("misc:", misc);
      ]
    in
    fun ppf () ->
      List.iter
        (fun (f, p) ->
          field_opt ppf f
            (gen_list (gen_field_with_opt gen_string gen_string))
            p)
        l

  (* field_opt ppf "lib:" (gen_list gen_string) lib; *)
  (* field_opt ppf "lib_root:" (gen_list gen_string) lib_root; *)
  (* field_opt ppf "libexec:" (gen_list gen_string) libexec; *)
  (* field_opt ppf "libexec_root:" (gen_list gen_string) libexec_root; *)
  (* field_opt ppf "bin:" (gen_list gen_string) bin; *)
  (* field_opt ppf "sbin:" (gen_list gen_string) sbin; *)
  (* field_opt ppf "toplevel:" (gen_list gen_string) toplevel; *)
  (* field_opt ppf "share:" (gen_list gen_string) share; *)
  (* field_opt ppf "share_root:" (gen_list gen_string) share_root; *)
  (* field_opt ppf "etc:" (gen_list gen_string) etc; *)
  (* field_opt ppf "doc:" (gen_list gen_string) doc; *)
  (* field_opt ppf "stublibs:" (gen_list gen_string) stublibs; *)
  (* field_opt ppf "man:" (gen_list gen_string) man; *)
  (* field_opt ppf "misc:" (gen_list gen_string) misc *)

  let fprintf t = t
end
