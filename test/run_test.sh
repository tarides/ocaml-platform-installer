#/usr/bin/env bash
set -euo pipefail

PLAT="${OCAMLPLATFORM_PLATFORM:-linux/amd64}"
VERSION="${VERSION:-}"

echo "Building the binary for $PLAT"

docker buildx build --platform $PLAT -f test/dockerfiles/Dockerfile.build --load -t ocaml-platform-build-$PLAT .

for test_ in "$@"
do
    echo "Running test $test_"
    if test -f test/dockerfiles/Dockerfile.$test_; then
        docker buildx build --build-arg VERSION=$VERSION --platform $PLAT -f test/dockerfiles/Dockerfile.$test_ --load -t ocaml-platform-$test_-$PLAT .
    else
        echo "$test_ is not a valid test as Dockerfile.$test_ does not exists."
    fi
done
