#/usr/bin/env bash
set -xeuo pipefail

# Test that the tools are not rebuilt in the sandbox switch if they have been
# cached. To do that, remove the sandbox switch, uninstall some packages and
# ask the platform to reinstall them.
# If the sandbox switch wasn't recreated, success.

eval `opam env`

DEFAULT_SANDBOX_SWITCH=$HOME/.opam/opam-tools-4.14.0
[[ -e $DEFAULT_SANDBOX_SWITCH ]]
rm -rf $DEFAULT_SANDBOX_SWITCH

opam remove ocamlformat+cached odoc+cached

printf "\n" | ocaml-platform -vv

! [[ -e $DEFAULT_SANDBOX_SWITCH ]]
 
ocamlformat --version
odoc --version
