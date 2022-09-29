#/usr/bin/env bash
set -euo pipefail

[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/odoc+bin+platform) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/dune) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/merlin+bin+platform) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/ocaml-lsp-server+bin+platform) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/ocamlformat+bin+platform) = "" ]]
[[ $(find $HOME/.opam/plugins/ocaml-platform/cache/archives/dune-release+bin+platform) = "" ]]
