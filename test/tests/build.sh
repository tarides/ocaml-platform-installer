#/usr/bin/env bash
set -xeuo pipefail

eval $(opam env)

opam exec -- dune build

tar cf ocaml-platform-$TARGETOS-$TARGETARCH.tar -C _build/install/default/bin ocaml-platform opam --dereference
