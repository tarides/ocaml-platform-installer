#/usr/bin/env bash
set -xeuo pipefail

tar cf ocaml-platform-$TARGETOS-$TARGETARCH.tar -C _build/install/default/bin ocaml-platform opam --dereference
