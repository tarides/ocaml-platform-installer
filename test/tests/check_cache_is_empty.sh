#/usr/bin/env bash
set -euo pipefail

[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/odoc) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/dune) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/merlin) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/ocaml-lsp-server) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/ocamlformat) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/dune-release) = "" ]]
