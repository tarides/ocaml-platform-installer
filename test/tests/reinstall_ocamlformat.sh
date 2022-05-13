#/usr/bin/env bash
set -xeuo pipefail

# Specify a version in .ocamlformat and expect it to be reinstalled to the
# requested version.
# Of course, first check that the current version isn't the one we expect,
# otherwise no re-installation would take place.

eval `opam env`

! [[ $(ocamlformat --version) = 0.19.0 ]]
echo "version = 0.19.0" > .ocamlformat
printf "\n" | ocaml-platform -vv
[[ $(ocamlformat --version) = 0.19.0 ]]
