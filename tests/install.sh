#!/usr/bin/env bash
#
# install.sh, with curl stubbed. The interesting cases are the ones where the
# download does not go well: piping curl straight at the destination used to
# leave a truncated file on PATH under the name `open`, replacing a working
# install with one that would not run.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=tests/lib.sh
source ./lib.sh

INSTALLER="$(cd .. && pwd)/install.sh"
setup_stubs
PREFIX_DIR="$(mktemp -d)"
trap 'teardown_stubs; rm -rf "$PREFIX_DIR"' EXIT

# Honours -o, like the real thing. MODE picks what goes wrong.
cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
out=""; prev=""
for a in "\$@"; do [[ "\$prev" == "-o" ]] && out="\$a"; prev="\$a"; done
# The redirect that resolves the tag. MODE decides what it resolves to, so
# the no-releases case has to be answered here rather than below.
case " \$* " in
  *" -fsI "*)
    if [[ "\${MODE:-ok}" == noreleases ]]; then
      printf 'https://github.com/x/y/releases'
    else
      printf 'https://github.com/x/y/releases/tag/1.0.1'
    fi
    exit 0 ;;
esac
case "\${MODE:-ok}" in
  truncated) head -20 "$OPEN" > "\$out"; exit 18 ;;
  htmlerror) printf '<!DOCTYPE html><html>404</html>\n' > "\$out"; exit 0 ;;
  *)         cat "$OPEN" > "\$out"; exit 0 ;;
esac
EOF
chmod +x "$STUB_DIR/curl"

fresh_prefix() {
  rm -rf "${PREFIX_DIR:?}/bin"
  mkdir -p "$PREFIX_DIR/bin"
  printf '#!/bin/sh\necho PREVIOUS\n' > "$PREFIX_DIR/bin/open"
  chmod +x "$PREFIX_DIR/bin/open"
}

run_installer() {
  fresh_prefix
  STDOUT="$(env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
    MODE="$1" PREFIX="$PREFIX_DIR" bash "$INSTALLER" 2>"$STUB_DIR/stderr")"
  STATUS=$?
  STDERR="$(cat "$STUB_DIR/stderr")"
  INSTALLED="$("$PREFIX_DIR/bin/open" --version 2>&1 | head -1)"
  LEFTOVERS="$(ls -A "$PREFIX_DIR/bin" | tr '\n' ' ')"
  return 0
}

printf 'install.sh\n'

it "installs when the download succeeds"
run_installer ok
assert_status 0
if [[ "$INSTALLED" == open* ]]; then ok; else bad "expected the tool, got: $INSTALLED"; fi

it "leaves the previous install alone when the download is cut short"
run_installer truncated
assert_status 1
assert_stderr "nothing was changed"
if [[ "$INSTALLED" == *PREVIOUS* ]]; then ok; else
  bad "the working install was replaced by a partial download: $INSTALLED"; fi

it "rejects a body that is not the tool"
run_installer htmlerror
assert_status 1
assert_stderr "does not look like winopen"
if [[ "$INSTALLED" == *PREVIOUS* ]]; then ok; else bad "an error page was installed"; fi

it "refuses when the repository has no releases"
run_installer noreleases
assert_status 1
assert_stderr "No releases found"

it "leaves no staging files behind, whatever happened"
for mode in ok truncated htmlerror; do
  run_installer "$mode"
  if [[ "$LEFTOVERS" == "open " ]]; then :; else
    bad "MODE=$mode left: $LEFTOVERS"; break
  fi
done
[[ "$LEFTOVERS" == "open " ]] && ok

summary
