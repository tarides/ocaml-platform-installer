open Astring

type full_name = { name : string; ver : string }

let v ~name ~ver = { name; ver }
let to_string { name; ver } = name ^ "." ^ ver
let name { name; ver = _ } = name
let ver { name = _; ver } = ver

module Opam_file = struct
  type t = string
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
  let ident s = with_pos (Ident s)
  let list l = with_pos @@ List (with_pos l)
  let option v l = with_pos @@ Option (v, with_pos l)
  let prefix_relop p v = with_pos @@ Prefix_relop (with_pos p, v)

  type atom = [ `Eq | `Geq | `Gt | `Leq | `Lt | `Neq ] * string * string
  type formula = Atom of atom | Formula of [ `And | `Or ] * formula * formula

  let atom (op, a, b) = with_pos @@ Relop (with_pos op, ident a, string b)

  let rec formula f =
    match f with
    | Atom a -> atom a
    | Formula (relop, g, h) ->
        with_pos @@ Logop (with_pos relop, formula g, formula h)

  let v ?install ?depends ?conflicts ?available ?url ~pkg_name () =
    let opam_version = "2.0" in
    let file_name = "opam" in
    let opam_version = variable "opam-version" (string opam_version) in
    let f_op_to_list e f = match e with None -> [] | Some l -> [ f l ] in
    let name = variable "name" (string pkg_name)
    and available =
      f_op_to_list available @@ fun available ->
      variable "available" (formula available)
    and install =
      f_op_to_list install @@ fun install ->
      variable "install"
        (list (List.map (fun e -> list (List.map string e)) install))
    and depends =
      f_op_to_list depends @@ fun depends ->
      let depend (p, c) =
        option (string p)
          (List.map (fun (rel, cstr) -> prefix_relop rel (string cstr)) c)
      in
      variable "depends" (list (List.map depend depends))
    and conflicts =
      f_op_to_list conflicts @@ fun conflicts ->
      variable "conflicts" (list (List.map string conflicts))
    and url =
      f_op_to_list url @@ fun url ->
      let items = [ variable "src" (string (Fpath.to_string url)) ] in
      section "url" None items
    in
    let file_contents =
      [ opam_version; name ] @ install @ depends @ available @ conflicts @ url
    in
    OpamPrinter.FullPos.opamfile
      { OpamParserTypes.FullPos.file_contents; file_name }

  let to_string t = t
  let of_string t = t
end

module Install_file = struct
  open Opam_file

  type t = OpamParserTypes.FullPos.opamfile

  let v classified_files ~pkg_name =
    let of_option o = match o with None -> [] | Some a -> [ string a ] in
    let file_contents =
      String.Map.fold
        (fun f v l ->
          variable f
            (list (List.map (fun (p, c) -> option (string p) (of_option c)) v))
          :: l)
        classified_files []
    and file_name = pkg_name ^ ".install" in
    { OpamParserTypes.FullPos.file_contents; file_name }

  let to_string t = OpamPrinter.FullPos.opamfile t
end
