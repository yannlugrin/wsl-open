# winopen

`open` for WSL: hand it a file, a directory or a URL and get the Windows
application that claims it.

```bash
open report.pdf                  # the default Windows app
open .                           # Explorer, here
open https://example.com         # your browser
open -R notes.md                 # reveal in Explorer, highlighted
open -a chrome.exe --args --incognito
echo "scratch" | open -f         # stdin into the text editor
```

It does the job of `xdg-open` — and can [take its place](#registering-as-xdg-open),
so links opened by editors and CLI tools go through it too — with the command
set of macOS `open(1)`: reveal, wait, choose the application, the text editor,
stdin. And it does one thing no other WSL opener does:
[URLs open on the virtual desktop you are looking at](#urls-open-on-the-desktop-you-are-looking-at),
not in whichever browser window happened to be active last.

`wslview`, from wslu, is archived and no longer packaged in Ubuntu 26.04.
winopen began as a shell function written to replace it on a fresh install, and
its author uses it every day. The repository is `winopen`; the command it
installs is `open`.

## Install

Needs WSL: the tool works by running `wslpath`, `cmd.exe`, `explorer.exe` and
`powershell.exe` from the Linux side. Without `powershell.exe` three things
fall back: URLs go straight to Windows, `-t` uses `notepad.exe`, and `-n`
opens normally and says so. `--check-update` and `--update` need `curl`.

The install script fetches the release tarball, checks it against the
published `SHA256SUMS`, and installs `open` and the
[desktop helper](#urls-open-on-the-desktop-you-are-looking-at) into `~/.local`
— **no root, at any point**:

```bash
curl -fsSL https://raw.githubusercontent.com/yannlugrin/winopen/main/install.sh | bash
```

It never runs `sudo` for you; nothing in winopen does. Point it at a prefix you
do not own and it downloads, verifies, then prints the privileged commands and
stops.

Or by hand. It is two files — the script, and a PowerShell helper it looks for
beside itself. Read them, then put them in place:

```bash
curl -fsSLO https://raw.githubusercontent.com/yannlugrin/winopen/main/open
curl -fsSLO https://raw.githubusercontent.com/yannlugrin/winopen/main/libexec/open-url.ps1
less open                                     # 800 lines; the helper is another 150
sudo install -m 755 open /usr/local/bin/open
sudo install -d /usr/local/libexec/winopen
sudo install -m 644 open-url.ps1 /usr/local/libexec/winopen/
```

The helper is optional: without it, `open` hands URLs straight to Windows, like
every other tool does. To remove either file, delete it. Both come from `main`,
the maintained branch; the script takes a checked release instead.

### Prefix and version

**Put assignments on the right of the pipe.** On the left they are set for
`curl`, which does not care, and the script never sees them:

```bash
curl -fsSL https://raw.githubusercontent.com/yannlugrin/winopen/main/install.sh | PREFIX=/usr/local bash    # yes
PREFIX=/usr/local curl -fsSL https://raw.githubusercontent.com/yannlugrin/winopen/main/install.sh | bash    # silently ignored
```

`VERSION=1.1.0` pins a release. `WITHOUT_DESKTOP=1` skips the helper.

Asked for `/usr/local`, the script finishes like this rather than escalating:

```
Downloaded and verified winopen 1.1.0.
/usr/local/bin is not yours to write, so the rest needs root:

    sudo install -d /usr/local/bin
    sudo install -m 755 /tmp/tmp.XXXX/winopen-1.1.0/open /usr/local/bin/open
    ...
```

`~/.local/bin` is on `PATH` for login shells on most distributions, but not
always for programs started by services. If you want `open` reachable from
everywhere, install to `/usr/local`.

### From source

With [`just`](https://github.com/casey/just), the project's task runner:

```bash
git clone https://github.com/yannlugrin/winopen.git
cd winopen
sudo just install        # and: sudo just uninstall
```

Pass a different prefix **as an argument**, not through the environment —
`sudo` resets the environment, so `sudo PREFIX=... just install` may quietly
install to `/usr/local` anyway:

```bash
just prefix=~/.local install      # no sudo needed
sudo just prefix=/opt install
```

If you installed the `xdg-open` shim, remove it with `open --uninstall-xdg`
before uninstalling the tool, while `open` is still there to do it.

## URLs open on the desktop you are looking at

Windows hands a URL to the browser that is already running, which opens it in
whichever of its windows was **last active** — on whatever virtual desktop that
window happens to be. So the tab lands somewhere you cannot see, or Windows
drags your view across to follow it.

winopen raises a browser window that is already on the desktop in view and
*then* hands over the URL, because a browser opens a URL in its last active
window and activating one is what makes it that. With no window here to raise,
it opens a new one, which Windows always places on the desktop in view.

Nothing needs doing — it is what `open https://example.com` does once the
helper is installed. It costs about 300ms over handing the URL straight to
Windows.

How it decides: it asks Windows which browser owns the scheme with
`AssocQueryString`, not by reading the `UserChoice` registry key, which can name
a browser the shell does not actually launch. It lists that browser's visible,
titled top-level windows and asks the documented `IVirtualDesktopManager`
interface which of them are on the current desktop. A query it cannot answer
counts as "no": doubt opens a new window rather than risking another desktop.

It steps aside whenever you have already said what you want, or it cannot do
better:

- `-a`, `-n`, `-W` or `--args`: the URL goes to Windows as given.
- `WINOPEN_DESKTOP=0`: off for one command.
- No `powershell.exe`, or no helper installed: falls back silently.
- An unknown scheme, or a browser it has no window flag for: falls back
  silently. It knows Chrome, Edge, Brave, Vivaldi, Opera and Thorium
  (`--new-window`), and Firefox, LibreWolf and Waterfox (`-new-window`).

**Known limitation:** if the topmost browser window on your desktop is a PWA
or app window rather than a tabbed one, the browser may still route the tab to
a tabbed window elsewhere.

## Usage

```
open [flags] [target ...]
```

```bash
open https://example.com          # URL, in the default browser
open vscode://file/tmp/x          # any scheme Windows has registered
open -u mailto:me@example.com     # force URL, even if a file of that name exists
open .                            # this directory, in Explorer
open ~/Documents/report.pdf       # the default Windows app for the type
open -R ~/Documents/report.pdf    # reveal in Explorer, highlighted
open -D ~/Documents/report.pdf    # the enclosing folder, in Explorer
open -e ~/.bashrc                 # notepad.exe
open -t ~/.bashrc                 # the default text editor
open -a notepad.exe ~/.bashrc     # a specific Windows application
open -a notepad.exe               # ...or just launch it
open -W somefile.txt              # wait for the application to exit
open -n https://example.com       # a new browser window
echo "hello" | open -f            # stdin, into the text editor
open file1.txt file2.txt          # several targets
open -a chrome.exe --args --incognito
open -- -weird-name.txt           # a target whose name starts with a dash
```

### Flags

| Flag | Meaning |
|------|---------|
| `-a <app>` | Open with a specific Windows application |
| `-u <url>` | Open a URL with whatever claims its scheme, even if a file of that name exists |
| `-R` | Reveal in Explorer, with the file highlighted |
| `-D` | Open the enclosing folder in Explorer *(extension)* |
| `-e` | Open in `notepad.exe` |
| `-t` | Open in the default text editor: `$WINOPEN_EDITOR`, else whatever Windows registered for `.txt` |
| `-W` | Wait for the application to exit before returning |
| `-n` | Open a new instance rather than reusing a running one — [partial](#new-instances) |
| `-f` | Read stdin into a temp file and open it as `-t` |
| `--args <...>` | Pass everything that follows to the launched application |
| `--` | Everything that follows is a target *(extension)* |
| `-h`, `--help` | Help |
| `-V`, `--version` | Version *(extension)* |
| `--check-update`, `--update` | See [Updating](#updating) *(extension)* |
| `--install-xdg`, `--uninstall-xdg` | See [Registering as xdg-open](#registering-as-xdg-open) *(extension)* |

Flags come from macOS `open(1)` unless marked as an extension. The
[parity section](#parity-with-macos-open1) lists what is missing and why.

### Environment variables

| Variable | Effect |
|----------|--------|
| `WINOPEN_EDITOR` | The editor `-t` (and so `-f`) uses. Unset, `-t` asks Windows what handles `.txt`. `-e` ignores it |
| `WINOPEN_DESKTOP` | `0` hands URLs straight to Windows, ignoring virtual desktops |
| `WINOPEN_XDG` | `0` bypasses the `xdg-open` shim for one command |

### Text editors

`-e` always uses `notepad.exe`. `-t` uses `$WINOPEN_EDITOR` if set, and
otherwise opens the file with whatever Windows has registered for `.txt` —
whatever the file's own extension happens to be. That last part asks Windows
directly, via `ShellExecuteEx` with `SEE_MASK_CLASSNAME`, because there is no
cheaper way to reach it: on Windows 11 the `.txt` handler is a Store app that
`ftype` cannot name and whose path is unreadable from WSL. It needs
`powershell.exe`; without it, `-t` falls back to `notepad.exe`.

### New instances

`-n` forces a new window rather than letting a running instance take the
target. Windows has no general "new instance" switch — `ShellExecute` asks the
application, and most single-instance themselves, which is exactly why a
browser handed a URL puts the tab in whichever window was last active. What
works is the application's own flag, so `-n` only knows the browsers it has a
flag for: Chrome, Edge, Brave, Vivaldi, Opera and Thorium take `--new-window`;
Firefox, LibreWolf and Waterfox take `-new-window`.

For anything else the target is still opened, with a note that the guarantee
was not available:

```
$ open -n -a notepad.exe file.txt
open: -n: no new-instance flag known for notepad.exe; opening normally, which may reuse a running window
```

It opens anyway on purpose. Whether an unknown application reuses a window or
starts a fresh one is its own business, and many start a fresh one regardless —
refusing would cost you the whole operation over a preference that may well
have been satisfied. A flag that *contradicts* the target is different: `-R` on
a URL is refused outright, because there is no enclosing folder to reveal.

Without `-a`, the application has to be resolved before it can be asked for a
new window, which needs `powershell.exe`. Without it, `-n` says so and opens
normally.

### `--args` and `--`

`--args` passes everything after it to the launched application rather than
opening it, as `open(1)` does. `--` is the opposite: everything after it is a
target, however it is spelled — the only way to open a file whose name begins
with a dash. Whichever of the two comes first claims the rest of the command
line.

### URLs

Any scheme Windows has registered is handed to it as-is — `https:`, `mailto:`,
`vscode:`, `ms-settings:`, `file:`, whatever else is installed. There is no
allowlist. An argument that looks like a URL but names an existing file is
treated as the file; `-u` says the opposite.

`-a`, `-W` and `--args` apply to URLs as they do to files, so
`open -a chrome.exe https://example.com` really does use Chrome. `-R`, `-D`,
`-e` and `-t` need a file to point at and are rejected for a URL rather than
silently ignored.

Windows reports success for a scheme nothing has registered, so `open` cannot
tell you when a URL had nowhere to go: a `0` means the URL was handed over, not
that anything opened it.

### Reading from stdin

`-f` writes standard input to a temporary `.txt` file and opens it in the text
editor `-t` resolves. The file is **not** deleted: `start` returns as soon as
Windows has been handed it, long before the application has read it, so
deleting it would race whatever is opening it. It is left in `/tmp` for the
system to reap.

### No target

`open` with no arguments prints its usage to stderr and exits 1. It does not
default to the current directory — `open .` is the idiom, as with macOS and
`code`. `open -a <app>` with no file is not a mistake: it launches the
application with no document, as macOS does.

## Registering as xdg-open

By itself, `open` only helps when you type it. Links opened by other programs —
editors, CLI tools, anything calling `xdg-open` — go elsewhere. Installing the
shim routes those through winopen too:

```bash
open --install-xdg      # into $PREFIX/bin, default /usr/local/bin
open --uninstall-xdg    # remove it, restoring anything it replaced
```

Installing winopen does not install the shim. It is a separate, explicit step,
and a separately reversible one.

`/usr/local/bin` is not normally yours to write. As everywhere in winopen,
`open` will not become root for you — it says what it would do and leaves you
to run it:

```
/usr/local/bin is not writable by you, so this needs root.
It would run:
    ln -s /usr/local/bin/open /usr/local/bin/xdg-open

Nothing has been changed. Run it again as root:
    sudo open --install-xdg
```

Under `sudo` the directory simply is writable, so it goes ahead.

### It shadows, it does not replace

`xdg-utils` ships `/usr/bin/xdg-open`. `/usr/local/bin` comes first on `PATH`,
so the shim takes precedence while the packaged file is left untouched —
package upgrades do not fight it, and removing the shim hands control straight
back. Only a file already sitting at the shim's own path is ever moved, and
then it is backed up alongside and restored on uninstall.

`PREFIX=~/.local open --install-xdg` avoids `sudo` — but `~/.local/bin` is
typically only on `PATH` in interactive shells, so programs started by
services, or launched into WSL from Windows, will not see it. That is the case
the shim exists for.

### It never falls back

The shim always opens through Windows. It does not try Windows and fall back to
the `xdg-open` it shadows, because Windows gives it no failure to detect —
`start` reports success even for a scheme nothing has registered. To bypass it
deliberately, for one command or one program's environment:

```bash
WINOPEN_XDG=0 xdg-open ~/notes.md    # the shadowed xdg-open instead
```

### Exit codes

The shim follows `xdg-open`'s contract rather than `open`'s: exactly one
target, and these codes.

| Code | Meaning |
|------|---------|
| 0 | Handed to Windows |
| 1 | Error in command line syntax |
| 2 | The file did not exist |
| 3 | `WINOPEN_XDG=0` and no other `xdg-open` to delegate to |

`xdg-open` also defines 4, "the action failed". winopen never returns it,
because Windows does not report whether the action succeeded.

### `$BROWSER`

`open` cannot set environment variables in your shell. To route `$BROWSER`
through winopen as well, add this yourself:

```bash
export BROWSER=/usr/local/bin/xdg-open
```

## Updating

`--check-update` asks GitHub what the latest release is. `--update` downloads
it, checks that what arrived is actually the tool — an error page or a captive
portal answers 200 with a body that would otherwise end up executable on your
`PATH` — and puts it in place.

If the installed `open` is not yours to write, `--update` does not ask for
root, and does not tell you to re-run the whole command as root either, which
would put the download under root too. It fetches and checks the new version as
you, then hands you the single privileged step:

```
Downloaded 1.1.0 to /tmp/winopen-update-a1b2c3.
/usr/local/bin/open is not writable by you, so the last step needs root:
    sudo install -m 755 /tmp/winopen-update-a1b2c3 /usr/local/bin/open
```

### What the checksum does and does not buy

The installer verifies the tarball against a `SHA256SUMS` published in the
same release. That protects against a truncated download or a mis-published
asset — integrity against accident. It does **not** protect against a
compromised source: whoever could replace the tarball could replace the
checksum beside it, and both arrive over the same connection from the same
host.

Where it pays off is letting you pin. A dotfiles repository can record a
version and its SHA and refuse anything else:

```bash
sha256sum -c <<< "8f423d...  winopen-1.1.0.tar.gz"
```

Real integrity is signing, which is a separate question and not answered here.

## Parity with macOS `open(1)`

macOS `open(1)` is the reference for flag names and semantics. Where winopen
diverges it is on purpose, and it is listed here.

### Not supported

| Flag | Why |
|------|-----|
| `-b <bundle id>` | Windows has no bundle identifiers |
| `-g` | Windows offers no way to do it. `ShellExecuteEx` with `SW_SHOWNOACTIVATE` is only a hint, and every application tested ignores it and takes the foreground anyway — verified against a Store app, a Win32 app, and a cold start, on Windows 11 build 26200. It was built, measured, and removed |
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

**`-n` is a partial guarantee.** macOS has an API for launching a new instance;
Windows does not. winopen passes the application's own new-window flag where
it knows one, and otherwise opens the target and says so rather than refusing —
see [New instances](#new-instances).

**`-e`, `-t`, `-R` and `-D` reject URLs.** They need a file to point at. macOS
is not explicit about this; ignoring the flag silently seemed worse than saying
so.

**An unopenable URL cannot be reported.** macOS `open` errors when nothing
claims a scheme. Windows reports success unconditionally.

### Extensions

`-D`, `--`, `-V`/`--version`, `--check-update`/`--update` and
`--install-xdg`/`--uninstall-xdg` have no `open(1)` counterpart, and are marked
as such in the [flags table](#flags). `-D` is not a macOS flag at all —
`open(1)` has `-R` but no `-D`. `--` is undocumented in `open(1)`, but it is
the usual Unix convention and the only way to open a file whose name begins
with a dash. The `xdg-open` shim follows `xdg-open`'s contract, not `open(1)`'s.

## Status

New and small: one maintainer, first substantial release, used daily.
Everything on the Windows side is verified on one machine — Ubuntu 26.04 under
WSL2, Windows 11 build 26200. Other builds, other browsers and other Windows
versions are untested, and the desktop handling and `-n` only know the nine
browsers listed above. Releases are checksummed, not signed.

If it breaks, the useful report has `open -V`, the Windows build, the browser,
the command line, and what happened versus what `open` claimed. Silent
successes are the bugs this tool attracts.

## Development

The checks that must pass are the ones CI runs:

```bash
just            # list the recipes
just check      # what CI runs: lint and tests, about a second
just test       # the suite that runs anywhere
just lint       # bash -n and shellcheck
just hooks      # run `just check` before every push
```

`just hooks` installs a `pre-push` hook, so the checks run when work is about
to become public rather than on every work-in-progress commit. `git push
--no-verify` skips it once; `just unhooks` removes it.

Linting needs [shellcheck](https://github.com/koalaman/shellcheck) — your
package manager has it, or take a static binary from its releases page. Without
it `just lint` still runs the syntax checks and says what it skipped. CI pins
the version (`just shellcheck-version`), so a finding cannot appear there and
nowhere else.

### Tests come in two halves

Only one of them can be automated.

`tests/cli.sh`, `tests/xdg.sh` and `tests/install.sh` run **anywhere**,
including a Linux CI runner with no WSL at all. The tool reaches Windows only by
spawning `wslpath`, `cmd.exe`, `explorer.exe`, `powershell.exe` and `curl` by
name, so stubs for them first on a scrubbed `PATH` make every crossing
observable: the tests assert the exact command line the tool builds, and its
exit status. A change to what crosses to Windows comes with a test here.

`tests/windows.sh` needs a **real WSL machine** and is run by hand before a
release:

```bash
just test-windows
```

It carries the one check only a real desktop can make: that a URL's tab landed
on the desktop in view rather than on another one, and it tells you how many
windows were elsewhere — because with everything on one desktop, the tab could
not have gone wrong and passing proves nothing.

It exists because the interesting failures here are invisible from an exit
code. `cmd.exe /C start` returns 0 for a scheme nothing has registered,
`explorer.exe` returns 1 when it succeeded, and `ShellExecuteEx` reports
success while opening nothing at all. Only looking at the result catches those,
so that suite opens real windows and leaves them for you to check.

### Why Bash

The tool runs on the Linux side of WSL, so no language can call Win32 directly:
a rewrite in Go or Rust would still shell out to `powershell.exe`, and change
everything except the part that hurts. Meanwhile a readable script is worth
something for a tool that installs itself as the system `xdg-open` and writes
to `/usr/local/bin`. Win32 work lives beside the tool in `libexec/`, off your
`PATH`; a compiled helper waits until something needs one.

### Releases

The release workflow checks that the `VERSION` constant matches the pushed tag
before publishing, then ships a tarball and `SHA256SUMS`. `tests/windows.sh`
runs by hand first.

## License

MIT