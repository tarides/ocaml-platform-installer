#/usr/bin/env bash
set -euo pipefail

eval $(opam env)

[[ $(ocamlformat --version) =~ "0.19.0" ]];

dune build @fmt
