#/usr/bin/env bash
set -xeuo pipefail

cat <<EOF
#/usr/bin/env bash
set -xeuo pipefail

PREFIX=\${PREFIX:-/usr/local}

case \$(uname -s || true) in
  "darwin") targetos=macos ;;
  *) targetos=linux ;;
esac

targetarch=\$(uname -m)
archive=ocaml-platform-$VERSION-\$targetos-\$targetarch.tar

case \$archive in
$(
  for a in "$@"; do
    read sha1 _ < <(sha1sum $a)
    echo "\"${a##*/}\") sha1=\"$sha1\" ;;"
  done
)
  *)
    echo "Cannot install ocaml-platform for \$targetos \$targetarch" >&2
    exit 1
    ;;
esac

cd "\$(mktemp -d)"

curl -LO "$ARCHIVES_URL/\$archive"
sha1sum --check - <<<"\$sha1 \$archive"
tar xf "\$archive"

install -m755 bin/* "\$PREFIX/bin"
EOF
