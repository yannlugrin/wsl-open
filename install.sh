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

URL="https://raw.githubusercontent.com/$REPO/$VERSION/open"

echo "Installing winopen $VERSION to $DEST..."

sudo_cmd=""
if [[ ! -w "$PREFIX/bin" ]]; then
  sudo_cmd="sudo"
fi

$sudo_cmd mkdir -p "$PREFIX/bin"

staged=""
tmpfile="$(mktemp)"
cleanup() {
  rm -f "$tmpfile"
  [[ -n "$staged" ]] && $sudo_cmd rm -f "$staged"
  return 0
}
trap cleanup EXIT

# Downloaded whole before anything is replaced. Piping curl straight at the
# destination meant a dropped connection left a truncated file on PATH under
# the name `open` -- verified: it replaced a working install with 20 lines that
# would not run.
curl -fsSL "$URL" -o "$tmpfile" || {
  echo "Download failed; nothing was changed." >&2
  exit 1
}

# A proxy or an error page returns 200 with a body that is not the tool.
head -n 1 "$tmpfile" | grep -q '^#!.*sh' && grep -q '^VERSION=' "$tmpfile" || {
  echo "What was downloaded does not look like winopen; nothing was changed." >&2
  exit 1
}

# Staged beside the destination so the last step is a rename within one
# filesystem, which either happens or does not. Installing over the top can
# still truncate if it is interrupted.
staged="$PREFIX/bin/.open.$$"
$sudo_cmd install -m 755 "$tmpfile" "$staged"
$sudo_cmd mv -f "$staged" "$DEST"
staged=""

echo "Installed successfully: $("$DEST" --version)"
