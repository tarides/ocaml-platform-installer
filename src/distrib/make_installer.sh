#/usr/bin/env bash
set -xeuo pipefail

# static_targetos is used for static builds of ocaml-platform, targetos is used
# for Opam's builds.

cat <<EOF
#/usr/bin/env bash
set -xeuo pipefail

PREFIX=\${PREFIX:-/usr/local}

targetos=\$(uname -s | tr '[:upper:]' '[:lower:]' || true)
case \$targetos in
  "darwin") static_targetos=macos; targetos=macos ;;
  *) static_targetos=linux ;;
esac

targetarch=\$(uname -m || echo unknown)
# Taken from Opam's installer
case \$targetarch in
  x86|i?86) targetarch="i686" ;;
  x86_64|amd64) targetarch="x86_64" ;;
  ppc|powerpc|ppcle) targetarch="ppc" ;;
  arm64|aarch64_be|aarch64) targetarch="arm64" ;;
  *armv*) targetarch="armhf" ;;
esac

archive=ocaml-platform-$VERSION-\$static_targetos-\$targetarch.tar

case \$archive in
$(
  for a in "$@"; do
    read sha512 _ < <(sha512sum $a)
    echo "\"${a##*/}\") sha512=\"$sha512\" ;;"
  done
)
  *)
    echo "Cannot install ocaml-platform for \$static_targetos \$targetarch" >&2
    exit 1
    ;;
esac

# Taken from Opam's installer. Args: dest_path url
download()
{
    if command -v wget >/dev/null; then wget -O "\$@"
    else curl -L -o "\$@"
    fi
}

install_opam ()
{
  local opam_bin opam_base_url sha512
  opam_bin=opam-2.1.2-\$targetarch-\$targetos
  opam_base_url=https://github.com/ocaml/opam/releases/download/2.1.2
  case \$opam_bin in
    opam-2.1.2-arm64-linux)     sha512=439b4d67c2888058df81b265148a3468b753c14700a8be38d091b76bf2777b5da5e9c8752839a92878cd377dd4bfbd5c3a458e7a26bff73e35056b60591d30f0 ;;
    opam-2.1.2-arm64-macos)     sha512=55879f3e18bbc70c32d06f21f4ef785d54ef052920f57f1847c2cddc15af2f08e82d32022e7284fa43b07d56e4ba2f5155956b3673c3def8cd2f5c2cb8f68e48 ;;
    opam-2.1.2-armhf-linux)     sha512=b9ee73e04ebaab23348e990b6e1d678fa0a66f5c0124e397761c6b9b2f1a8cb6fb2fa97da119aed520097f47ac7f8a2095f310891c72b088be8088c9547362d7 ;;
    opam-2.1.2-i686-linux)      sha512=85a480d60e09a7d37fa0d0434ed97a3187434772ceb4e7e8faa5b06bc18423d004af3ad5849c7d35e72dca155103257fd6b1178872df8291583929eb8f884b6a ;;
    opam-2.1.2-x86_64-freebsd)  sha512=50abe8d91bc2fde43565f40d12ff18a1eceaad51483db3d7c6619bce70920d0a3845fad8993b8bfad24c9d550c4b6a5c12d55fb8a5f26c0da25f221b68307f4b ;;
    opam-2.1.2-x86_64-linux)    sha512=c0657ecbd4dc212587a4da70c5ff0402df95d148867be0e1eb1be8863a2851015f191437c3c99b7c2b153fcaa56cac99169c76ec94c5787750d7a59cd1fbb68b ;;
    opam-2.1.2-x86_64-macos)    sha512=5ec63f3e4e4e93decb7580d0a114d3ab5eab49baea29edd80c8b4c86b7ab5224e654035903538ef4b63090ab3c2967d6efcc46bf0e8abf239ecc3e04ad7304e2 ;;
    opam-2.1.2-x86_64-openbsd)  sha512=7c16d69c3bb655a149511218663aebdca54f9dd4346f8e4770f2699ae9560651ac242eb7f7aa94b21ad1b579bd857143b6f1ef98b0a53bd3c7047f13fcf95219 ;;
    *)
      echo "Cannot install opam for \$targetos \$targetarch. Please obtain it at https://opam.ocaml.org/" >&2
      exit 1
      ;;
  esac
  download opam "\$opam_base_url/\$opam_bin"
  sha512sum --check - <<<"\$sha512 opam"
  install -m755 "opam" "\$PREFIX/bin"
}

cd "\$(mktemp -d)"

download "\$archive" "$ARCHIVES_URL/\$archive"
sha512sum --check - <<<"\$sha512 \$archive"
tar xf "\$archive"
install -m755 bin/* "\$PREFIX/bin"

# Install Opam if necessary
if ! [[ -e \$PREFIX/bin/opam ]]; then
  install_opam
fi
EOF
