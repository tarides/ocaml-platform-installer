#/usr/bin/env bash
set -euo pipefail

eval $(opam env)

ocaml-platform --version
opam --version
dune --version
dune-release --version
dune ocaml-merlin --version
odoc --version
ocamlformat --version
opam-publish --version
utop -version
