#/usr/bin/env bash
set -euo pipefail

cd helloworld

eval $(opam env)

[[ $(ocamlformat --version) =~ "0.19.0" ]];

dune build @fmt
