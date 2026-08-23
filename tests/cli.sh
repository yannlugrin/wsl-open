#!/usr/bin/env bash
#
# What `open` builds, per flag. Asserts the command line handed to Windows and
# the exit status, which between them are the whole contract on this side of
# the boundary.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=tests/lib.sh
source ./lib.sh

setup_stubs
trap teardown_stubs EXIT

printf 'cli\n'

# --- targets ---------------------------------------------------------------

it "opens a file through start"
run_open "$WORK_DIR/file.txt"
assert_status 0
assert_dispatch "cmd.exe /C start  W:${WORK_DIR//\//\\}\\file.txt"

it "opens a directory in Explorer"
run_open "$WORK_DIR/dir"
assert_status 0
assert_dispatch "explorer.exe W:${WORK_DIR//\//\\}\\dir"

it "opens every target, not just the first"
run_open "$WORK_DIR/dir" "$WORK_DIR/dir" "$WORK_DIR/dir"
assert_status 0
if [[ "$(grep -c explorer.exe <<< "$DISPATCH")" == 3 ]]; then ok; else
  bad "expected 3 dispatches, got: $DISPATCH"; fi

it "exits 0 on success, so callers can chain"
run_open "$WORK_DIR/file.txt"
assert_status 0

# --- urls ------------------------------------------------------------------

it "passes a URL through untouched"
run_open "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  https://example.com"

it "accepts any registered-looking scheme, not an allowlist"
run_open "vscode://file/tmp/x"
assert_status 0
assert_dispatch "cmd.exe /C start  vscode://file/tmp/x"

it "treats an existing file named like a URL as a file"
: > "$WORK_DIR/mailto:a@b.c"
run_open "$WORK_DIR/mailto:a@b.c"
assert_status 0
assert_stderr ""

it "-u forces URL treatment over the existing path"
(cd "$WORK_DIR" && : > "foo:bar")
run_open -u "foo:bar"
assert_status 0
assert_dispatch "cmd.exe /C start  foo:bar"

# --- flags reaching URLs (#19) ---------------------------------------------

it "-a applies to a URL"
run_open -a chrome.exe "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe https://example.com"

it "-W applies to a URL"
run_open -W "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  /WAIT https://example.com"

it "-R is refused for a URL rather than ignored"
run_open -R "https://example.com"
assert_status 1
assert_stderr "needs a file, not a URL"
assert_no_dispatch

it "-D is refused for a URL rather than ignored"
run_open -D "https://example.com"
assert_status 1
assert_stderr "needs a file, not a URL"

it "-e is refused for a URL rather than ignored"
run_open -e "https://example.com"
assert_status 1
assert_stderr "need a file, not a URL"

# --- explorer flags --------------------------------------------------------

it "-R reveals the file"
run_open -R "$WORK_DIR/file.txt"
assert_status 0
assert_dispatch "explorer.exe /select,W:${WORK_DIR//\//\\}\\file.txt"

it "-D opens the enclosing folder"
run_open -D "$WORK_DIR/file.txt"
assert_status 0
assert_dispatch "explorer.exe W:${WORK_DIR//\//\\}"

# --- -a and --args ---------------------------------------------------------

it "-a with no target launches the application"
run_open -a chrome.exe
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe"

it "--args goes to the application, after the app and before nothing else"
run_open -a chrome.exe --args --incognito
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe --incognito"

it "--args follows the target when there is one"
run_open -a chrome.exe "$WORK_DIR/file.txt" --args --flag
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe W:${WORK_DIR//\//\\}\\file.txt --flag"

it "-W adds /WAIT"
run_open -W "$WORK_DIR/file.txt"
assert_status 0
assert_dispatch "cmd.exe /C start  /WAIT W:${WORK_DIR//\//\\}\\file.txt"

# --- -- (target separator) -------------------------------------------------

it "-- makes a dash-named target reachable"
(cd "$WORK_DIR" && : > "-dashed.txt")
run_open -- "$WORK_DIR/-dashed.txt"
assert_status 0
assert_dispatch "cmd.exe /C start  W:${WORK_DIR//\//\\}\\-dashed.txt"

it "without --, a dash-named target is still read as flags"
run_open "-dashed.txt"
assert_status 1
assert_stderr "unknown option"

# --- -n (#9) ---------------------------------------------------------------

it "-n with a known application adds its new-window flag"
run_open -n -a chrome.exe "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe --new-window https://example.com"

it "-n uses the Firefox spelling for Firefox"
run_open -n -a firefox.exe "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  firefox.exe -new-window https://example.com"

it "-n opens anyway when the application has no known flag"
run_open -n -a notepad.exe "$WORK_DIR/file.txt"
assert_status 0
assert_stderr "no new-instance flag known"
assert_dispatch "cmd.exe /C start  notepad.exe W:${WORK_DIR//\//\\}\\file.txt"

it "-n opens anyway with no powershell.exe to resolve the application"
run_open -n "$WORK_DIR/file.txt"
assert_status 0
assert_stderr "could not work out which application"
assert_dispatch "cmd.exe /C start  W:${WORK_DIR//\//\\}\\file.txt"

it "-n does not leak its flag onto later targets"
run_open -n -a chrome.exe "https://a.com" "https://b.com"
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe --new-window https://a.com
cmd.exe /C start  chrome.exe --new-window https://b.com"

it "-n warns rather than going silent on the Explorer path"
run_open -n "$WORK_DIR/dir"
assert_status 0
assert_stderr "cannot ask Explorer for a new window"

# --- no target / usage (#7) ------------------------------------------------

it "bare open prints usage to stderr and exits 1"
run_open
assert_status 1
assert_stderr "Usage: open"
assert_empty_stdout

it "-h prints usage to stdout and exits 0"
run_open -h
assert_status 0
assert_stdout "Usage: open"

it "-V prints the version"
run_open -V
assert_status 0
assert_stdout "open "

# --- errors ----------------------------------------------------------------

it "a missing target exits 1"
run_open /nonexistent-winopen-test
assert_status 1
assert_stderr "no such file or directory"

it "an unknown flag exits 1"
run_open -Z
assert_status 1
assert_stderr "unknown option"

it "-a with no application name exits 1"
run_open -a
assert_status 1
assert_stderr "requires an application name"

it "-u with no URL exits 1"
run_open -u
assert_status 1
assert_stderr "requires a URL"

# --- stdin (#3) ------------------------------------------------------------

it "-f writes a .txt temp file and does not delete it"
: > "$DISPATCH_LOG"
rm -f /tmp/winopen-*.txt
printf 'piped\n' | env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
  WINOPEN_EDITOR=cmd.exe bash "$OPEN" -f >/dev/null 2>&1
# `start` returns before the application has read the file, so deleting it here
# would race whatever opened it: it has to still be on disk afterwards.
survivors=(/tmp/winopen-*.txt)
if [[ -e "${survivors[0]}" ]]; then ok; else bad "no /tmp/winopen-*.txt survived the run"; fi
rm -f /tmp/winopen-*.txt

it "-f does not override an explicit -a"
: > "$DISPATCH_LOG"
printf 'piped\n' | env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
  bash "$OPEN" -a chrome.exe -f >/dev/null 2>&1
if grep -q 'chrome.exe' "$DISPATCH_LOG"; then ok; else
  bad "expected chrome.exe, got: $(cat "$DISPATCH_LOG")"; fi
rm -f /tmp/winopen-*.txt

# --- keeping a URL on the desktop in view (#13) ----------------------------

stub_powershell

it "a plain URL goes through the helper"
run_open "https://example.com"
assert_status 0
if [[ "$DISPATCH" == *powershell.exe*open-url.ps1* ]]; then ok; else
  bad "expected the helper to run" "got: ${DISPATCH:-<nothing>}"; fi

it "and the helper is given the URL"
if [[ "$DISPATCH" == *"-Url https://example.com"* ]]; then ok; else
  bad "the URL did not reach the helper" "got: $DISPATCH"; fi

it "-a names the application, so the helper is not consulted"
run_open -a chrome.exe "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe https://example.com"

it "-n is asking for a new window, which is the opposite of reuse"
run_open -n -a chrome.exe "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  chrome.exe --new-window https://example.com"

it "-W wants to wait, which the helper cannot do"
run_open -W "https://example.com"
assert_status 0
assert_dispatch "cmd.exe /C start  /WAIT https://example.com"

it "--args would be dropped by the helper, so it is skipped"
run_open "https://example.com" --args --flag
assert_status 0
assert_dispatch "cmd.exe /C start  https://example.com --flag"

it "WINOPEN_DESKTOP=0 turns it off"
WINOPEN_DESKTOP=0 run_open "https://example.com"
unset WINOPEN_DESKTOP
assert_status 0
assert_dispatch "cmd.exe /C start  https://example.com"

it "falls back to the plain handler when the helper cannot improve on it"
POWERSHELL_EXIT=1 run_open "https://example.com"
unset POWERSHELL_EXIT
assert_status 0
if [[ "$DISPATCH" == *"cmd.exe /C start  https://example.com"* ]]; then ok; else
  bad "expected a fall back to start" "got: $DISPATCH"; fi

it "a file is not a URL, so the helper is never involved"
run_open "$WORK_DIR/file.txt"
assert_status 0
if [[ "$DISPATCH" != *powershell.exe* ]]; then ok; else
  bad "the helper ran for a file" "$DISPATCH"; fi

unstub_powershell

# --- the update check (#15) -----------------------------------------------

it "reads the tag from the releases/latest redirect"
stub_curl redirect "https://github.com/yannlugrin/winopen/releases/tag/9.9.9"
run_open --check-update
assert_status 0
assert_stdout "Latest version: 9.9.9"

it "says it is up to date when the tag matches"
version="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$OPEN")"
stub_curl redirect "https://github.com/yannlugrin/winopen/releases/tag/$version"
run_open --check-update
assert_status 0
assert_stdout "up to date"

it "refuses to read 'releases' as a tag when there are no releases"
stub_curl redirect "https://github.com/yannlugrin/winopen/releases"
run_open --check-update
assert_status 1
assert_stderr "no releases found"

it "reports a failure to reach GitHub"
stub_curl fail
run_open --check-update
assert_status 1
assert_stderr "failed to check for updates"
unstub_curl

# --- --update never escalates either (#16) ---------------------------------

it "updates in place when the file is writable"
cp "$OPEN" "$WORK_DIR/updatable"
sed -i 's/^VERSION=".*"$/VERSION="0.0.1"/' "$WORK_DIR/updatable"
chmod 755 "$WORK_DIR/updatable"
stub_curl update "9.9.9" "$OPEN"
STDOUT="$(env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
  bash "$WORK_DIR/updatable" --update 2>"$STUB_DIR/stderr")"
STATUS=$?
STDERR="$(cat "$STUB_DIR/stderr")"
assert_status 0
assert_stdout "Updated successfully"

it "prints one privileged command rather than escalating, when it cannot write"
if is_root; then skip "running as root, every path is writable"; else
  cp "$OPEN" "$WORK_DIR/locked"
  sed -i 's/^VERSION=".*"$/VERSION="0.0.1"/' "$WORK_DIR/locked"
  chmod 555 "$WORK_DIR/locked"
  stub_curl update "9.9.9" "$OPEN"
  STDOUT="$(env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
    bash "$WORK_DIR/locked" --update 2>"$STUB_DIR/stderr")"
  STATUS=$?
  STDERR="$(cat "$STUB_DIR/stderr")"
  if [[ "$STATUS" == 1 && "$STDERR" == *"sudo install -m 755"* ]]; then ok; else
    bad "expected the sudo command to be printed" "status=$STATUS stderr=$STDERR"; fi
fi

it "leaves the download in place, so the printed command has something to copy"
if is_root; then skip "running as root"; else
  file="$(sed -n 's/^Downloaded .* to \(.*\)\.$/\1/p' <<< "$STDERR")"
  if [[ -n "$file" && -s "$file" ]]; then ok; else
    bad "the file the command refers to is not there" "named: ${file:-<none>}"; fi
  rm -f "$file"
fi

it "refuses a download that is not the tool"
cp "$OPEN" "$WORK_DIR/target"
sed -i 's/^VERSION=".*"$/VERSION="0.0.1"/' "$WORK_DIR/target"
chmod 755 "$WORK_DIR/target"
printf '<!DOCTYPE html><html>404</html>\n' > "$WORK_DIR/notatool"
stub_curl update "9.9.9" "$WORK_DIR/notatool"
STDOUT="$(env -i HOME="$HOME" PATH="$STUB_DIR:/usr/bin:/bin" \
  bash "$WORK_DIR/target" --update 2>"$STUB_DIR/stderr")"
STATUS=$?
STDERR="$(cat "$STUB_DIR/stderr")"
assert_status 1
assert_stderr "does not look like winopen"
if grep -q '^VERSION="0.0.1"' "$WORK_DIR/target"; then ok; else
  bad "an error page replaced the tool"; fi
unstub_curl

summary
