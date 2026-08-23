#!/usr/bin/env bash
set -euo pipefail

REPO="yannlugrin/winopen"
PREFIX="${PREFIX:-/usr/local}"
DEST="$PREFIX/bin/open"

VERSION="${VERSION:-latest}"
if [[ "$VERSION" == "latest" ]]; then
  # The releases/latest redirect names the tag, with no API rate limit and no
  # JSON to parse. A repository with no releases redirects to the releases page
  # instead, whose last path component would pass for a tag name.
  redirect="$(curl -fsI -o /dev/null -w '%{redirect_url}' \
    "https://github.com/$REPO/releases/latest" 2>/dev/null)" ||
    { echo "Could not reach GitHub to resolve the latest release." >&2; exit 1; }
  case "$redirect" in
    */releases/tag/*) VERSION="${redirect##*/}" ;;
    *) echo "No releases found for $REPO." >&2; exit 1 ;;
  esac
fi

echo "Installing winopen $VERSION to $DEST..."

# Whether root is needed is a question about the nearest directory that exists,
# not about $PREFIX/bin: on a fresh prefix that directory has not been created
# yet, so testing it directly asks for a password to write somewhere the user
# already owns.
probe="$PREFIX/bin"
while [[ ! -e "$probe" && "$probe" != "/" && "$probe" != "." ]]; do
  probe="$(dirname "$probe")"
done

sudo_cmd=""
if [[ ! -w "$probe" ]]; then
  sudo_cmd="sudo"
fi

$sudo_cmd mkdir -p "$PREFIX/bin"

staged=""
helper_file=""
workdir="$(mktemp -d)"
cleanup() {
  rm -rf "$workdir"
  [[ -n "$staged" ]] && $sudo_cmd rm -f "$staged"
  return 0
}
trap cleanup EXIT

asset="winopen-${VERSION}.tar.gz"
base="https://github.com/$REPO/releases/download/$VERSION"
source_file=""

# Release assets are the intended mechanism: a tag can be moved with `git tag
# -f`, and raw.githubusercontent.com follows it, so the same URL can serve
# different content over time. An asset cannot be replaced without it showing.
if curl -fsSL "$base/$asset" -o "$workdir/$asset" 2>/dev/null; then
  curl -fsSL "$base/SHA256SUMS" -o "$workdir/SHA256SUMS" || {
    echo "The release has a tarball but no SHA256SUMS; nothing was changed." >&2
    exit 1
  }

  # --ignore-missing so a SHA256SUMS listing several assets still verifies when
  # only one of them was downloaded.
  ( cd "$workdir" && sha256sum --ignore-missing -c SHA256SUMS >/dev/null ) || {
    echo "Checksum mismatch for $asset; nothing was changed." >&2
    exit 1
  }

  tar -xzf "$workdir/$asset" -C "$workdir" || {
    echo "Could not unpack $asset; nothing was changed." >&2
    exit 1
  }
  source_file="$workdir/winopen-${VERSION}/open"
  helper_file="$workdir/winopen-${VERSION}/libexec/open-url.ps1"
else
  # Releases made before the tarball existed have no assets at all. Falling
  # back keeps `VERSION=1.0.1` installable rather than breaking older pins.
  echo "No release assets for $VERSION; falling back to the tagged script." >&2
  curl -fsSL "https://raw.githubusercontent.com/$REPO/$VERSION/open" \
    -o "$workdir/open" || {
    echo "Download failed; nothing was changed." >&2
    exit 1
  }
  source_file="$workdir/open"
fi

# A proxy or an error page returns 200 with a body that is not the tool.
if [[ ! -f "$source_file" ]] ||
   ! { head -n 1 "$source_file" | grep -q '^#!.*sh'; } ||
   ! grep -q '^VERSION=' "$source_file"; then
  echo "What was downloaded does not look like winopen; nothing was changed." >&2
  exit 1
fi

# The PowerShell helper that keeps a URL's tab on the desktop in view. Optional:
# `open` works without it, just without that. Only the tarball carries it, so a
# fallback install simply has none.
if [[ -n "$helper_file" && -f "$helper_file" ]]; then
  $sudo_cmd mkdir -p "$PREFIX/libexec/winopen"
  $sudo_cmd install -m 644 "$helper_file" "$PREFIX/libexec/winopen/open-url.ps1"
fi

# Staged beside the destination so the last step is a rename within one
# filesystem, which either happens or does not. Installing over the top can
# still truncate if it is interrupted.
staged="$PREFIX/bin/.open.$$"
$sudo_cmd install -m 755 "$source_file" "$staged"
$sudo_cmd mv -f "$staged" "$DEST"
staged=""

echo "Installed successfully: $("$DEST" --version)"
