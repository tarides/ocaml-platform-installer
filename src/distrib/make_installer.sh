#/usr/bin/env bash
set -xeuo pipefail

# static_targetos is used for static builds of ocaml-platform, targetos is used
# for Opam's builds.

cat <<EOF
#/usr/bin/env bash
set -euo pipefail

# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   https://archive.ph/xvQVA
_() {

PREFIX=\${PREFIX:-/usr/local}

targetarch=\$(uname -m || echo unknown)
# Taken from Opam's installer
case \$targetarch in
  x86|i?86) targetarch="i686" ;;
  x86_64|amd64) targetarch="x86_64" ;;
  ppc|powerpc|ppcle) targetarch="ppc" ;;
  arm64|aarch64_be|aarch64) targetarch="arm64" ;;
  *armv*) targetarch="armhf" ;;
esac

targetos=\$(uname -s | tr '[:upper:]' '[:lower:]' || true)
case \$targetos in
  "darwin")
    static_targetos=macos
    targetos=macos
    # Distribute the x86_64 static binary to arm64 users too.
    static_targetarch=x86_64
    ;;
  *) static_targetos=linux; static_targetarch=\$targetarch ;;
esac

archive=ocaml-platform-$VERSION-\$static_targetos-\$static_targetarch.tar

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

# Args: sha512 path
check_sha512()
{
  if command -v sha512sum >/dev/null
  then sha512sum --check --quiet - <<<"\$1 \$2"
  else shasum -a 512 --check --quiet - <<<"\$1 \$2"
  fi
}

install_opam ()
{
  local opam_bin opam_base_url sha512
  opam_bin=opam-2.1.3-\$targetarch-\$targetos
  opam_base_url=https://github.com/ocaml/opam/releases/download/2.1.3
  case \$opam_bin in
    opam-2.1.3-arm64-linux)     sha512=6c495ed1ebb63eeb3b4a07068df97673dd9520c4474e480102412c23eb35e796a237680df3e0905faade190ead69c67be8f3a92e78944c2896e3546dfa68361d ;;
    opam-2.1.3-arm64-macos)     sha512=abd834a078c6c783fa021f63ff17e5d4e3c8af833bcc276995f73c2d9af446b68ed8132bc344c791ce78afae980b6a6ca6ad0cea599076216deb5fe34e032250 ;;
    opam-2.1.3-armhf-linux)     sha512=303e7e71daa3e678f6aed025a1ff5b4fbc1d3146dcda0d0ae91884d3ccce4b205d1a4d283005b63a3990ea4452df291f2e84d144ca13bc40373bcb46ee702690 ;;
    opam-2.1.3-i686-linux)      sha512=b6834a54294c864069e70d0a46346fd4166c6847985f751c02a8c00184fc346095cbced3ded0aa34d710e1a68d687f5ca3ad8df4a2eea3c681727f5d1c0b099c ;;
    opam-2.1.3-x86_64-freebsd)  sha512=0cf37cb5f7ca95706bacaf8340abd00901b3a7c7bfba4af1ba77f5740614e1e5227f9632be0427f1efdf8ed324c21efe412bf7f3a725afa84ac7f7339c4b5cbd ;;
    opam-2.1.3-x86_64-linux)    sha512=b02e49f062291d6adf97a4e0ab3774f5ecb886d5ff73e693773493249f26aaa11b1cb1987ecf5074ce431fc34bacdc359a560d75ecc9bb4853f564489194b43b ;;
    opam-2.1.3-x86_64-macos)    sha512=0d820ba42f34e6e3cfc6ac145794fb02b919f7c7086d9c6fb92489ddf11ab42d718753c9f84275f553832536216b66ee1bb57e93d08fc658cf0a82678df5be42 ;;
    opam-2.1.3-x86_64-openbsd)  sha512=dc4479ca27baaa1b596451768cfeaeca35a87321a9938d3ecb3e3247adbc814da400667a864ba4d8cbffa665b72dc9e55aa7d3410a5caa8b82b4dc04991e5f77 ;;
    *)
      echo "Cannot install opam for \$targetos \$targetarch." >&2
      echo "Opam is required to setup the platform. Please install it via your package manager or obtain it at https://opam.ocaml.org/" >&2
      echo "Once Opam is installed, run 'ocaml-platform'." >&2
      exit 1
      ;;
  esac

  echo "=> Download \$opam_bin"
  download opam "\$opam_base_url/\$opam_bin"
  check_sha512 "\$sha512" opam

  echo "=> Install into \$PREFIX/bin"
  install -m755 "opam" "\$PREFIX/bin"
}

cd "\$(mktemp -d)"

echo "=> Download \$archive" >&2
download "\$archive" "$ARCHIVES_URL/\$archive"
check_sha512 "\$sha512" "\$archive"
tar xf "\$archive"

echo "=> Install into \$PREFIX/bin"
install -m755 bin/* "\$PREFIX/bin"

# Install Opam if necessary
if ! [[ -e \$PREFIX/bin/opam ]]; then
  echo "Opam is not installed, installing."
  install_opam
fi

echo "Installation is done. Please run 'ocaml-platform' to install the Platform tools inside your set switch."
}

# Now that we know the whole script has downloaded, run it.
_ "\$0" "\$@"
EOF
