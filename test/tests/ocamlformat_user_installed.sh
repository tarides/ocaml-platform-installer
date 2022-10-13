#/usr/bin/env bash
set -xeuo pipefail

# OCamlformat is already installed but not to the right version.
# The difference with the "reinstall_ocamlformat" is that ocamlformat is
# initially installed from its upstream package.

eval `opam env`

! [[ $(ocamlformat --version) = 0.24.1 ]]
echo "version = 0.24.1" > .ocamlformat
ocaml-platform -vv
[[ $(ocamlformat --version) = 0.24.1 ]]
