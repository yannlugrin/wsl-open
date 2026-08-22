# winopen

Open files, directories and URLs from WSL in Windows applications.

A drop-in replacement for `xdg-open`, with the richer command set of macOS's `open`: reveal in Explorer, wait for the application to exit, choose which application to use, open in an editor, read from stdin.

The installed command is called `open`.

- Repository: <https://github.com/yannlugrin/winopen>

## Install

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/yannlugrin/winopen/main/install.sh | bash
```

Install a specific version:

```bash
VERSION=1.0.0 curl -fsSL https://raw.githubusercontent.com/yannlugrin/winopen/main/install.sh | bash
```

Change install prefix (default: `/usr/local`):

```bash
PREFIX=~/.local curl -fsSL https://raw.githubusercontent.com/yannlugrin/winopen/main/install.sh | bash
```

### From source

```bash
git clone https://github.com/yannlugrin/winopen.git
cd winopen
sudo install -m 755 open /usr/local/bin/open
```

That is the whole install — one file on your `PATH`. To remove it, delete it.

With [`just`](https://github.com/casey/just), which the project uses as its
task runner:

```bash
sudo just install
sudo just uninstall
```

To install somewhere else, pass the prefix **as an argument**, not through the
environment — `sudo` resets the environment, so `sudo PREFIX=... just install`
may quietly install to `/usr/local` anyway:

```bash
just prefix=~/.local install      # no sudo needed
sudo just prefix=/opt install
```

If you installed the `xdg-open` shim, remove it with `open --uninstall-xdg`
before uninstalling the tool, while `open` is still there to do it.

## Usage

```
open [flags] [target ...]
```

### Examples

```bash
open https://example.com          # Open URL in default browser
open vscode://file/tmp/x          # Any scheme Windows has registered
open -u mailto:me@example.com     # Force URL, even if a file of that name exists
open .                            # Open current directory in Explorer
open ~/Documents/report.pdf       # Open file with default Windows app
open -D ~/Documents/report.pdf    # Open enclosing folder in Explorer
open -R ~/Documents/report.pdf    # Reveal file in Explorer
open -e ~/.bashrc                 # Open in notepad.exe
open -t ~/.bashrc                 # Open in the default text editor
open -a notepad.exe ~/.bashrc     # Open with specific Windows app
open -W somefile.txt              # Wait for the app to close
echo "hello" | open -f            # Read stdin, open it in the text editor
open file1.txt file2.txt          # Open multiple files
open -a notepad.exe               # Launch an app with no document
open -a chrome.exe --args --incognito
open -- -weird-name.txt           # A target whose name starts with a dash
```

### Flags

| Flag | Description |
|------|-------------|
| (none) | Open target with default Windows app |
| `-a <app>` | Open with a specific Windows application |
| `-u <url>` | Open a URL with whatever application claims its scheme, even if a file of that name exists |
| `-D` | Open the enclosing folder in Explorer |
| `-R` | Reveal in Explorer (highlight the file) |
| `-e` | Open in `notepad.exe` |
| `-t` | Open in the default text editor (`$WINOPEN_EDITOR`, else whatever Windows registered for `.txt`) |
| `-W` | Wait for the application to exit before returning |
| `-n` | Open a new instance, rather than reusing a running one |
| `-f` | Read stdin into a temp file, then open it in the text editor (as `-t`) |
| `--args <...>` | Pass all remaining arguments to the launched application |
| `--` | Treat all remaining arguments as targets |
| `-h`, `--help` | Show help |
| `-V`, `--version` | Show version |
| `--check-update` | Check if a newer version is available |
| `--update` | Download the latest version and put it in place |
| `--install-xdg` | Install an `xdg-open` shim so other programs route through winopen |
| `--uninstall-xdg` | Remove the shim and restore any backup |

### Text editors

`-e` always uses `notepad.exe`. `-t` uses `$WINOPEN_EDITOR` if set, and
otherwise opens the file with whatever Windows has registered for `.txt` —
whatever the file's own extension happens to be.

That last part asks Windows directly, via `ShellExecuteEx` with
`SEE_MASK_CLASSNAME`, because there is no cheaper way to reach it: on Windows 11
the `.txt` handler is a Store app that `ftype` cannot name and whose path is
unreadable from WSL. It needs `powershell.exe`; without it, `-t` falls back to
`notepad.exe`.

### New instances

`-n` forces a new window rather than letting a running instance take the target:

```bash
open -n https://example.com          # a new browser window
open -n -a chrome.exe file.html
```

Windows has no general "new instance" switch — `ShellExecute` asks the
application, and most single-instance themselves, which is exactly why a
browser handed a URL puts the tab in whichever window was last active. What
works is the application's own flag, so `-n` only knows the browsers it has a
flag for: Chrome, Edge, Brave, Vivaldi, Opera and Thorium take `--new-window`,
Firefox, LibreWolf and Waterfox take `-new-window`.

For anything else, the file is still opened — it just says that the guarantee
was not available:

```
$ open -n -a notepad.exe file.txt
open: -n: no new-instance flag known for notepad.exe; opening normally, which may reuse a running window
```

It opens anyway on purpose. Whether an unknown application reuses a window or
starts a fresh one is its own business, and many start a fresh one regardless —
so refusing would cost you the whole operation over a preference that may well
have been satisfied. A flag that *contradicts* the target is different: `-R` on
a URL is refused outright, because there is no enclosing folder to reveal.

With no `-a`, the application has to be resolved before it can be asked for a
new window, which needs `powershell.exe`. Without it, `-n` says so and opens
normally.

### Passing arguments, and targets that look like flags

`--args` passes everything after it to the launched application rather than
opening it, as macOS `open(1)` does:

```bash
open -a chrome.exe --args --incognito
```

`--` is the opposite: everything after it is a target, however it is spelled.
This is an extension — `open(1)` does not document it — kept because it is the
usual Unix convention and the only way to open a file whose name begins with a
dash:

```bash
open -- -weird-name.txt
```

Whichever of the two comes first claims the rest of the command line.

### No target

`open` with no arguments prints its usage to stderr and exits 1. It does not
default to the current directory — `open .` is the documented idiom, the same
as macOS and `code`.

`open -a <app>` with no file is not a mistake: it launches the application with
no document, as macOS does.

### URLs

Any scheme Windows has registered is handed to it as-is — `https:`, `mailto:`,
`vscode:`, `ms-settings:`, `file:`, whatever else is installed. There is no
allowlist.

An argument that looks like a URL but names an existing file is treated as the
file. `-u` says the opposite: open it as a URL regardless.

Windows reports success for a scheme nothing has registered, so `open` cannot
tell you when a URL had nowhere to go.

`-a`, `-W` and `--args` apply to URLs as they do to files, so
`open -a chrome.exe https://example.com` really does use Chrome. `-R`, `-D`,
`-e` and `-t` need a file to point at and are rejected for a URL rather than
silently ignored.

### Reading from stdin

`-f` writes standard input to a temporary `.txt` file and opens it in the text
editor, the same one `-t` resolves.

The temporary file is **not** deleted. `start` returns as soon as Windows has
been handed the file, long before the application has read it, so deleting it
would race whatever is opening it. It is left in `/tmp` for the system to reap.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `WINOPEN_EDITOR` | The editor `-t` uses. Unset, `-t` asks Windows what handles `.txt`. `-e` ignores it. |
| `WINOPEN_XDG` | Set to `0` to bypass the `xdg-open` shim for one command |

## Updating

`--check-update` asks GitHub what the latest release is. `--update` downloads
it and puts it in place.

If the installed `open` is not yours to write, `--update` does **not** ask for
root, and does not tell you to re-run the whole command as root either — that
would put the download under root too. It fetches and checks the new version as
you, then hands you the single privileged step:

```
Downloaded 1.0.2 to /tmp/winopen-update-a1b2c3.
/usr/local/bin/open is not writable by you, so the last step needs root:
    sudo install -m 755 /tmp/winopen-update-a1b2c3 /usr/local/bin/open
```

Either way it checks that what arrived is actually the tool: an error page or a
captive portal answers 200 with a body that would otherwise end up executable
on your `PATH`.

## xdg-open integration

By itself, `open` only helps when you type it. Links opened by other programs —
editors, CLI tools, anything calling `xdg-open` — go elsewhere. Installing the
shim routes those through winopen too:

```bash
open --install-xdg      # into $PREFIX/bin, default /usr/local/bin
open --uninstall-xdg    # remove it, restoring anything it replaced
```

Installing winopen does not install the shim. It is a separate, explicit step,
and a separately reversible one.

`/usr/local/bin` is not normally yours to write. `open` will not become root
for you — it says what it would do and leaves you to run it:

```
/usr/local/bin is not writable by you, so this needs root.
It would run:
    ln -s /usr/local/bin/open /usr/local/bin/xdg-open

Nothing has been changed. Run it again as root:
    sudo open --install-xdg
```

Under `sudo` the directory simply is writable, so it goes ahead. Nothing in
`open` invokes `sudo` itself.

### It shadows, it does not replace

`xdg-utils` ships `/usr/bin/xdg-open`. `/usr/local/bin` comes first on `PATH`,
so the shim takes precedence while the packaged file is left untouched —
package upgrades do not fight it, and removing the shim hands control straight
back. Only a file already sitting at the shim's own path is ever moved, and
then it is backed up alongside and restored on uninstall.

Install to a prefix on your `PATH` with `PREFIX=~/.local open --install-xdg` if
you prefer no `sudo` — but note that `~/.local/bin` is typically only on `PATH`
in interactive shells, so programs started by services, or launched into WSL
from Windows, will not see it. That is the case the shim exists for.

### It never falls back

The shim always opens through Windows. It does not try Windows and fall back to
the `xdg-open` it shadows, because Windows gives it no failure to detect —
`start` reports success even for a scheme nothing has registered.

To bypass it deliberately, for one command or one program's environment:

```bash
WINOPEN_XDG=0 xdg-open ~/notes.md    # uses the shadowed xdg-open instead
```

### Exit codes

The shim follows `xdg-open`'s contract rather than `open`'s: exactly one target,
and these codes.

| Code | Meaning |
|------|---------|
| 0 | Handed to Windows |
| 1 | Error in command line syntax |
| 2 | The file did not exist |
| 3 | `WINOPEN_XDG=0` and no other `xdg-open` to delegate to |

`xdg-open` also defines 4, "the action failed". winopen never returns it,
because Windows does not report whether the action succeeded. A 0 means the
target was handed over, not that something opened.

### BROWSER

`open` cannot set environment variables in your shell. To route `$BROWSER`
through winopen as well, add this yourself:

```bash
export BROWSER=/usr/local/bin/xdg-open
```

## Parity with macOS `open(1)`

macOS `open(1)` is the reference for flag names and semantics. Where winopen
diverges it is on purpose, and it is listed here.

### Supported

| Flag | Notes |
|------|-------|
| `-a <app>` | |
| `-e` | `notepad.exe`, the TextEdit analogue |
| `-t` | `$WINOPEN_EDITOR`, else whatever Windows registered for `.txt` |
| `-f` | Writes a `.txt` temp file and opens it as `-t`. The file is left for the system to reap |
| `-W` | |
| `-R` | Reveals in Explorer rather than Finder |
| `-u <url>` | |
| `--args` | |
| `-n` | **Partial.** See below |

### Not supported

| Flag | Why |
|------|-----|
| `-b <bundle id>` | Windows has no bundle identifiers |
| `-g` | Windows offers no way to do it. `ShellExecuteEx` with `SW_SHOWNOACTIVATE` is only a hint, and every application tested ignores it and takes the foreground anyway — verified against a Store app, a Win32 app, and a cold start, on Windows 11 build 26200 |
| `-F` | No Windows equivalent of launching without restoring windows |
| `-j` | Launch hidden: no clean equivalent, little value |
| `-s <sdk>` | Xcode-specific, and paired with macOS's `-h` |
| `--env` | Niche |
| `--stdin`, `--stdout`, `--stderr` | Niche |
| `--arch` | Not applicable |

### Deliberate deviations

**`-h` means help here.** On macOS it searches header locations for a matching
header and opens it. This is the one place winopen actively contradicts
`open(1)`, and it is not going to change: `-h` is help everywhere else on this
platform.

**`-n` is a partial guarantee.** macOS has an API for launching a new instance.
Windows does not — `ShellExecute` asks the application, and most single-instance
themselves. winopen passes the application's own new-window flag and knows the
common browsers; for anything else it opens the target and says the guarantee
was not available, rather than refusing. See [New instances](#new-instances).

**`-e` and `-t` reject URLs**, as do `-R` and `-D`. They need a file to point
at. macOS is not explicit about this; ignoring the flag silently seemed worse
than saying so.

**An unopenable URL cannot be reported.** macOS `open` errors when nothing
claims a scheme. Windows reports success unconditionally, so a `0` from winopen
means the URL was handed over, not that anything opened it.

### Extensions with no macOS counterpart

| Flag | |
|------|--|
| `-D` | Open the enclosing folder in Explorer. Not a macOS flag at all — `open(1)` has `-R` but no `-D` |
| `--` | Everything after it is a target. `open(1)` does not document it, but it is the usual Unix convention and the only way to open a file whose name begins with a dash |
| `-V`, `--version` | |
| `--check-update`, `--update` | |
| `--install-xdg`, `--uninstall-xdg` | Registering as the system `xdg-open`. See [xdg-open integration](#xdg-open-integration) |

| Variable | |
|----------|--|
| `WINOPEN_EDITOR` | The editor `-t` uses |
| `WINOPEN_XDG` | Set to `0` to bypass the `xdg-open` shim |

The `xdg-open` shim has its own contract, which is not `open(1)`'s — one target,
and `xdg-open`'s documented exit codes. It never returns `4` ("the action
failed"), because Windows does not report whether the action succeeded.

## Requirements

- WSL (Windows Subsystem for Linux)
- `wslpath` (built into WSL)

## Development

```bash
just            # list the recipes
just check      # what CI runs: lint and tests, about a second
just test       # the suite that runs anywhere
just lint       # bash -n and shellcheck
just hooks      # run `just check` before every push
```

`just hooks` installs a `pre-push` hook, so the checks run when work is about
to become public rather than on every work-in-progress commit. `git push
--no-verify` skips it once, `just unhooks` removes it.

Linting needs [shellcheck](https://github.com/koalaman/shellcheck) — your
package manager has it, or take a static binary from its releases page. Without
it `just lint` still runs the syntax checks and says what it skipped. CI pins
the version (`just shellcheck-version`), so a finding cannot appear there and
nowhere else.

Tests come in two halves, because only one of them can be automated.

`tests/cli.sh`, `tests/xdg.sh` and `tests/install.sh` run **anywhere**, including a Linux CI runner
with no WSL at all. They put stubs for `wslpath`, `cmd.exe` and `explorer.exe`
first on a scrubbed `PATH` and assert the exact command line the tool builds,
along with its exit status.

`tests/windows.sh` needs a **real WSL machine** and is run by hand before a
release:

```bash
just test-windows
```

It exists because the interesting failures here are invisible from an exit
code. `cmd.exe /C start` returns 0 for a scheme nothing has registered,
`explorer.exe` returns 1 when it succeeded, and `ShellExecuteEx` reports
success while opening nothing at all. Only looking at the result catches those,
so that suite opens real windows and leaves them for you to check.

## License

MIT
