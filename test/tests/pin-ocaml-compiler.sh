#/usr/bin/env bash
set -euo pipefail

cd $HOME
git clone --branch 4.14 --single-branch https://github.com/ocaml/ocaml
cd ocaml
opam switch create --empty pinned
opam install .
