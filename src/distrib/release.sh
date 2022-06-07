#/usr/bin/env bash
set -xeuo pipefail

archive_name=$OUTPUT/ocaml-platform-$VERSION-$TARGETOS-$TARGETARCH.tar

dune subst

dune build -p platform
# Executables are symlinks, follow with -h.
tar hcf "$archive_name" -C _build/install/default bin/ocaml-platform
