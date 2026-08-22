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
