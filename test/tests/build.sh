#/usr/bin/env bash
set -xeuo pipefail

eval $(opam env)

opam exec -- dune build
