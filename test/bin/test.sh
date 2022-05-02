#!/bin/bash
set -euo pipefail

docker build -t test .
docker run -i --privileged test <<EOF
printf "\n" | ocaml-platform setup-global --yes
eval \$(opam env)
opam --version
dune --version
utop -version
dune-release --version
dune ocaml-merlin --version
odoc --version
ocamlformat --version
EOF
# ocaml-lsp-server is missing. how can we check if it's installed?
