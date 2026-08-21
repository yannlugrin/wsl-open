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
sudo make install
```

To uninstall:

```bash
sudo make uninstall
```

To install to a custom prefix (no sudo needed):

```bash
make install PREFIX=~/.local
```

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
| `-t` | Open in the default text editor (`$WINOPEN_EDITOR`, else `notepad.exe`) |
| `-W` | Wait for the application to exit before returning |
| `-f` | Read stdin into a temp file, then open it in the text editor (as `-t`) |
| `-h`, `--help` | Show help |
| `-V`, `--version` | Show version |
| `--check-update` | Check if a newer version is available |
| `--update` | Update to the latest version |
| `--install-xdg` | Install an `xdg-open` shim so other programs route through winopen |
| `--uninstall-xdg` | Remove the shim and restore any backup |

### URLs

Any scheme Windows has registered is handed to it as-is — `https:`, `mailto:`,
`vscode:`, `ms-settings:`, `file:`, whatever else is installed. There is no
allowlist.

An argument that looks like a URL but names an existing file is treated as the
file. `-u` says the opposite: open it as a URL regardless.

Windows reports success for a scheme nothing has registered, so `open` cannot
tell you when a URL had nowhere to go.

### Reading from stdin

`-f` writes standard input to a temporary `.txt` file and opens it in the text
editor, the same one `-t` resolves.

The temporary file is **not** deleted. `start` returns as soon as Windows has
been handed the file, long before the application has read it, so deleting it
would race whatever is opening it. It is left in `/tmp` for the system to reap.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `WINOPEN_EDITOR` | The editor `-t` uses (default: `notepad.exe`). `-e` ignores it. |
| `WINOPEN_XDG` | Set to `0` to bypass the `xdg-open` shim for one command |

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

`/usr/local/bin` is not normally yours to write, so this needs `sudo`. Before
asking for your password it tells you why, and names the exact commands root
will run:

```
/usr/local/bin is not writable by you, so this needs root.
sudo will run:
    ln -s /usr/local/bin/open /usr/local/bin/xdg-open
```

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

## Requirements

- WSL (Windows Subsystem for Linux)
- `wslpath` (built into WSL)

## License

MIT
