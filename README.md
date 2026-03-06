# open

A macOS-like `open` command for WSL (Windows Subsystem for Linux).

Opens files, directories, and URLs from WSL using the appropriate Windows application — just like `open` works on macOS.

- Repository: <https://github.com/yannlugrin/wsl-open>

## Install

```bash
make install
```

This installs the `open` script to `/usr/local/bin/open`.

To uninstall:

```bash
make uninstall
```

## Usage

```
open [flags] [target ...]
```

### Examples

```bash
open https://example.com          # Open URL in default browser
open .                            # Open current directory in Explorer
open ~/Documents/report.pdf       # Open file with default Windows app
open -D ~/Documents/report.pdf    # Open enclosing folder in Explorer
open -R ~/Documents/report.pdf    # Reveal file in Explorer
open -e ~/.bashrc                 # Open in text editor (notepad.exe)
open -a notepad.exe ~/.bashrc     # Open with specific Windows app
open -W somefile.txt              # Wait for the app to close
echo "hello" | open -f            # Read from stdin, open as temp file
open file1.txt file2.txt          # Open multiple files
```

### Flags

| Flag | Description |
|------|-------------|
| (none) | Open target with default Windows app |
| `-a <app>` | Open with a specific Windows application |
| `-D` | Open the enclosing folder in Explorer |
| `-R` | Reveal in Explorer (highlight the file) |
| `-e` | Open in text editor (notepad.exe by default) |
| `-t` | Alias for `-e` |
| `-W` | Wait for the application to exit before returning |
| `-f` | Read from stdin, write to a temp file, then open it |
| `-g` | Open in background (no-op on Windows; apps already detach) |
| `-h`, `--help` | Show help |
| `-V`, `--version` | Show version |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `WSL_OPEN_EDITOR` | Override the default text editor (default: `notepad.exe`) |

## Requirements

- WSL (Windows Subsystem for Linux)
- `wslpath` (built into WSL)

## License

MIT
