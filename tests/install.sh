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
trap 'teardown_stubs; rm -rf "$PREFIX_DIR" "${FIXTURE:-}"' EXIT

# A real tarball and checksum, so the verification path is exercised rather
# than mocked past.
FIXTURE="$(mktemp -d)"
mkdir -p "$FIXTURE/winopen-1.0.1/libexec"
cp "$OPEN" "$FIXTURE/winopen-1.0.1/open"
printf '# stand-in helper\n' > "$FIXTURE/winopen-1.0.1/libexec/open-url.ps1"
tar -czf "$FIXTURE/winopen-1.0.1.tar.gz" -C "$FIXTURE" winopen-1.0.1
( cd "$FIXTURE" && sha256sum winopen-1.0.1.tar.gz > SHA256SUMS )
printf 'deadbeef  winopen-1.0.1.tar.gz\n' > "$FIXTURE/SHA256SUMS.bad"
printf '<!DOCTYPE html><html>404</html>\n' > "$FIXTURE/notatool"

# Serves the release assets or the raw script, depending on MODE. Honours -o,
# like the real thing.
cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
url=""; out=""; prev=""
for a in "\$@"; do
  [[ "\$prev" == "-o" ]] && out="\$a"
  case "\$a" in http*) url="\$a" ;; esac
  prev="\$a"
done

case " \$* " in
  *" -fsI "*)
    if [[ "\${MODE:-assets}" == noreleases ]]; then
      printf 'https://github.com/x/y/releases'
    else
      printf 'https://github.com/x/y/releases/tag/1.0.1'
    fi
    exit 0 ;;
esac

case "\$url" in
  *winopen-1.0.1.tar.gz)
    case "\${MODE:-assets}" in
      noassets|truncated|htmlerror) exit 22 ;;
      *) cp "$FIXTURE/winopen-1.0.1.tar.gz" "\$out"; exit 0 ;;
    esac ;;
  *SHA256SUMS)
    case "\${MODE:-assets}" in
      nosums) exit 22 ;;
      badsum) cp "$FIXTURE/SHA256SUMS.bad" "\$out"; exit 0 ;;
      *) cp "$FIXTURE/SHA256SUMS" "\$out"; exit 0 ;;
    esac ;;
  *raw.githubusercontent.com*)
    case "\${MODE:-assets}" in
      truncated) head -20 "$OPEN" > "\$out"; exit 18 ;;
      htmlerror) cp "$FIXTURE/notatool" "\$out"; exit 0 ;;
      *) cp "$OPEN" "\$out"; exit 0 ;;
    esac ;;
esac
exit 22
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

it "installs from the release tarball when there is one"
run_installer assets
assert_status 0
if [[ "$INSTALLED" == open* ]]; then ok; else bad "expected the tool, got: $INSTALLED"; fi

it "installs the PowerShell helper alongside the tool"
run_installer assets
if [[ -f "$PREFIX_DIR/libexec/winopen/open-url.ps1" ]]; then ok; else
  bad "the helper was not installed"; fi

it "installs without a helper when falling back to the tagged script"
rm -rf "$PREFIX_DIR/libexec"
run_installer noassets
assert_status 0
if [[ ! -e "$PREFIX_DIR/libexec/winopen/open-url.ps1" ]]; then ok; else
  bad "a helper appeared from a release that has none"; fi

it "refuses a tarball whose checksum does not match"
run_installer badsum
assert_status 1
assert_stderr "Checksum mismatch"
if [[ "$INSTALLED" == *PREVIOUS* ]]; then ok; else bad "it installed anyway"; fi

it "refuses a release that has a tarball but no SHA256SUMS"
run_installer nosums
assert_status 1
assert_stderr "no SHA256SUMS"

it "falls back to the tagged script for releases published without assets"
run_installer noassets
assert_status 0
assert_stderr "falling back"
if [[ "$INSTALLED" == open* ]]; then ok; else bad "the fallback did not install"; fi

it "leaves the previous install alone when the fallback is cut short"
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
for mode in assets badsum nosums noassets truncated htmlerror; do
  run_installer "$mode"
  if [[ "$LEFTOVERS" == "open " ]]; then :; else
    bad "MODE=$mode left: $LEFTOVERS"; break
  fi
done
[[ "$LEFTOVERS" == "open " ]] && ok

summary
