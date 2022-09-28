#/usr/bin/env bash
set -euo pipefail

eval $(opam env)

ocaml-platform -vv
