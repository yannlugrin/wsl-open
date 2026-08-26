#!/usr/bin/env bash
#
# Assertions and a stubbed Windows, for tests that run anywhere.
#
# The tool never touches Windows directly: it spawns wslpath, cmd.exe,
# explorer.exe and powershell.exe by name. Putting stubs for those first on a
# scrubbed PATH makes every one of them observable and makes the whole suite
# runnable on a plain Linux box -- which is what CI has.

set -uo pipefail

OPEN="${OPEN:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/open}"

passed=0
failed=0
skipped=0
current=""

setup_stubs() {
  STUB_DIR="$(mktemp -d)"
  DISPATCH_LOG="$STUB_DIR/dispatch.log"
  WORK_DIR="$(mktemp -d)"

  # Deterministic, so assertions can name the exact string the tool builds.
  cat > "$STUB_DIR/wslpath" <<'EOF'
#!/usr/bin/env bash
p="${!#}"
[[ "$p" = /* ]] || p="$PWD/$p"
printf 'W:%s\n' "${p//\//\\}"
EOF

  printf '#!/usr/bin/env bash\nprintf "cmd.exe %%s\\n" "$*" >> "%s"\n' \
    "$DISPATCH_LOG" > "$STUB_DIR/cmd.exe"

  # Mirrors the real one, which returns 1 whether or not it worked.
  printf '#!/usr/bin/env bash\nprintf "explorer.exe %%s\\n" "$*" >> "%s"\nexit 1\n' \
    "$DISPATCH_LOG" > "$STUB_DIR/explorer.exe"

  chmod +x "$STUB_DIR"/wslpath "$STUB_DIR"/cmd.exe "$STUB_DIR"/explorer.exe

  : > "$WORK_DIR/file.txt"
  mkdir -p "$WORK_DIR/dir"
}

# The helper that keeps a URL's tab on the desktop in view runs under
# powershell.exe. Stubbing it makes visible both that the helper was reached and
# what it was asked to do -- and MODE=fail exercises the fall-back.
stub_powershell() {
  cat > "$STUB_DIR/powershell.exe" <<EOF
#!/usr/bin/env bash
printf 'powershell.exe %s\n' "\$*" >> "$DISPATCH_LOG"
exit \${POWERSHELL_EXIT:-0}
EOF
  chmod +x "$STUB_DIR/powershell.exe"
}

unstub_powershell() { rm -f "$STUB_DIR/powershell.exe"; }

# The update check asks GitHub what the latest release is. Stubbing curl keeps
# the suite hermetic -- no network, no rate limit, and the failure modes become
# reachable on demand.
stub_curl() {
  case "$1" in
    redirect) printf '#!/usr/bin/env bash\nprintf "%%s" "%s"\n' "$2" > "$STUB_DIR/curl" ;;
    fail)     printf '#!/usr/bin/env bash\nexit 6\n' > "$STUB_DIR/curl" ;;
    # A release, served from a directory of assets: $2 the tag, $3 that
    # directory, $4 how it should go wrong -- noassets, nosums or badsum.
    release)
      cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
case " \$* " in *" -fsI "*) printf 'https://github.com/x/y/releases/tag/$2'; exit 0 ;; esac
url=""; out=""; prev=""
for a in "\$@"; do
  [[ "\$prev" == "-o" ]] && out="\$a"
  case "\$a" in http*) url="\$a" ;; esac
  prev="\$a"
done
case "\$url" in
  *.tar.gz)
    if [[ "${4:-ok}" == noassets ]]; then exit 22; fi
    cp "$3/winopen-$2.tar.gz" "\$out" ;;
  *SHA256SUMS)
    case "${4:-ok}" in
      nosums) exit 22 ;;
      badsum) cp "$3/SHA256SUMS.bad" "\$out" ;;
      *)      cp "$3/SHA256SUMS" "\$out" ;;
    esac ;;
  *) exit 22 ;;
esac
EOF
      ;;
  esac
  chmod +x "$STUB_DIR/curl"
}

# -w is always true for root, so the "this needs root" paths cannot be reached.
is_root() { [[ "$(id -u)" == 0 ]]; }

unstub_curl() { rm -f "$STUB_DIR/curl"; }

teardown_stubs() {
  [[ -n "${STUB_DIR:-}" ]] && rm -rf "$STUB_DIR"
  [[ -n "${WORK_DIR:-}" ]] && rm -rf "$WORK_DIR"
  return 0
}

# env -i so a developer's own PATH cannot reach a real cmd.exe and turn a unit
# test into something that opens windows.
run_open() {
  : > "$DISPATCH_LOG"
  STDOUT="$(env -i \
    HOME="$HOME" \
    PATH="$STUB_DIR:/usr/bin:/bin" \
    ${WINOPEN_EDITOR+WINOPEN_EDITOR="$WINOPEN_EDITOR"} \
    ${PREFIX+PREFIX="$PREFIX"} \
    ${WINOPEN_DESKTOP+WINOPEN_DESKTOP="$WINOPEN_DESKTOP"} \
    ${POWERSHELL_EXIT+POWERSHELL_EXIT="$POWERSHELL_EXIT"} \
    bash "$OPEN" "$@" 2>"$STUB_DIR/stderr")"
  STATUS=$?
  STDERR="$(cat "$STUB_DIR/stderr")"
  DISPATCH="$(cat "$DISPATCH_LOG")"
  return 0
}

it() { current="$1"; }

ok()   { passed=$((passed + 1)); }
skip() { skipped=$((skipped + 1)); printf '  SKIP  %s (%s)\n' "$current" "$1"; }
bad()  {
  failed=$((failed + 1))
  printf '  FAIL  %s\n' "$current"
  printf '        %s\n' "$@"
}

assert_status() {
  if [[ "$STATUS" == "$1" ]]; then ok; else
    bad "expected exit $1, got $STATUS" "stderr: $STDERR"; fi
}

assert_dispatch() {
  if [[ "$DISPATCH" == "$1" ]]; then ok; else
    bad "expected dispatch: $1" "actual dispatch:   ${DISPATCH:-<nothing>}"; fi
}

assert_no_dispatch() {
  if [[ -z "$DISPATCH" ]]; then ok; else
    bad "expected nothing to be dispatched" "actual: $DISPATCH"; fi
}

assert_stderr() {
  if [[ "$STDERR" == *"$1"* ]]; then ok; else
    bad "expected stderr to contain: $1" "actual stderr: ${STDERR:-<empty>}"; fi
}

assert_stdout() {
  if [[ "$STDOUT" == *"$1"* ]]; then ok; else
    bad "expected stdout to contain: $1" "actual stdout: ${STDOUT:-<empty>}"; fi
}

assert_empty_stdout() {
  if [[ -z "$STDOUT" ]]; then ok; else
    bad "expected empty stdout" "actual: $STDOUT"; fi
}

summary() {
  printf '\n  %d passed, %d failed' "$passed" "$failed"
  [[ $skipped -gt 0 ]] && printf ', %d skipped' "$skipped"
  printf '\n'
  [[ $failed -eq 0 ]]
}
