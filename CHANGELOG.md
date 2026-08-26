# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **`install.sh` never runs `sudo` either.** It defaults to `~/.local`, so the
  usual install needs no privilege at all; asked for a prefix you do not own, it
  downloads, verifies, and prints the commands to finish rather than
  escalating. Re-running it under `sudo` would be worse than either — piped
  from `curl`, that runs the download as root too. The previous default was
  `/usr/local`; pass `PREFIX=/usr/local` to keep it.

- **The virtual-desktop helper is installed with the tool**, into the same
  prefix, so it needs no privilege the tool does not and is inert without
  `powershell.exe`. `WITHOUT_DESKTOP=1` skips it, alongside the existing
  `PREFIX` and `VERSION`, and `just install --without-desktop` does the same
  from source. An install with no helper to place — asked to skip it, or from
  a release that carries none — takes away the one already there: the tool and
  the helper are one version. It goes in after the tool, so a `libexec` that is
  not yours to write costs the helper rather than the install, and the `sudo`
  lines that would finish the job are printed.

- **`--update` takes the release tarball and checks it** against the published
  `SHA256SUMS`, the way `install.sh` does, rather than fetching the tagged raw
  script and sniffing it. A tag can be moved with `git tag -f` and
  raw.githubusercontent.com follows it; a release asset cannot be replaced
  without it showing. There is no fallback for a release without assets,
  because an update only ever goes to the latest one. The virtual-desktop
  helper is refreshed out of that same tarball when one is installed beside the
  tool — the two are one release, and a stale helper fails silently rather
  than loudly — but one that is not there is never installed: that decision
  belongs to the install. `--update` now needs `tar` and `sha256sum` as well as
  `curl`.

- **`--install-xdg` puts the shim beside the tool** rather than defaulting to
  `/usr/local`, so it follows the install instead of asking for root over a
  prefix winopen was never installed into. `PREFIX` still decides, and every
  install now says what the choice costs: a program finds the shim only if its
  directory comes first on the `PATH` that program runs with, which is not the
  `PATH` you type at.

### Fixed

- **`--help` described the old `-t`.** It still read "`$WINOPEN_EDITOR`, else
  notepad.exe", while `-t` has been asking Windows what handles `.txt` and
  falling back to `notepad.exe` only without `powershell.exe`. The flags table
  in the README had it right; the two now agree.

- **The documented `curl | bash` examples set their variables on the wrong side
  of the pipe.** `PREFIX=~/.local curl ... | bash` applies the assignment to
  `curl`, which ignores it, so the script never saw it and quietly used the
  default. They now read `curl ... | PREFIX=~/.local bash`, as do
  `install.sh --help` and the hints the installer prints.

- **Installing to a prefix that does not exist yet asked for root.** The
  installer tested whether `$PREFIX/bin` was writable, which is false when it
  has not been created, so `PREFIX=~/somewhere-new` demanded a password to
  write somewhere the user already owned. It now asks about the nearest
  directory that exists.

## [1.1.0] - 2026-08-23

If you are upgrading, these change behaviour you may be relying on:

- `$WSL_OPEN_EDITOR` is now `$WINOPEN_EDITOR`.
- `-e` no longer reads that variable; it is always `notepad.exe`. Use `-t`,
  which is what macOS `open(1)` means by "the default text editor".
- `--update` no longer completes on its own when the destination needs root.
  It downloads, then prints the one privileged command and exits 1.
- `-R`, `-D`, `-e` and `-t` now fail on a URL instead of silently ignoring the
  flag and opening it anyway.
- Installing from source uses `just`, not `make` — or just copy `open` onto
  your `PATH`, which is the whole install.

### Added

- **URLs open on the virtual desktop you are looking at.** Windows gives a URL
  to the running browser, which opens it in whichever of its windows was last
  active — on whatever desktop that window sits, so the tab lands out of sight
  or drags your view across to follow it. winopen now raises a browser window
  already on the desktop in view before handing over the URL, and opens a new
  window when there is none. It steps aside for `-a`, `-n`, `-W` and `--args`,
  for `WINOPEN_DESKTOP=0`, and whenever it cannot do better than Windows would.

- **A test suite and CI.** `tests/cli.sh` and `tests/xdg.sh` stub `wslpath`,
  `cmd.exe` and `explorer.exe` and assert the command line the tool builds, so
  they run on any Linux machine including CI. `tests/windows.sh` covers what
  only a real WSL machine can answer — whether Windows actually opened
  anything — and is run by hand before a release.

- **A `pre-push` hook**, installed with `just hooks`, running the same checks
  CI does. CI pins the shellcheck version so a finding cannot appear there and
  nowhere else.
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

- **`open` never invokes `sudo`.** `--update`, `--install-xdg` and
  `--uninstall-xdg` used to escalate on your behalf. They now say what they
  would do and stop, leaving you to run it — and under `sudo` the destination
  simply is writable, so the same code path just works. `--update` goes
  further: it downloads and checks the new version as you, then prints the one
  privileged copy, so the network fetch never runs as root.
- **`--update` checks what it downloaded** is actually the tool before
  replacing anything, as `install.sh` now does.
- **Releases ship a tarball and `SHA256SUMS`**, built by `just dist` and
  published by a workflow that first runs the tests and asserts the `VERSION`
  constant matches the tag. `install.sh` prefers the assets and verifies the
  checksum, because a tag can be moved with `git tag -f` and
  `raw.githubusercontent.com` follows it. Releases published before the assets
  existed still install, from the tagged script, so older pins keep working.
- **The install is atomic.** `install.sh` piped `curl` straight at
  `$PREFIX/bin/open`, so a dropped connection left a truncated file on `PATH`
  under the name `open` — verified: it replaced a working install with 20 lines
  that would not run. It now downloads in full, checks that what arrived is
  actually the tool rather than an error page, and puts it in place with a
  rename, which either happens or does not.
- **The update check uses the `releases/latest` redirect** instead of the
  GitHub API. The unauthenticated API is limited to 60 requests an hour per IP,
  and the tag was being extracted from JSON with `grep`. A repository with no
  releases redirects to the releases page rather than to a tag, which is
  detected rather than reported as a release named "releases".

- **The task runner is now [`just`](https://github.com/casey/just)**, was
  `make`. Installing from source does not require it — the README leads with
  the plain `install -m 755` command, since that is the whole install. Pass a
  prefix as an argument (`just prefix=~/.local install`) rather than through
  the environment: `sudo` resets the environment, so `sudo PREFIX=... just
  install` can quietly install to `/usr/local` instead.
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
- **Renamed the project from `wsl-open` to `winopen`.** The old name collided
  with an unrelated project of the same name. The GitHub repository redirects,
  so existing clones and install commands keep working. The installed command
  is still `open`.
- **Breaking:** the editor override is now `WINOPEN_EDITOR`, was
  `WSL_OPEN_EDITOR`.

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

[Unreleased]: https://github.com/yannlugrin/winopen/compare/1.1.0...HEAD
[1.1.0]: https://github.com/yannlugrin/winopen/compare/1.0.1...1.1.0
[1.0.1]: https://github.com/yannlugrin/winopen/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/yannlugrin/winopen/releases/tag/1.0.0
