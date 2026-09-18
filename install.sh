#!/bin/sh
# Installs a Metatavu command-line tool.
#
#   curl -sfL https://raw.githubusercontent.com/Metatavu/homebrew-tap/main/install.sh | sh -s -- severa
#
# Re-run it to upgrade. On macOS prefer `brew install metatavu/tap/<tool>`, which
# tracks upgrades with everything else.
set -eu

REPO="Metatavu/homebrew-tap"
TOOL="severa"
VERSION="latest"
PREFIX="${PREFIX:-$HOME/.local/bin}"

usage() {
    cat >&2 <<EOF
Usage: install.sh [TOOL] [--version VERSION] [--prefix DIR]

  TOOL       Tool to install (default: severa)
  --version  Release to install, e.g. 0.1.0 (default: the latest)
  --prefix   Directory to install into (default: \$HOME/.local/bin)

Re-run to upgrade.
EOF
    exit 2
}

die() {
    echo "install.sh: $*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --version) [ $# -ge 2 ] || usage; VERSION="$2"; shift 2 ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        --prefix) [ $# -ge 2 ] || usage; PREFIX="$2"; shift 2 ;;
        --prefix=*) PREFIX="${1#*=}"; shift ;;
        -h|--help) usage ;;
        -*) die "unknown option: $1" ;;
        *) TOOL="$1"; shift ;;
    esac
done

need curl
need tar

# --- work out which build to fetch -----------------------------------------

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
    Darwin) os_name="darwin" ;;
    Linux) os_name="linux" ;;
    *) die "unsupported operating system: $os" ;;
esac

case "$arch" in
    arm64|aarch64) arch_name="arm64" ;;
    x86_64|amd64) arch_name="amd64" ;;
    *) die "unsupported architecture: $arch" ;;
esac

target="${os_name}-${arch_name}"

# There is no Intel macOS build: Apple stopped shipping those Macs in 2023, and
# Rosetta translates x86 to arm rather than the reverse, so there is nothing to
# fall back to.
[ "$target" = "darwin-amd64" ] && die "Intel Macs are not supported; use an Apple Silicon Mac, or run the Linux build under Docker"

# Only the amd64 Linux build is statically linked. GraalVM's musl toolchain is
# x86_64 only, so the arm64 build carries a glibc floor and would otherwise fail
# at startup with an unexplained "GLIBC_2.39 not found".
if [ "$target" = "linux-arm64" ] && command -v ldd >/dev/null 2>&1; then
    have="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$' || true)"
    if [ -n "$have" ]; then
        oldest="$(printf '%s\n2.39\n' "$have" | sort -V | head -1)"
        [ "$oldest" = "2.39" ] || die "the arm64 Linux build needs glibc 2.39 or newer, and this system has $have"
    fi
fi

# --- resolve the version ----------------------------------------------------

if [ "$VERSION" = "latest" ]; then
    # Follows the redirect that /releases/latest performs, so no API call and no
    # rate limit to trip over.
    resolved="$(curl -sfLI -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest" | sed 's#.*/tag/##')"
    [ -n "$resolved" ] || die "could not determine the latest release"
    VERSION="${resolved#"${TOOL}-"}"
    VERSION="${VERSION#v}"
fi

base="https://github.com/${REPO}/releases/download/${TOOL}-v${VERSION}"
archive="${TOOL}-${target}.tar.gz"

# --- fetch and verify -------------------------------------------------------

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

echo "Installing ${TOOL} ${VERSION} (${target})" >&2

curl -sfL "${base}/${archive}" -o "${tmp}/${archive}" \
    || die "could not download ${base}/${archive}"
curl -sfL "${base}/${archive}.sha256" -o "${tmp}/${archive}.sha256" \
    || die "could not download the checksum for ${archive}"

# The point of piping a script from a repository you trust: it verifies the
# binary, so there is one thing to trust rather than two.
expected="$(cut -d' ' -f1 < "${tmp}/${archive}.sha256")"
if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "${tmp}/${archive}" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "${tmp}/${archive}" | cut -d' ' -f1)"
else
    die "neither sha256sum nor shasum is available, so the download cannot be verified"
fi

[ "$expected" = "$actual" ] || die "checksum mismatch for ${archive}: expected ${expected}, got ${actual}"

tar -xzf "${tmp}/${archive}" -C "$tmp" || die "could not unpack ${archive}"
[ -f "${tmp}/${TOOL}" ] || die "${archive} did not contain ${TOOL}"

# --- install ----------------------------------------------------------------

mkdir -p "$PREFIX" || die "could not create ${PREFIX}"
install -m 0755 "${tmp}/${TOOL}" "${PREFIX}/${TOOL}" 2>/dev/null \
    || { cp "${tmp}/${TOOL}" "${PREFIX}/${TOOL}" && chmod 0755 "${PREFIX}/${TOOL}"; } \
    || die "could not install into ${PREFIX}; pass --prefix to choose somewhere writable"

echo "Installed ${PREFIX}/${TOOL}" >&2

# An installer that succeeds and leaves the command unavailable is the commonest
# way this goes wrong, so say so rather than letting it be discovered.
case ":${PATH}:" in
    *":${PREFIX}:"*) ;;
    *)
        echo >&2
        echo "${PREFIX} is not on your PATH. Add it:" >&2
        echo >&2
        echo "  export PATH=\"${PREFIX}:\$PATH\"" >&2
        ;;
esac
