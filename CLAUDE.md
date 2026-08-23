# winopen

## What this is

An `open` command for WSL: it opens files, directories and URLs from a WSL
shell in the Windows applications that own them.

**It is an `xdg-open` replacement first.** That is the pitch, and the reason the
project exists — `wslu`/`wslview` is archived upstream and gone from the Ubuntu
26.04 repositories, and every other WSL opener is years stale. The gap is
maintenance, not features, so the tests and the release machinery are part of
the value rather than overhead.

macOS `open(1)` is where the richer command set comes from — reveal, wait,
choose the application, edit, stdin — and it is the reference for flag names and
semantics. It is **not** the positioning. Nothing written here — README,
`--help`, commit messages, issue comments — should read as "for people coming
from a Mac"; it reads as "the tool for opening things from WSL". Avoid "mac" in
names, identifiers and filenames: it is a trademark. Referring to macOS
`open(1)` by name when documenting parity is fine and expected.

**The installed binary is always `open`,** whatever the project is called.

## The parity contract

macOS `open(1)` is the reference. A flag we share must mean what it means there.

Divergences are allowed, but they must be **deliberate and documented** — never
an accident of implementation. The README's "Parity with macOS `open(1)`"
section is the register: what is supported, what is not and why, and every place
winopen knowingly differs. Adding or changing a flag means asking what `open(1)`
does with it, and updating that section if the answer differs.

## Layout

| path | what it is |
|---|---|
| `open` | the whole tool, one Bash script |
| `libexec/open-url.ps1` | keeps a URL's tab on the virtual desktop in view |
| `install.sh` | `curl \| bash` installer |
| `justfile` | every task: `install`, `test`, `lint`, `dist`, `hooks` |
| `tests/` | see below |
| `.github/workflows/` | `ci.yml` on push, `release.yml` on a tag |

`VERSION` is a constant near the top of `open` and must match the release tag —
`just check-version` asserts it, and the release workflow fails without it.

## Conventions

- Bash, `#!/usr/bin/env bash`, `set -euo pipefail`.
- **Comments explain *why*, not *what*.** Match the prose-y style already in
  `open` and `install.sh`: a short paragraph explaining the reason a thing is
  done that way, not a restatement of the line below it. If a comment would only
  paraphrase the code, drop it.
- **Dependency-free** beyond `wslpath` and coreutils. `curl` for the update
  paths. PowerShell is used where `cmd.exe` cannot reach, and stays **optional**:
  every path that needs it degrades and says so when it is absent.
- `just` is the task runner. Installing from source does not require it — the
  README leads with a plain `install -m 755`, because that is the whole install.

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

`just check` is what CI runs. Tests come in two halves because only one of them
can be automated.

**`tests/cli.sh`, `tests/xdg.sh`, `tests/install.sh` run anywhere**, including a
Linux runner with no WSL. The tool reaches Windows only by spawning `wslpath`,
`cmd.exe`, `explorer.exe`, `powershell.exe` and `curl` **by name**, so stubs
first on a scrubbed `PATH` make every crossing observable. They assert the exact
command line built and the exit status returned.

**`tests/windows.sh` needs a real WSL machine** and is run by hand before a
release (`just test-windows`). It opens real windows and leaves them.

### Verify against a real Windows; never assume

The recurring failure here is **silent success**. All of these are real:

- `cmd.exe /C start` returns 0 for a scheme nothing has registered.
- `explorer.exe` returns 1 when it worked.
- `ShellExecuteEx` reports success while opening nothing, if `lpParameters` is
  set for a document.
- `SW_SHOWNOACTIVATE` is a hint every application tested ignores — which is why
  `-g` is documented as unsupported rather than implemented.

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

## Git

**Do not stage or commit anything unless explicitly asked. No `git add`.** The
maintainer curates their own commits. When asked for a message, write it and let
them run it.

Message style, from the history: imperative subject, a body explaining the
reasoning rather than the diff, `BREAKING:` called out in the body, `Closes #N`
at the end. Merges into `main` are fast-forward or squash — no merge commits.

A `pre-push` hook (`just hooks`) runs `just check` before anything leaves the
machine.

## Ask before anything outward-facing

Pushing, tagging, publishing releases, editing repository settings, anything on
npm — confirm first. Commenting on issues is expected and welcome.

## Decisions worth not re-litigating

- **Bash stays** (#22). The tool runs on the Linux side of WSL, so no language
  can call Win32 directly — a rewrite would change everything except the part
  that hurts. Win32 work lives beside the tool in `libexec/`, off `PATH`. A
  compiled helper is deferred, with triggers recorded on #22.
- **`--` stays** as a documented extension, though `open(1)` omits it. It is the
  usual Unix convention and the only way to open a file whose name begins with a
  dash.
- **`open` never invokes `sudo`** (#16). It prints what it would do and stops.
  Under `sudo` the destination is simply writable and the same path proceeds.
- **A flag that contradicts the target is refused** — `-R` on a URL has no
  enclosing folder. **A guarantee that cannot be kept warns and proceeds** —
  `-n` for an application whose new-window flag is unknown still opens the
  target. Refusing there would cost the caller everything over a preference.
