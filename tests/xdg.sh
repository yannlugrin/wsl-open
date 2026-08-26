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

it "says the shim is only found on the PATH its callers run with"
if [[ "$STDOUT" == *"comes first on the PATH they"* ]]; then ok; else
  bad "no word on where callers look" "$STDOUT"; fi

it "a second install is a no-op, not a second link"
run_open --install-xdg
assert_status 0
assert_stdout "Already installed"

it "goes beside the tool when no prefix says otherwise"
tree="$(mktemp -d)"
mkdir -p "$tree/bin"
cp "$OPEN" "$tree/bin/open"
STDOUT="$(env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
  bash "$tree/bin/open" --install-xdg 2>"$STUB_DIR/stderr")"
STATUS=$?
STDERR="$(cat "$STUB_DIR/stderr")"
if [[ "$STATUS" == 0 && -L "$tree/bin/xdg-open" ]]; then ok; else
  bad "expected the shim beside the tool" "status=$STATUS stderr=$STDERR"; fi

it "points elsewhere at where the callers that matter do look"
if [[ "$STDOUT" == *"PREFIX=/usr/local"* ]]; then ok; else
  bad "no way out for a prefix nothing else reads" "$STDOUT"; fi
rm -rf "$tree"

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

# --- it never becomes root on your behalf (#16) ----------------------------

# An earlier test leaves a backup behind on purpose; start from nothing.
rm -f "$SHIM" "$SHIM.winopen-backup"

it "prints the command instead of escalating, and changes nothing"
if is_root; then skip "running as root, every path is writable"; else
  chmod 555 "$PREFIX/bin"
  run_open --install-xdg
  chmod 755 "$PREFIX/bin"
  if [[ "$STATUS" == 1 && "$STDERR" == *"needs root"* && "$STDERR" == *"sudo "* \
        && ! -e "$SHIM" ]]; then ok; else
    bad "expected a refusal that changed nothing" "status=$STATUS stderr=$STDERR"; fi
fi

it "names the invocation and the prefix, so the hint can be pasted"
if is_root; then skip "running as root"; else
  chmod 555 "$PREFIX/bin"
  run_open --install-xdg
  chmod 755 "$PREFIX/bin"
  if [[ "$STDERR" == *"PREFIX=$PREFIX"* && "$STDERR" == *"--install-xdg"* ]]; then ok; else
    bad "the sudo hint would not work if pasted" "$STDERR"; fi
fi

it "uninstall refuses the same way rather than escalating"
if is_root; then skip "running as root"; else
  run_open --install-xdg >/dev/null 2>&1
  chmod 555 "$PREFIX/bin"
  run_open --uninstall-xdg
  chmod 755 "$PREFIX/bin"
  if [[ "$STATUS" == 1 && "$STDERR" == *"needs root"* && -L "$SHIM" ]]; then ok; else
    bad "expected a refusal leaving the shim in place" "status=$STATUS"; fi
  run_open --uninstall-xdg >/dev/null 2>&1
fi

summary
