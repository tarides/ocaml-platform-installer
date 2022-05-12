open Ppxlib

let expand ~ctxt filepath =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let cwd =
    Expansion_context.Extension.code_path ctxt
    |> Code_path.file_path |> Filename.dirname
  in
  let filepath =
    if Filename.is_relative filepath then Filename.concat cwd filepath
    else filepath
  in
  try
    let ic = open_in filepath in
    let file_content = really_input_string ic (in_channel_length ic) in
    Ast_builder.Default.estring ~loc file_content
  with Sys_error _ as err ->
    Ast_builder.Default.pexp_extension ~loc
      (Location.error_extensionf ~loc "[embed] %s" (Printexc.to_string err))

let my_extension =
  Extension.V3.declare "embed" Extension.Context.expression
    Ast_pattern.(single_expr_payload (estring __))
    expand

let rule = Ppxlib.Context_free.Rule.extension my_extension
let () = Driver.register_transformation ~rules:[ rule ] "embed"
