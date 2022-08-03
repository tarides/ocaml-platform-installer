#/usr/bin/env bash
set -euo pipefail

eval $(opam env)

ocaml-platform -vv

[[ $(which ocamlformat) = "/home/user/.opam/5.0.0~alpha1/bin/ocamlformat" ]];
[[ $(which dune) = "/home/user/.opam/5.0.0~alpha1/bin/dune" ]];
[[ $(which ocamlmerlin) = "/home/user/.opam/5.0.0~alpha1/bin/ocamlmerlin" ]];
[[ $(which dune-release) = "/home/user/.opam/5.0.0~alpha1/bin/dune-release" ]];
[[ $(which odoc) = "/home/user/.opam/5.0.0~alpha1/bin/odoc" ]];
[[ $(which ocamllsp) = "/home/user/.opam/5.0.0~alpha1/bin/ocamllsp" ]];
