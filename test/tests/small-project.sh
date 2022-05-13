#/usr/bin/env bash
set -euo pipefail

opam install dune -y

eval $(opam env)

dune init proj helloworld

cd helloworld

echo "version = 0.19.0" > .ocamlformat

opam switch create . 4.13.1
