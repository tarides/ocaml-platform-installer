#/usr/bin/env bash
set -euo pipefail

cd $HOME
git clone https://github.com/ocaml/ocaml
cd ocaml
opam switch create --empty pinned
opam install .
