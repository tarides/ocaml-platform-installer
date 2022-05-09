#/usr/bin/env bash
set -euo pipefail

printf "\n" | ocaml-platform --yes

eval $(opam env)
