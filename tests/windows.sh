#!/usr/bin/env bash
#
# The half CI cannot have: whether Windows did the thing, not whether we asked
# for it correctly.
#
# Every silent-success bug this project has hit lives here -- `start` returns 0
# for a scheme nothing has registered, `explorer.exe` returns 1 when it worked,
# ShellExecuteEx reports success while opening nothing. None of them are visible
# from an exit code, so these checks look at the result instead.
#
# Run by hand on a real WSL box, before a release. It opens windows: they are
# left for you to close, since closing them is how you confirm what opened.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
OPEN="${OPEN:-$(cd .. && pwd)/open}"

passed=0; failed=0; manual=0

pass() { passed=$((passed + 1)); printf '  ok      %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf '  FAIL    %s\n      %s\n' "$1" "$2"; }
look() { manual=$((manual + 1)); printf '  LOOK    %s\n      %s\n' "$1" "$2"; }

for cmd in wslpath cmd.exe; do
  command -v "$cmd" >/dev/null 2>&1 || {
    printf 'not a WSL machine (%s missing) -- this suite needs one\n' "$cmd"
    exit 1
  }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
printf 'winopen windows-side check\n' > "$WORK/sample.txt"
printf 'text wearing the wrong extension\n' > "$WORK/decoy.pdf"

# A window title is the only honest evidence that something opened. Get-Process
# does not reliably see these from a WSL-spawned PowerShell, so a miss here is
# not proof of absence -- hence LOOK rather than FAIL.
title_matching() {
  command -v powershell.exe >/dev/null 2>&1 || return 1
  powershell.exe -NoProfile -Command \
    "Get-Process | Where-Object { \$_.MainWindowTitle -match '$1' } |
     Select-Object -First 1 -ExpandProperty MainWindowTitle" 2>/dev/null | tr -d '\r'
}

printf '\nexit statuses against the real Windows\n'

for c in "$WORK/sample.txt" "." "https://example.com"; do
  if timeout 60 "$OPEN" "$c" >/dev/null 2>&1; then
    pass "open $c -> 0"
  else
    fail "open $c" "exited $?; explorer.exe returning 1 on success is the usual cause"
  fi
  sleep 1
done

printf '\n-t opens with the .txt handler, not the file own extension\n'
if timeout 60 "$OPEN" -t "$WORK/decoy.pdf" >/dev/null 2>&1; then
  sleep 4
  found="$(title_matching 'decoy')"
  if [[ "$found" == *Notepad* || "$found" == *notepad* ]]; then
    pass "decoy.pdf opened in the text editor ($found)"
  else
    look "decoy.pdf" "expected a text editor window; saw '${found:-nothing}'. Check the screen."
  fi
else
  fail "open -t decoy.pdf" "exited non-zero"
fi

printf '\n-n opens a new window rather than reusing one\n'
if timeout 60 "$OPEN" -n https://example.com >/dev/null 2>&1; then
  look "open -n https://example.com" "a NEW browser window should have appeared, not a new tab"
else
  fail "open -n" "exited non-zero"
fi

printf '\nthings Windows will not tell us\n'
if timeout 60 "$OPEN" "definitely-not-a-scheme://nothing" >/dev/null 2>&1; then
  pass "an unregistered scheme still exits 0 (documented: we cannot detect it)"
else
  fail "unregistered scheme" "exited non-zero, which contradicts the README"
fi

printf '\n  %d passed, %d failed, %d need your eyes\n' "$passed" "$failed" "$manual"
[[ $failed -eq 0 ]]
