#!/bin/bash
set -euo pipefail

printf "\n" | ocaml-platform setup-global --yes

eval $(opam env)
