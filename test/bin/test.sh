#!/bin/bash
set -euo pipefail

docker build -t test test/bin
docker run --rm -it -v $(pwd)/_build/default/bin:/root/platform --privileged test
# docker run --rm -i -v $(pwd)/_build/default/bin:/root/platform --privileged test <<EOF
# ./root/platform/main.exe
# opam init -y
# EOF
