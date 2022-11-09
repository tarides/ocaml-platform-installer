#/usr/bin/env bash
set -euo pipefail

# The setting of this test should be the end of the "install" test. That is, the
# current switch should be of version 4.08 with the installer having run.

# The installed version of these tools should be tied to 4.08.1, as they are
# dependent on the version of OCaml they were compiled with.
[[ $(opam show dune -f depends: ) =~ "4.08.1" ]]
[[ $(opam show merlin -f depends: ) =~ "4.08.1" ]]
[[ $(opam show ocaml-lsp-server -f depends: ) =~ "4.08.1" ]]
[[ $(opam show odoc -f depends: ) =~ "4.08.1" ]]

# The installed version of these tools should not be tied to 4.08.1, as they are
# independent from the version of OCaml they were compiled with.
[[ $(opam show dune-release -f depends: ) != *"4.08.1"* ]]
[[ $(opam show ocamlformat -f depends: ) != *"4.08.1"* ]]

# Now, we check that the installation still works well on 4.13

opam switch create 4.13.1

eval $(opam env)

ocaml-platform

opam --version
dune --version
dune-release --version
dune ocaml-merlin --version
odoc --version
ocamlformat --version
