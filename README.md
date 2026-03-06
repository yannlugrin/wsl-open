# open

A macOS-like `open` command for WSL (Windows Subsystem for Linux).

Opens files, directories, and URLs from WSL using the appropriate Windows application — just like `open` works on macOS.

- Repository: <https://github.com/yannlugrin/wsl-open>

## Install

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/yannlugrin/wsl-open/main/install.sh | bash
```

Install a specific version:

```bash
VERSION=1.0.0 curl -fsSL https://raw.githubusercontent.com/yannlugrin/wsl-open/main/install.sh | bash
```

Change install prefix (default: `/usr/local`):

```bash
PREFIX=~/.local curl -fsSL https://raw.githubusercontent.com/yannlugrin/wsl-open/main/install.sh | bash
```

### From source

```bash
git clone https://github.com/yannlugrin/wsl-open.git
cd wsl-open
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
| `-h`, `--help` | Show help |
| `-V`, `--version` | Show version |
| `--check-update` | Check if a newer version is available |
| `--update` | Update to the latest version |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `WSL_OPEN_EDITOR` | Override the default text editor (default: `notepad.exe`) |

## Requirements

- WSL (Windows Subsystem for Linux)
- `wslpath` (built into WSL)

## License

MIT
