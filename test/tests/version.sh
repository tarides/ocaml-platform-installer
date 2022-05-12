#/usr/bin/env bash
set -euo pipefail

eval $(opam env)

ocaml-platform --version
opam --version
dune --version
utop -version
dune-release --version
dune ocaml-merlin --version
odoc --version
ocamlformat --version
