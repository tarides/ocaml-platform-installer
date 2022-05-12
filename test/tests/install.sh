#/usr/bin/env bash
set -euo pipefail

printf "\n" | ocaml-platform

eval $(opam env)
