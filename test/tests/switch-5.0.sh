#/usr/bin/env bash
set -euo pipefail

opam update

opam switch create 5.0.0~alpha1 --repositories=default,beta=git+https://github.com/ocaml/ocaml-beta-repository.git


