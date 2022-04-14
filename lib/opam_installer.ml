let install_opam () =
  let install_sh =
    "bash -c \"sh <(curl -fsSL \
     https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)\""
  in
  Sys.command install_sh
