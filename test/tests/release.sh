#/usr/bin/env bash
set -xeuo pipefail

tar cf ocaml-platform-$VERSION-$TARGETOS-$TARGETARCH.tar -C _build/install/default/bin ocaml-platform opam --dereference
