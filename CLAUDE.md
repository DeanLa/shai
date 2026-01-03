# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ShAI** - AI-powered CLI tool that converts natural language to shell commands, with the generated command pre-loaded into the command line ready to execute.

## Architecture

- `shai.py` - Python script using OpenAI API to generate shell commands. Uses uv inline script metadata for dependency management.
- `shai.zsh` - Zsh shell integration providing:
  - `shai` function: `shai "your query"` → shows command, pre-populates buffer via `print -z`
  - `Ctrl+G` widget: type query directly, press Ctrl+G to transform into command

## Local Checks - Not installed
```bash
export SHAI_SCRIPT="$PWD/shai.py" && source ./shai.zsh && shai
```
## Installation

```bash
# Copy script to PATH
cp shai.py ~/.local/bin/
chmod +x ~/.local/bin/shai.py

# Add to .zshrc
echo 'source /path/to/shai.zsh' >> ~/.zshrc
```

## Usage

```bash
# Method 1: Function (command pre-loaded, press Enter to run)
shai "find large files over 100mb"

# Method 2: Widget (type query, press Ctrl+G)
find files modified today<Ctrl+G>
```

## Coding Preferences

### Line Length & Formatting
- Prefer single long lines over artificial line breaks

### Rich Library Patterns
- Use `Console(stderr=True, force_terminal=True)` when output may be captured/redirected
- For inline code backgrounds (not full-line), use `Syntax.highlight()` + `Text.stylize("on #color")` + `Padding`
- Store colors as constants at module level (e.g., `COLOR_INFO = "cyan"`)
- `#555555` works well as code background in both light and dark terminal modes

### Code Organization
- Extract semantic helper functions (e.g., `print_info()`, `print_warning()`, `print_error()`)
- Keep presentation logic separate from business logic
- Use `test_rich.py` or similar scratch files to experiment with formatting before integrating
- Organize code into sections with comment headers: `# === Constants ===`, `# === Models ===`, `# === Output ===`, `# === Context ===`, `# === API ===`, `# === CLI ===`, `# === Main ===`
- Extract exit codes as constants (e.g., `EXIT_SUCCESS`, `EXIT_ERROR`, `EXIT_DESTRUCTIVE`)
