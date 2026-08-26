# winopen -- an `open` command for WSL

# Pinned so CI and a developer's machine agree: different shellcheck versions
# report different things, and a finding that only appears in CI is worse than
# no finding at all.
shellcheck_version := "0.10.0"

# Override as an argument -- `just prefix=~/.local install` -- rather than
# through the environment. sudo resets the environment by default, so
# `sudo PREFIX=/opt just install` can quietly install somewhere else entirely;
# an argument always survives. PREFIX is still read for anyone who is not using
# sudo and expects it.
prefix := env("PREFIX", "/usr/local")

# List the recipes
default:
    @just --list

# Everything CI runs
check: lint test

# Syntax and shellcheck
lint:
    @bash -n open
    @bash -n install.sh
    @for f in tests/*.sh; do bash -n "$f"; done
    @echo "  syntax ok"
    @if command -v shellcheck >/dev/null 2>&1; then \
        shellcheck --severity=warning open install.sh tests/*.sh && echo "  shellcheck ok"; \
    else \
        echo "  shellcheck not installed, skipped -- apt/dnf/brew install shellcheck,"; \
        echo "  or a static binary from https://github.com/koalaman/shellcheck/releases"; \
    fi

# The shellcheck version CI pins, so the workflow has one place to read it from
shellcheck-version:
    @echo "{{shellcheck_version}}"

# Run `just check` before every push (bypass once with `git push --no-verify`)
hooks:
    git config core.hooksPath .githooks
    @echo "  pre-push hook enabled"

# Stop running the hooks
unhooks:
    git config --unset core.hooksPath
    @echo "  hooks disabled"

# The suite that runs anywhere, Windows stubbed out
test:
    @bash tests/cli.sh
    @bash tests/xdg.sh
    @bash tests/install.sh

# The half CI cannot have: needs a real WSL, and opens windows
test-windows:
    @bash tests/windows.sh

# Install the tool. Override with `just prefix=~/.local install`, and leave out
# the virtual-desktop helper with `just install --without-desktop`.
install flag="":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{flag}}" in
      ""|--without-desktop) ;;
      *) echo "unknown option: {{flag}}" >&2; exit 1 ;;
    esac

    install -d {{prefix}}/bin
    install -m 755 open {{prefix}}/bin/open

    # After the tool, so a libexec this user cannot write costs the helper.
    if [[ "{{flag}}" == --without-desktop ]]; then
      rm -f {{prefix}}/libexec/winopen/open-url.ps1
      rmdir {{prefix}}/libexec/winopen {{prefix}}/libexec 2>/dev/null || :
      echo "  virtual-desktop helper skipped"
    elif ! { install -d {{prefix}}/libexec/winopen &&
             install -m 644 libexec/open-url.ps1 {{prefix}}/libexec/winopen/open-url.ps1
           } 2>/dev/null; then
      {
        echo "  {{prefix}}/libexec is not yours to write, so the virtual-desktop"
        echo "  helper was skipped. To add it:"
        echo "      sudo install -d {{prefix}}/libexec/winopen"
        echo "      sudo install -m 644 libexec/open-url.ps1 {{prefix}}/libexec/winopen/open-url.ps1"
      } >&2
    fi

# Remove the tool. Run `open --uninstall-xdg` first if you installed the shim.
uninstall:
    rm -f {{prefix}}/bin/open
    rm -f {{prefix}}/libexec/winopen/open-url.ps1
    -rmdir {{prefix}}/libexec/winopen

# Build the release tarball and its checksum into dist/
dist:
    #!/usr/bin/env bash
    set -euo pipefail
    version="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' open)"
    name="winopen-${version}"
    rm -rf dist
    mkdir -p "dist/${name}"
    # What someone needs to install and to know what they installed. install.sh
    # is not in here: it is fetched from the repository, not from the tarball.
    cp open README.md CHANGELOG.md LICENSE "dist/${name}/"
    mkdir -p "dist/${name}/libexec"
    cp libexec/open-url.ps1 "dist/${name}/libexec/"
    tar -czf "dist/${name}.tar.gz" -C dist "${name}"
    rm -rf "dist/${name}"
    ( cd dist && sha256sum "${name}.tar.gz" > SHA256SUMS )
    ls -l dist
    cat dist/SHA256SUMS

# Assert the VERSION constant matches a tag, for the release workflow
check-version tag:
    #!/usr/bin/env bash
    set -euo pipefail
    version="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' open)"
    if [[ "$version" != "{{tag}}" ]]; then
        echo "VERSION is $version but the tag is {{tag}}" >&2
        exit 1
    fi
    echo "  VERSION matches {{tag}}"
