#/usr/bin/env bash
set -xeuo pipefail

# static_targetos is used for static builds of ocaml-platform, targetos is used
# for Opam's builds.

latest_opam_version () {
    echo $(curl -s https://api.github.com/repos/ocaml/opam/releases/latest | jq -r .tag_name)
}

OPAM_VERSION=$(latest_opam_version)

get_opam_base_url ()
{
    local version
    version=$1
    echo "https://github.com/ocaml/opam/releases/download/$version"
}

# Args: opam_version arch os
opam_sha512sum ()
{
    local arch os version opam_base_url opam_file download_dir
    version=$1
    arch=$2
    os=$3
    opam_base_url=$(get_opam_base_url $version)
    opam_file=opam-$version-$arch-$os
    download_dir="/tmp/ocaml-platform-scratch"
    curl -fsSL https://opam-3.ocaml.org/opam-dev-pubkey.pgp | gpg --batch --import &> /dev/null
    mkdir -p $download_dir
    cd $download_dir
    wget -c $opam_base_url/$opam_file &> /dev/null
    wget -c $opam_base_url/$opam_file.sig &> /dev/null
    if $(gpg --verify $opam_file.sig $opam_file);
    then
        echo $(sha512sum $opam_file | cut -d " " -f 1)
    else
        echo "download-failed"
    fi
}

cat <<EOF
#/usr/bin/env bash
set -euo pipefail

# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   https://archive.ph/xvQVA
_() {

DEFAULT_PREFIX=/usr
if [[ -d /usr/local ]]; then DEFAULT_PREFIX=/usr/local; fi

PREFIX=\${PREFIX:-\$DEFAULT_PREFIX}

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
  else shasum -a 512 --check --quiet - <<<"\$1  \$2"
  fi
}

install_opam ()
{
  local opam_bin opam_base_url sha512
  opam_bin=opam-$OPAM_VERSION-\$targetarch-\$targetos
  opam_base_url=$(get_opam_base_url $OPAM_VERSION)
  case \$opam_bin in
    opam-$OPAM_VERSION-arm64-linux)     sha512=$(opam_sha512sum $OPAM_VERSION arm64 linux) ;;
    opam-$OPAM_VERSION-arm64-macos)     sha512=$(opam_sha512sum $OPAM_VERSION arm64 macos) ;;
    opam-$OPAM_VERSION-armhf-linux)     sha512=$(opam_sha512sum $OPAM_VERSION armhf linux) ;;
    opam-$OPAM_VERSION-i686-linux)      sha512=$(opam_sha512sum $OPAM_VERSION i686 linux) ;;
    opam-$OPAM_VERSION-x86_64-freebsd)  sha512=$(opam_sha512sum $OPAM_VERSION x86_64 freebsd) ;;
    opam-$OPAM_VERSION-x86_64-linux)    sha512=$(opam_sha512sum $OPAM_VERSION x86_64 linux) ;;
    opam-$OPAM_VERSION-x86_64-macos)    sha512=$(opam_sha512sum $OPAM_VERSION x86_64 macos) ;;
    opam-$OPAM_VERSION-x86_64-openbsd)  sha512=$(opam_sha512sum $OPAM_VERSION x86_64 openbsd) ;;
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
  sudo install -m755 "opam" "\$PREFIX/bin"
}

cd "\$(mktemp -d)"

echo "=> Download \$archive" >&2
download "\$archive" "$ARCHIVES_URL/\$archive"
check_sha512 "\$sha512" "\$archive"
tar xf "\$archive"

echo "=> Install into \$PREFIX/bin"
sudo install -m755 bin/* "\$PREFIX/bin"

# Install Opam if necessary
if ! command -v opam &> /dev/null;  then
  echo "Opam is not installed, installing."
  install_opam
fi

echo "Installation is done. Please run 'ocaml-platform' to install the Platform tools inside your set switch."
}

# Now that we know the whole script has downloaded, run it.
_ "\$0" "\$@"
EOF
