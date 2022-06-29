open! Import
open Astring

type full_name = { name : string; ver : string }

let v ~name ~ver = { name; ver }
let to_string { name; ver } = name ^ "." ^ ver
let name { name; ver = _ } = name
let ver { name = _; ver } = ver

module Opam_file = struct
  type t = OpamParserTypes.FullPos.opamfile
  type cmd = string list
  type dep = string * ([ `Eq | `Geq | `Gt | `Leq | `Lt | `Neq ] * string) list

  open OpamParserTypes.FullPos

  let with_pos pelem =
    let pos = { start = (0, 0); stop = (0, 0); filename = "" } in
    { pelem; pos }

  let variable name value = with_pos @@ Variable (with_pos name, value)

  let section kind name items =
    let section_kind = with_pos kind
    and section_name = Option.map with_pos name
    and section_items = with_pos items in
    with_pos @@ Section { section_kind; section_name; section_items }

  let string s = with_pos (String s)
  let list l = with_pos @@ List (with_pos l)
  let option v l = with_pos @@ OpamParserTypes.FullPos.Option (v, with_pos l)
  let prefix_relop p v = with_pos @@ Prefix_relop (with_pos p, v)

  let v ?install ?depends ?conflicts ?url ~pkg_name () =
    let opam_version = "2.0" in
    let file_name = "opam" in
    let opam_version = variable "opam-version" (string opam_version)
    and name = variable "name" (string pkg_name)
    and install =
      match install with
      | None -> []
      | Some install ->
          [
            variable "install"
              (list (List.map (fun e -> list (List.map string e)) install));
          ]
    and depends =
      match depends with
      | None -> []
      | Some depends ->
          [
            variable "depends"
              (list
                 (List.map
                    (fun (p, c) ->
                      option (string p)
                        (List.map
                           (fun (rel, cstr) -> prefix_relop rel (string cstr))
                           c))
                    depends));
          ]
    and conflicts =
      match conflicts with
      | None -> []
      | Some conflicts ->
          [ variable "conflicts" (list (List.map string conflicts)) ]
    and url =
      match url with
      | None -> []
      | Some url ->
          let items = [ variable "src" (string (Fpath.to_string url)) ] in
          [ section "url" None items ]
    in
    let file_contents =
      [ opam_version; name ] @ install @ depends @ conflicts @ url
    in
    { OpamParserTypes.FullPos.file_contents; file_name }

  let to_string t = OpamPrinter.FullPos.opamfile t
end

module Install_file = struct
  open Opam_file

  type t = OpamParserTypes.FullPos.opamfile

  let v ?lib ?lib_root ?libexec ?libexec_root ?bin ?sbin ?toplevel ?share
      ?share_root ?etc ?doc ?stublibs ?man ?misc ~pkg_name () =
    let of_option o = match o with None -> [] | Some a -> [ string a ] in
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

    let file_name = pkg_name ^ ".install"
    and file_contents =
      List.map
        (fun (f, v) ->
          variable f
            (list
               (List.map
                  (fun (p, c) -> option (string p) (of_option c))
                  (Option.value ~default:[] v))))
        l
    in
    { OpamParserTypes.FullPos.file_contents; file_name }

  let to_string t = OpamPrinter.FullPos.opamfile t
end
