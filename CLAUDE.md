# winopen

## What this is

An `open` command for WSL: it opens files, directories and URLs from a WSL
shell in the Windows applications that own them. **The installed binary is
always `open`,** whatever the project is called.

**It is an `xdg-open` replacement first.** That is the pitch and the reason the
project exists: `wslu`/`wslview` is archived upstream and gone from the Ubuntu
26.04 repositories, and every other WSL opener is years stale. The gap is
maintenance, not features, so the tests and the release machinery are part of
the value rather than overhead — and a fifth abandoned WSL opener would leave
the landscape worse than none. Anything that makes the tool harder to maintain
needs a reason.

macOS `open(1)` is where the richer command set comes from — reveal, wait,
choose the application, edit, stdin — and it is the reference for flag names
and semantics. It is **not** the positioning. Nothing written here — README,
`--help`, commit messages, issue comments — reads as "for people coming from a
Mac"; it reads as "the tool for opening things from WSL". No "mac" in names,
identifiers or filenames: it is a trademark. Naming macOS `open(1)` when
documenting parity is fine and expected.

The one thing no alternative does: a URL's tab lands on the virtual desktop in
view. `install.sh` ships the helper by default, and it stays **optional at run
time** — without it, or without `powershell.exe`, `open` hands the URL to
Windows like every other tool.

## Git, and anything outward-facing

**Do not stage or commit anything unless explicitly asked. No `git add`.** The
maintainer curates their own commits. When asked for a message, write it and
let them run it.

Message style, from the history: imperative subject; a body explaining the
reasoning rather than the diff; `BREAKING:` called out in the body; `Closes #N`
at the end; the `Co-Authored-By` trailer on commits Claude wrote, as in the
history. Merges into `main` are fast-forward or squash — no merge commits. A
`pre-push` hook (`just hooks`) runs `just check` before anything leaves the
machine.

**Confirm before** pushing, tagging, publishing a release, or editing
repository settings. Commenting on issues is expected and welcome.

## Layout

| path | what it is |
|---|---|
| `open` | the tool, one Bash script; `VERSION` is a constant near the top |
| `libexec/open-url.ps1` | the desktop helper; installed beside the tool, off `PATH` |
| `install.sh` | `curl \| bash` installer: release tarball checked against `SHA256SUMS`, `~/.local` by default; `PREFIX`, `VERSION` and `WITHOUT_DESKTOP` read from the environment on the right of the pipe |
| `justfile` | every task: `install`, `check`, `test`, `lint`, `test-windows`, `dist`, `hooks`, `check-version` |
| `tests/` | see Testing |
| `.github/workflows/` | `ci.yml` on push, `release.yml` on a tag |

`VERSION` must match the release tag — `just check-version` asserts it, and the
release workflow fails without it.

## Conventions

- Bash, `#!/usr/bin/env bash`, `set -euo pipefail`.
- **Comments explain *why*, not *what*.** Match the prose style already in
  `open` and `install.sh`: a short paragraph on the reason a thing is done that
  way, never a restatement of the line below it. If a comment would only
  paraphrase the code, drop it.
- **Dependency-free** beyond `wslpath` and coreutils; `curl` for the update
  paths only. PowerShell reaches what `cmd.exe` cannot and stays **optional**:
  without it the desktop handling falls back silently (by design), `-t` falls
  back to `notepad.exe`, and `-n` opens normally and says so.
- **Nothing runs `sudo`** — not `open`, not `install.sh`. A path that needs a
  destination it cannot write prints the exact privileged commands and stops;
  under `sudo` the destination is simply writable and the same code proceeds.
  `sudo` appears in the code only inside messages.
- `just` is the task runner. Installing from source does not require it.

### `set -euo pipefail` has bitten this codebase repeatedly

All of these shipped and had to be fixed:

- A bare `x="$(cmd)"` assignment ends the run when `cmd` fails. Use
  `|| x=""` when failure is expected.
- A trap's last command becomes the script's exit status.
- `explorer.exe` returns 1 on success, so its status must be discarded.
- A script-level array appended to inside a per-target function leaks across
  targets.

`just lint` runs shellcheck, which catches most of this class. Run it.

## Testing

`just check` is what CI runs: lint and the anywhere suite, about a second.
Tests come in two halves because only one of them can be automated.

**`tests/cli.sh`, `tests/xdg.sh`, `tests/install.sh` run anywhere**, including
a Linux runner with no WSL. The tool reaches Windows only by spawning
`wslpath`, `cmd.exe`, `explorer.exe`, `powershell.exe` and `curl` **by name**,
so stubs first on a scrubbed `PATH` make every crossing observable. They assert
the exact command line built and the exit status returned. A change to what
crosses to Windows comes with an assertion here, and the binaries keep being
called by name — a hard-coded path defeats the stubs.

**`tests/windows.sh` needs a real WSL machine** and is run by hand before a
release (`just test-windows`). It opens real windows and leaves them, and it
checks desktop placement through `IVirtualDesktopManager` rather than by asking
a human — with a count of windows elsewhere, because on a single desktop
passing proves nothing.

The bug that got past a green suite and a green release was in `install.sh`,
on a prefix that did not exist yet: it asked for root to write a directory the
user owned, and no test could see it because every test created the prefix
first. Test the state a stranger's machine is in, not the state the test set
up.

### Verify against a real Windows; never assume

The recurring failure here is **silent success**. All of these are real:

- `cmd.exe /C start` returns 0 for a scheme nothing has registered.
- `explorer.exe` returns 1 when it worked.
- `ShellExecuteEx` reports success while opening nothing, if `lpParameters` is
  set for a document.
- `SW_SHOWNOACTIVATE` is a hint every application tested ignores — which is why
  `-g` is documented as unsupported rather than implemented.
- The `.txt` handler on Windows 11 is a Store app: `ftype` names nothing,
  `UserChoice` holds an AppX id with no command line, and launching the
  resolved `WindowsApps` path from WSL hangs for minutes.

Exit codes prove nothing on this boundary. Check the result: a window title, a
file on disk, the command line a stub received.

Two measurement traps, both of which produced wrong conclusions before being
caught:

- **`notepad.exe` launch latency swings between ~3s and ~45s** on identical
  calls, because system32's copy is a launcher stub for the Store app. Do not
  benchmark against it.
- **`Get-Process` from a WSL-spawned PowerShell does not reliably see windows.**
  A foreground launch that definitely opened one reported nothing. A miss there
  is not evidence of absence.

More generally: do not write code to handle a state until you have confirmed
that state occurs.

## Documentation

The README was reshaped on purpose. Keep its shape:

- **The first screen is fixed:** tagline, six examples, the two features with
  links, why it exists, the `winopen`/`open` naming. Then Install. Nothing else
  goes above the desktop section.
- **Order:** Install → the desktop feature → Usage → the shim → Updating →
  Parity → Status → Development. Pitch first, reference after, Parity as an
  appendix.
- **Reasons live next to the behaviour they explain,** one paragraph, in the
  section where a reader would ask "why does it do that?". There is no
  design-notes section; do not add one. Long-form arguments go in issues.
- **Say each thing once.** The flags table is the only list of flags, the
  env-var table the only list of variables; "exit code 4 is never returned" and
  "0 means handed over, not opened" are stated once each.
- **Do not overclaim.** Windows-side behaviour is verified on one machine —
  Ubuntu 26.04 under WSL2, Windows 11 build 26200 — and Status says so. Limits
  stay stated, not smoothed. Checksums are integrity against accident, not
  against a compromised source.
- **A flag change touches four places:** `--help` in `open`, the flags table,
  the Parity section, and the tests.
- Markdown only, no HTML. Sample outputs in the README are pasted from the real
  tool, not composed.

## The parity contract

macOS `open(1)` is the reference. A flag we share must mean what it means
there. Divergences are allowed, but they must be **deliberate and documented**
— never an accident of implementation. The register is the README: the flags
table marks extensions, and "Parity with macOS `open(1)`" lists what is not
supported and why, plus every knowing deviation. Adding or changing a flag
means asking what `open(1)` does with it, and updating the register if the
answer differs.

## Decisions worth not re-litigating

- **Bash stays** (#22). The tool runs on the Linux side of WSL, so no language
  can call Win32 directly — a rewrite would change everything except the part
  that hurts. Win32 work lives beside the tool in `libexec/`, off `PATH`. A
  compiled helper is deferred, with triggers recorded on #22.
- **`open` never invokes `sudo`** (#16). It prints what it would do and stops.
  Under `sudo` the destination is simply writable and the same path proceeds.
- **A flag that contradicts the target is refused** — `-R` on a URL has no
  enclosing folder. **A guarantee that cannot be kept warns and proceeds** —
  `-n` for an application whose new-window flag is unknown still opens the
  target. Refusing there would cost the caller everything over a preference.
- **`-g` stays unsupported.** It was built, measured and removed:
  `SW_SHOWNOACTIVATE` is ignored by every application tested. A flag that
  silently does nothing is worse than no flag.
- **`-h` is help,** not macOS's header search. The one active contradiction of
  `open(1)`, and it is not going to change.
- **`--` stays** as a documented extension, though `open(1)` omits it. It is
  the usual Unix convention and the only way to open a file whose name begins
  with a dash.
- **The shim shadows, it does not replace.** `/usr/bin/xdg-open` stays dpkg's;
  the shim lives in `$PREFIX/bin` ahead of it on `PATH`, and it never falls
  back to what it shadows, because Windows gives it no failure to detect.
- **`-f` leaves its temp file.** `start` returns before the application has
  read it; deleting it would race the reader.

## Releasing

The maintainer tags and publishes; prepare, do not push. Before a tag:
`VERSION` in `open` matches it (`just check-version`), `just check` is green,
`just test-windows` has been run by hand on the real machine, and the README's
version numbers and sample outputs are current. The workflow then ships a
tarball and `SHA256SUMS`.