#/usr/bin/env bash
set -euo pipefail

cd helloworld

eval $(opam env)

dune build @doc

ls -l _build/default/_doc/_html/index.html
