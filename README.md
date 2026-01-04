# shai

AI-powered CLI tool that converts natural language to shell commands, with the generated command pre-loaded into your command line ready to execute.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/DeanLa/shai/main/install.sh | bash
```

## Requirements

- `OPENAI_API_KEY` environment variable must be set

## Usage

```bash
shai "find all Python files modified in the last week"
```

The command is generated and loaded into your shell buffer - just press Enter to run it.

### Options

- `-q, --quiet` - Hide explanation, only output the command
- `--debug` - Show debug information
- `-a, --aliases` - Include your shell aliases as context

### Ctrl+G Widget

Type your query directly, then press `Ctrl+G` to transform it into a command:

```
find large files over 100mb<Ctrl+G>
```
