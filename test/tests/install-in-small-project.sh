#/usr/bin/env bash
set -euo pipefail

cd helloworld

eval $(opam env)

ocaml-platform -vv
