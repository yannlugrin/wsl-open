# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

- **`-e` and `-t` are no longer the same flag.** Matching macOS `open(1)`, where
  `-e` names one application and `-t` asks the system which one handles text:
  `-e` is now always `notepad.exe`, and only `-t` honours `$WINOPEN_EDITOR`.
  Scripts relying on `-e` picking up `$WINOPEN_EDITOR` should use `-t`.

  `-t` should ask Windows what it has registered for `.txt`. It does not yet:
  on Windows 11 that is a Store app, and reaching it needs `ShellExecuteEx`
  with `SEE_MASK_CLASSNAME`, which lands with the PowerShell work in #10. Until
  then `-t` without `$WINOPEN_EDITOR` falls back to `notepad.exe`.

### Fixed

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
