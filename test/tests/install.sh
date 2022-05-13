#/usr/bin/env bash
set -euo pipefail

printf "\n" | ocaml-platform -vv

eval $(opam env)
