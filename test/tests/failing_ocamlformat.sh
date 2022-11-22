#/usr/bin/env bash
set -euo pipefail

# We modify the ocamlformat.0.24.1 package so that it won’t build (by setting wrong SHAs)
sed -i 's/sha256=[a-zA-Z0-9]*/sha256=3b6a07254c78e5dfdd564178a4a99336bd5b6e79b6531efd7e537b73d4613fd2/g' ~/opam-repository/packages/ocamlformat/ocamlformat.0.24.1/opam
sed -i 's/sha512=[a-zA-Z0-9]*/sha512=c38a5bc6ab23186fc2ab0ba08719e84b038c529c4d7d1f575227d8a02b0e23aa016e61276445be5e7ee725c4f471b409c4ec724bdd0ba7b1f94ae41a9c1396e5/g' ~/opam-repository/packages/ocamlformat/ocamlformat.0.24.1/opam 
opam update

# We removed installed versions
opam remove ocamlformat odoc

# And force next installation to be 0.24.1
sed -i 's/0.19.0/0.24.1/g' .ocamlformat

# Run the installed
! ocaml-platform -vv

# Check that ocaml-platform has updated the state as intended:
# - ocamlformat binary package build has failed
# - odoc has been reinstalled

! opam show ocamlformat
opam show odoc
