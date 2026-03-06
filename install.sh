#!/usr/bin/env bash
set -euo pipefail

REPO="yannlugrin/wsl-open"
PREFIX="${PREFIX:-/usr/local}"
DEST="$PREFIX/bin/open"

VERSION="${VERSION:-latest}"
if [[ "$VERSION" == "latest" ]]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)"
fi

URL="https://raw.githubusercontent.com/$REPO/$VERSION/open"

echo "Installing wsl-open $VERSION to $DEST..."

sudo_cmd=""
if [[ ! -w "$(dirname "$DEST")" ]]; then
  sudo_cmd="sudo"
fi

$sudo_cmd mkdir -p "$PREFIX/bin"
curl -fsSL "$URL" | $sudo_cmd tee "$DEST" > /dev/null
$sudo_cmd chmod +x "$DEST"

echo "Installed successfully: $($DEST --version)"
