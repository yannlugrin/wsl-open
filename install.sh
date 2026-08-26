#!/usr/bin/env bash
set -euo pipefail

REPO="yannlugrin/winopen"
SELF_URL="https://raw.githubusercontent.com/$REPO/main/install.sh"

usage() {
  cat <<EOF
Usage: install.sh

Installs winopen. One file on your PATH, and nothing else unless asked.

  -h, --help   Show this help

Environment:
  PREFIX         Where to install (default: \$HOME/.local, which needs no root)
  VERSION        A release tag to install (default: the latest release)
  WITHOUT_DESKTOP  Set to 1 to skip the PowerShell helper that opens a URL on
                 the virtual desktop you are looking at. Installed by default;
                 it goes beside the tool and needs no privilege the tool does
                 not already need.

Piped from curl, the assignment goes on the right of the pipe -- on the left it
would be set for curl, which does not care:

  curl -fsSL $SELF_URL | PREFIX=/usr/local bash
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    *)
      echo "install.sh: unknown option: $1" >&2
      echo >&2
      usage >&2
      exit 1 ;;
  esac
done

# On by default. It lands in the same prefix as the tool, so it asks for no
# privilege the tool does not already need, and without it URLs open wherever
# Windows feels like -- which is the thing this tool exists to fix.
case "${WITHOUT_DESKTOP:-0}" in
  1|true|yes) want_desktop=false ;;
  *)          want_desktop=true ;;
esac

PREFIX="${PREFIX:-$HOME/.local}"
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


staged=""
helper_file=""
keep_workdir=false
workdir="$(mktemp -d)"
cleanup() {
  $keep_workdir || rm -rf "$workdir"
  [[ -n "$staged" ]] && rm -f "$staged"
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
  if $want_desktop; then
    helper_file="$workdir/winopen-${VERSION}/libexec/open-url.ps1"
  fi
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

# Nothing here escalates, exactly as `open` does not. Re-running this under sudo
# would be worse than either: piped from curl, that runs the download as root
# too. So the work that could be done as this user has been, and what is left is
# printed for them to run.
#
# Whether root is needed is a question about the nearest directory that exists:
# on a fresh prefix, $PREFIX/bin has not been created yet.
probe="$PREFIX/bin"
while [[ ! -e "$probe" && "$probe" != "/" && "$probe" != "." ]]; do
  probe="$(dirname "$probe")"
done

if [[ ! -w "$probe" ]]; then
  keep_workdir=true
  {
    echo
    echo "Downloaded and verified winopen $VERSION."
    echo "$PREFIX/bin is not yours to write, so the rest needs root:"
    echo
    echo "    sudo install -d $PREFIX/bin"
    echo "    sudo install -m 755 $source_file $DEST"
    if [[ -n "$helper_file" && -f "$helper_file" ]]; then
      echo "    sudo install -d $PREFIX/libexec/winopen"
      echo "    sudo install -m 644 $helper_file $PREFIX/libexec/winopen/open-url.ps1"
    fi
    echo
    echo "Or install somewhere you own, which needs no root at all:"
    # Piped from curl, $0 is the shell, not something anyone can re-run.
    if [[ -f "$0" ]]; then
      echo "    PREFIX=$HOME/.local $0"
    else
      # On the left of the pipe it would be set for curl, which does not care.
      echo "    curl -fsSL $SELF_URL | PREFIX=$HOME/.local bash"
    fi
  } >&2
  exit 1
fi

mkdir -p "$PREFIX/bin"

# The PowerShell helper that keeps a URL's tab on the desktop in view. Optional:
# `open` works without it, just without that. Only the tarball carries it, so a
# fallback install simply has none.
if [[ -n "$helper_file" && -f "$helper_file" ]]; then
  mkdir -p "$PREFIX/libexec/winopen"
  install -m 644 "$helper_file" "$PREFIX/libexec/winopen/open-url.ps1"
fi

# Staged beside the destination so the last step is a rename within one
# filesystem, which either happens or does not. Installing over the top can
# still truncate if it is interrupted.
staged="$PREFIX/bin/.open.$$"
install -m 755 "$source_file" "$staged"
mv -f "$staged" "$DEST"
staged=""

echo "Installed successfully: $("$DEST" --version)"

# Asked for it and did not get it: releases published before the helper existed
# carry no assets to take it from.
if $want_desktop && [[ -z "$helper_file" || ! -f "$helper_file" ]]; then
  echo
  echo "This release carries no virtual-desktop helper, so URLs go straight to"
  echo "Windows, which opens them in whichever browser window was last active"
  echo "-- possibly on a desktop you are not looking at."
fi
