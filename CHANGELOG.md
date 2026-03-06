# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Install script for quick setup without cloning (`curl | bash`)

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

[Unreleased]: https://github.com/yannlugrin/wsl-open/compare/1.0.0...HEAD
[1.0.0]: https://github.com/yannlugrin/wsl-open/releases/tag/1.0.0
