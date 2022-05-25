#/usr/bin/env bash
set -euo pipefail

opam install dune -y

eval $(opam env)

dune init proj helloworld

cd helloworld

echo "version = 0.19.0" > .ocamlformat

sed -i 's/depends ocaml dune/depends ocaml dune dune-release/g' dune-project

opam switch create . 4.13.1
