#/usr/bin/env bash
set -xeuo pipefail

# Test that the sandbox switch and the tools are not built again when they are
# installed a second time. 
# To do that, remove the "default" repository from the selection of new
# switches, this will prevent any switch from being created.

eval `opam env`

opam repository remove --set-default default

opam remove ocamlformat odoc

ocaml-platform -vv

ocamlformat --version
odoc --version
