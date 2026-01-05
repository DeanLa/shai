# shai

**Sh**ell **AI** - ask for a shell command in plain English. It appears in your terminal, ready to run.

**Not a project tool.** Unlike Claude Code or Cursor, shai doesn't understand your codebase or manage context. It's the lightweight alternative - a replacement for opening ChatGPT and asking "how do I grep for X?" Just ask in your terminal and the command is ready to run.

```bash
shai "find all Python files modified in the last week"
```

The command is generated and loaded into your shell buffer - just press Enter to run it. No copy-paste. No typing. Just hit Enter.

<!-- VIDEO_PLACEHOLDER -->

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/DeanLa/shai/main/install.sh | bash
```

Requires `OPENAI_API_KEY` environment variable. Currently zsh only - bash and fish coming soon.

## Options

| Flag | Description |
|------|-------------|
| `-q, --quiet` | Hide explanation, only output the command |
| `-a, --aliases` | Include your shell aliases as context (so it can use them) |
| `--debug` | Show debug information |

## Advanced Features

### Session Memory

Enable session memory to give shai context about your recent commands and their exit codes. It learns from your terminal session.

```bash
# Add to .zshrc
export SHAI_SESSION_ENABLED=1
```

Now shai knows what you've been doing:
```bash
shai "why did that fail"      # References your last command
shai "do the same for .js"    # Knows what you just did
```

### Ctrl+G Widget

Type your query directly in the terminal, then press `Ctrl+G` to transform it into a command:

```
find large files over 100mb<Ctrl+G>
```

The query disappears and the generated command takes its place.

### Destructive Command Safety

shai won't let you accidentally nuke your system.

When it generates a potentially dangerous command (`rm`, `mv`, overwrites, etc.), it loads as a comment:

```bash
# rm -rf ./build
```

The command is right there, but you must deliberately remove the `#` to run it. One extra keystroke between you and disaster. You see exactly what's about to happen, and you make the conscious choice to execute it.

### Configuration

Add to your `.zshrc` to enable features:

```bash
export SHAI_SESSION_ENABLED=1           # Enable session memory
export SHAI_ALIASES_ENABLED=1           # Include your aliases as context
```

## Providers

### OpenAI (default)

```bash
export OPENAI_API_KEY="sk-..."
```

For custom endpoints (Azure, proxies, etc.):
```bash
export OPENAI_BASE_URL="https://your-endpoint.com/v1"
```

### More providers coming soon

Anthropic, Gemini, and local models are planned.
