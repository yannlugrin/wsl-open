#!/usr/bin/env bash
#
# The xdg-open shim: its own contract, which is not open(1)'s -- exactly one
# target, and the exit codes callers branch on -- plus install and uninstall.
# All of it runs against a scratch PREFIX, so none of it needs root.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=tests/lib.sh
source ./lib.sh

setup_stubs
PREFIX="$(mktemp -d)"
mkdir -p "$PREFIX/bin"
trap 'teardown_stubs; rm -rf "$PREFIX"' EXIT

SHIM="$PREFIX/bin/xdg-open"

run_shim() {
  : > "$DISPATCH_LOG"
  STDOUT="$(env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
    ${WINOPEN_XDG+WINOPEN_XDG="$WINOPEN_XDG"} \
    bash "$SHIM" "$@" 2>"$STUB_DIR/stderr")"
  STATUS=$?
  STDERR="$(cat "$STUB_DIR/stderr")"
  DISPATCH="$(cat "$DISPATCH_LOG")"
  return 0
}

printf 'xdg-open shim\n'

# --- install ---------------------------------------------------------------

it "installs as a symlink to the tool"
run_open --install-xdg
assert_status 0
if [[ -L "$SHIM" && "$(readlink -f "$SHIM")" == "$(readlink -f "$OPEN")" ]]; then ok; else
  bad "expected $SHIM -> $OPEN"; fi

it "a second install is a no-op, not a second link"
run_open --install-xdg
assert_status 0
assert_stdout "Already installed"

# --- the contract ----------------------------------------------------------

it "opens one target"
run_shim "$WORK_DIR/file.txt"
assert_status 0
assert_dispatch "cmd.exe /C start  W:${WORK_DIR//\//\\}\\file.txt"

it "opens a URL"
run_shim "https://example.com"
assert_status 0

it "exit 2 when the file does not exist, not our flat 1"
run_shim /nonexistent-winopen-test
assert_status 2

it "exit 1 on no arguments"
run_shim
assert_status 1

it "exit 1 on more than one argument, which xdg-open does not take"
run_shim a b
assert_status 1

it "--manual is accepted, as xdg-open defines it"
run_shim --manual
assert_status 0
assert_stdout "Usage: xdg-open"

it "--version reports winopen rather than claiming an xdg-utils version"
run_shim --version
assert_status 0
assert_stdout "winopen"

# --- WINOPEN_XDG=0 ---------------------------------------------------------

it "exit 3 when bypassed with nothing to delegate to"
WINOPEN_XDG=0 run_shim "$WORK_DIR/file.txt"
assert_status 3
unset WINOPEN_XDG

it "delegates to a shadowed xdg-open when bypassed, without recursing"
printf '#!/usr/bin/env bash\nprintf "system-xdg-open %%s\\n" "$*" >> "%s"\n' \
  "$DISPATCH_LOG" > "$STUB_DIR/xdg-open"
chmod +x "$STUB_DIR/xdg-open"
: > "$DISPATCH_LOG"
STATUS=0
timeout 10 env -i HOME="$HOME" PATH="$PREFIX/bin:$STUB_DIR:/usr/bin:/bin" \
  WINOPEN_XDG=0 bash "$SHIM" "$WORK_DIR/file.txt" >/dev/null 2>&1 || STATUS=$?
DISPATCH="$(cat "$DISPATCH_LOG")"
if [[ "$STATUS" == 124 ]]; then
  bad "it recursed into itself until the timeout fired"
elif [[ "$DISPATCH" == system-xdg-open* ]]; then ok; else
  bad "expected the shadowed xdg-open to run" "got: ${DISPATCH:-<nothing>}"; fi
rm -f "$STUB_DIR/xdg-open"

# --- uninstall -------------------------------------------------------------

it "uninstall removes the shim"
run_open --uninstall-xdg
assert_status 0
if [[ ! -e "$SHIM" ]]; then ok; else bad "$SHIM survived uninstall"; fi

it "uninstall refuses when it is not ours"
printf '#!/bin/sh\necho other\n' > "$SHIM"
chmod +x "$SHIM"
run_open --uninstall-xdg
assert_status 1
assert_stderr "not installed by winopen"

it "install backs up a foreign xdg-open at the same path"
run_open --install-xdg
assert_status 0
if [[ -e "$SHIM.winopen-backup" ]]; then ok; else bad "no backup was taken"; fi

it "uninstall restores the backup"
run_open --uninstall-xdg
assert_status 0
if [[ -e "$SHIM" && ! -L "$SHIM" ]]; then ok; else bad "the backup was not restored"; fi

it "install refuses to overwrite an existing backup"
cp "$SHIM" "$SHIM.winopen-backup"
run_open --install-xdg
assert_status 1
assert_stderr "refusing to overwrite an existing backup"

summary
