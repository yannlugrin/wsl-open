# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **A test suite and CI.** `tests/cli.sh` and `tests/xdg.sh` stub `wslpath`,
  `cmd.exe` and `explorer.exe` and assert the command line the tool builds, so
  they run on any Linux machine including CI. `tests/windows.sh` covers what
  only a real WSL machine can answer — whether Windows actually opened
  anything — and is run by hand before a release.

- **A `pre-push` hook**, installed with `just hooks`, running the same checks
  CI does. CI pins the shellcheck version so a finding cannot appear there and
  nowhere else.

### Changed

- **The task runner is now [`just`](https://github.com/casey/just)**, was
  `make`. Installing from source does not require it — the README leads with
  the plain `install -m 755` command, since that is the whole install. Pass a
  prefix as an argument (`just prefix=~/.local install`) rather than through
  the environment: `sudo` resets the environment, so `sudo PREFIX=... just
  install` can quietly install to `/usr/local` instead.

### Added

- **A "Parity with macOS `open(1)`" section in the README**, listing what is
  supported, what is not and why, and every deliberate deviation — so parity
  claims are honest and a deliberate omission is not mistaken for a bug.

- **`-n`**, matching macOS `open(1)`: open a new instance rather than letting a
  running one take the target. Windows has no general switch for this, so it
  uses the application's own flag and knows the common browsers. For anything
  else the target is still opened, with a message saying the guarantee was not
  available — many applications start a fresh window regardless, so refusing
  would cost the whole operation over a preference. With no `-a` the default
  application is resolved with `AssocQueryString`, which needs `powershell.exe`.

- **`--args`**, matching macOS `open(1)`: everything after it is passed to the
  launched application instead of being opened.

- **`--install-xdg` / `--uninstall-xdg`**: register winopen as the system
  `xdg-open`, so links opened by other programs route through it rather than
  only what you type yourself. The shim is a symlink that shadows any packaged
  `/usr/bin/xdg-open` without touching it, and honours `xdg-open`'s own
  contract — one target, and its documented exit codes — rather than `open`'s.
  Installing winopen does not install the shim; it is a separate, reversible
  step.
- **`WINOPEN_XDG=0`** bypasses the shim for one command, handing the target to
  the `xdg-open` it shadows. The shim never falls back on its own: Windows
  reports success unconditionally, so there is no failure to detect.
- **`-u <url>`**, matching macOS `open(1)`: open a URL with whatever application
  claims its scheme, even when a file of that name exists.

### Changed

- **`open -a <app>` with no file now launches the application**, with no
  document, as macOS `open(1)` does. It used to be rejected as "no target
  specified".
- **A bare `open` prints its usage** to stderr and exits 1, rather than a
  one-line error. It still does not default to the current directory: `open .`
  is the documented idiom. `-h` is unchanged — usage on stdout, exit 0.

- **`-e` and `-t` are no longer the same flag.** Matching macOS `open(1)`, where
  `-e` names one application and `-t` asks the system which one handles text:
  `-e` is now always `notepad.exe`, and only `-t` honours `$WINOPEN_EDITOR`.
  Scripts relying on `-e` picking up `$WINOPEN_EDITOR` should use `-t`.

  With `$WINOPEN_EDITOR` unset, `-t` now asks Windows what it has registered for
  `.txt` and opens the file with that, whatever the file's own extension is. It
  needs `powershell.exe` to ask, and falls back to `notepad.exe` without it.

### Fixed

- **Every modifier flag was silently ignored for URLs.** The URL test was the
  first branch of the dispatch chain and answered the whole question, so
  `open -a chrome.exe https://example.com` did not use Chrome and `-W` did
  nothing. Addressing the target and choosing what opens it are now separate
  decisions. `-R`, `-D`, `-e` and `-t` need a file and now say so instead of
  vanishing.
- **`-e` and `-t` waited for the editor to exit, and `-W` did nothing for
  them.** They launched the editor in the foreground rather than through
  `start` — 5s with and without `-W` against an editor that sleeps 5s. Windows
  editors now go through `start` like everything else. A Linux editor is still
  run in place, where blocking is what a terminal editor wants.
- **`--` never worked for the one thing it exists for.** It stopped our own
  parser reading `-weird-name.txt` as flags, and then `wslpath` and `dirname`
  read it as *their* flags and failed. `open -- -weird-name.txt` now opens the
  file, as do `-R`, `-D` and a dash-named directory.
- **`-f` opened the wrong application, and deleted the temp file before it
  could be read.** The temp file had no extension, so Windows had no
  association for it, and the `EXIT` trap removed it while `start` was still
  handing it over — the file was reliably gone a second later, so the README's
  own `echo "hello" | open -f` example did not work. It now writes a `.txt`
  file, opens it in the text editor as `open(1)` specifies, and leaves it for
  the system to reap.
- **`open` exited 1 on every successful call.** The `EXIT` trap ended on a
  failed test whenever there was no temp file to clean up, and the trap's status
  becomes the script's, so `open file && ...` never ran.
- **Every URL scheme but `http`, `https`, `mailto` and `ftp` was rejected.**
  `vscode:`, `slack:`, `file:` and the rest were treated as file paths and died
  with "no such file or directory". Schemes are now recognised by shape, and
  Windows decides what it can open. A side effect: Windows-style paths such as
  `C:\Windows` now open instead of failing.
- **Only the first directory of a multi-target call was opened.** `explorer.exe`
  returns 1 whether it succeeded or not; under `set -euo pipefail` that ended the
  run after the first target.
- **`--update` ended with an error and an empty version.** Backslash-escaped
  quotes are literal inside `$( )`, so the final line ran a command whose name
  included the quotes. The update itself had already succeeded; only the report
  of it was broken.

### Changed

- **Renamed the project from `wsl-open` to `winopen`.** The old name collided
  with an unrelated project of the same name. The GitHub repository redirects,
  so existing clones and install commands keep working. The installed command
  is still `open`.
- **Breaking:** the editor override is now `WINOPEN_EDITOR`, was
  `WSL_OPEN_EDITOR`.

## [1.0.1] - 2026-03-06

### Added

- Install script for quick setup without cloning (`curl | bash`)
- `--check-update` flag to check if a newer version is available
- `--update` flag to self-update to the latest version

## [1.0.0] - 2026-03-06

### Added

- Open files, directories, and URLs from WSL using Windows applications
- `-a <app>` flag to open with a specific Windows application
- `-D` flag to open the enclosing folder in Explorer
- `-R` flag to reveal file in Explorer
- `-e` / `-t` flag to open in text editor (notepad.exe or `$WSL_OPEN_EDITOR`)
- `-W` flag to wait for the application to exit
- `-f` flag to read from stdin into a temp file
- Support for multiple targets (`open file1 file2 file3`)
- Makefile with `install` and `uninstall` targets

[Unreleased]: https://github.com/yannlugrin/winopen/compare/1.0.1...HEAD
[1.0.1]: https://github.com/yannlugrin/winopen/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/yannlugrin/winopen/releases/tag/1.0.0
