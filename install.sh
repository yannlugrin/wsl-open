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
if [[ ! -w "$(dirname "$DEST")" ]]; then
  sudo_cmd="sudo"
fi

$sudo_cmd mkdir -p "$PREFIX/bin"
curl -fsSL "$URL" | $sudo_cmd tee "$DEST" > /dev/null
$sudo_cmd chmod +x "$DEST"

echo "Installed successfully: $($DEST --version)"
