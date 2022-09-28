#/usr/bin/env bash
set -euo pipefail

# Starts from a simple project with:
# - platform tools already installed,
# - but the dependencies not installed.

# Dune and dune-release are dependencies of the simple project.

# This test tests the behaviour of:
# - installing dependencies on top of the tools:
#     dependencies should replace the tools if there is a clash
# - installing the tools on top of dependencies
#     tools should not replace a package if it is installed

eval $(opam env)

# Checking that we start with the good environment
opam show dune-release+bin+platform
! opam show dune-release
[[ $(ocamlformat --version) = 0.19.0 ]]

# Installing dependencies
dune build
opam install . --deps-only

# Checking that the environment has been updated correctly
[[ $(ocamlformat --version) = 0.19.0 ]]
! opam show dune-release+bin+platform
opam show dune-release

# To check that ocamlformat is replaced
sed -i 's/0.19.0/0.20.0/g' .ocamlformat

# Run ocaml-platform again
ocaml-platform -vv

# Check that ocaml-platform has updated the state as intended:
# - ocamlformat binary package has been updated
# - the binary package of dune-release has not replaced the dune-release package
opam show ocamlformat+bin+platform
! opam show ocamlformat
[[ $(ocamlformat --version) = 0.20.0 ]]
! opam show dune-release+bin+platform
opam show dune-release
