#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["openai>=1.0.0", "pydantic>=2.0.0", "rich>=13.0.0"]
# ///
"""
AI command generator - converts natural language to shell commands.
"""

import sys
import os
import argparse
import tomllib
from pathlib import Path
from openai import OpenAI
from pydantic import BaseModel, Field
from rich.console import Console
from rich.syntax import Syntax
from rich.padding import Padding
from rich.table import Table


# === Constants ===

COLOR_CODE_BG = "#555555"
COLOR_INFO = "cyan"
COLOR_WARNING = "yellow"
COLOR_ERROR = "red"

EXIT_SUCCESS = 0
EXIT_ERROR = 1
EXIT_DESTRUCTIVE = 2

# Config defaults
CONFIG_DIR = Path.home() / ".config" / "shai"
CONFIG_FILE = CONFIG_DIR / "config.toml"
DEFAULT_MODEL = "gpt-5.1-2025-11-13"
DEFAULT_QUIET = False

# Valid config keys for `shai set`
VALID_CONFIG_KEYS = {"model", "quiet", "session.enabled", "session.dir", "session.size", "aliases.enabled", "feedback.file"}

SYSTEM_PROMPT = """You are a shell command generator. Convert the user's natural language request into a single shell command.

Rules:
- Use OS-appropriate commands (). For macOS, prefer BSD variants or GNU tools with 'g' prefix if needed (e.g., gdate, gsed)
- Prefer user's aliases when applicable (e.g., if they have `alias ll='ls -la'`, use `ll` instead of `ls -la`)
- Prefer simple, safe commands
- If the request is ambiguous, make reasonable assumptions
- For destructive operations, include safety flags where appropriate (e.g., -i for interactive)
- Use the recent command history for context when the user refers to previous commands or actions
- Reference actual files and folders from the current directory listing when relevant
"""


# === Models ===

class Step(BaseModel):
    command: str = Field(description="The command or pipeline segment, e.g. 'grep foo' or 'sort -r'")
    explanation: str = Field(description="Brief explanation of what this step does")


class CommandResponse(BaseModel):
    command: str = Field(description="The shell command to execute. Must be a single valid command or pipeline.")
    explanation: str = Field(description="Brief explanation of what the command does, in plain English.")
    steps: list[Step] = Field(description="For multi-step commands (pipes, &&, ;), break down each step. Empty list for simple single commands.")
    is_destructive: bool = Field(description="True if the command could delete, overwrite, or irreversibly modify files or system state.")
    danger_reason: str = Field(description="If is_destructive is true, explain WHY this command is dangerous and what could go wrong. Empty string if not destructive.")


# === Output ===

err = Console(stderr=True, force_terminal=True)
_syntax = Syntax("", "bash", background_color="default")

def print_code(code: str, pad: int = 4):
    highlighted = _syntax.highlight(code)
    err.print(Padding(highlighted, (0, 0, 0, pad)))

def print_info(msg: str):
    err.print(f"[{COLOR_INFO}]{msg}[/{COLOR_INFO}]")

def print_warning(msg: str):
    err.print(f"[{COLOR_WARNING}]{msg}[/{COLOR_WARNING}]")

def print_error(msg: str):
    err.print(f"[{COLOR_ERROR}]{msg}[/{COLOR_ERROR}]")

def print_explanation(result: CommandResponse):
    print_info(f"💡 {result.explanation}")
    if result.steps:
        err.print()
        for i, step in enumerate(result.steps, 1):
            print_code(f"{i}. {step.command}\n   # {step.explanation}")

def print_danger_warning(result: CommandResponse):
    if result.is_destructive:
        print_warning(f"⚠️  {result.danger_reason}")

def output_command(command: str):
    print(command)


# === Config ===

def load_config() -> dict:
    """Load config from TOML file. Returns empty dict if file doesn't exist."""
    if not CONFIG_FILE.exists():
        return {}
    try:
        with open(CONFIG_FILE, "rb") as f:
            return tomllib.load(f)
    except Exception:
        return {}

def save_config(config: dict):
    """Save config to TOML file, creating directory if needed."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    lines = []
    # Write top-level keys first
    for key, value in config.items():
        if not isinstance(value, dict):
            lines.append(f"{key} = {_toml_value(value)}")
    # Write sections
    for key, value in config.items():
        if isinstance(value, dict):
            lines.append(f"\n[{key}]")
            for k, v in value.items():
                lines.append(f"{k} = {_toml_value(v)}")
    with open(CONFIG_FILE, "w") as f:
        f.write("\n".join(lines) + "\n")

def _toml_value(value) -> str:
    """Convert a Python value to TOML representation."""
    if isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, str):
        return f'"{value}"'
    elif isinstance(value, (int, float)):
        return str(value)
    return f'"{value}"'

def get_nested(config: dict, key: str, default=None):
    """Get a potentially nested config value like 'session.enabled'."""
    parts = key.split(".")
    value = config
    for part in parts:
        if isinstance(value, dict) and part in value:
            value = value[part]
        else:
            return default
    return value

def set_nested(config: dict, key: str, value):
    """Set a potentially nested config value like 'session.enabled'."""
    parts = key.split(".")
    target = config
    for part in parts[:-1]:
        if part not in target:
            target[part] = {}
        target = target[part]
    target[parts[-1]] = value

def unset_nested(config: dict, key: str) -> bool:
    """Remove a potentially nested config value. Returns True if key existed."""
    parts = key.split(".")
    target = config
    for part in parts[:-1]:
        if part not in target:
            return False
        target = target[part]
    if parts[-1] in target:
        del target[parts[-1]]
        return True
    return False

def resolve_config_value(key: str, cli_value, env_var: str | None, config: dict, default):
    """Resolve config value with priority: CLI > env > config file > default."""
    if cli_value is not None:
        return cli_value, "cli"
    if env_var and os.environ.get(env_var):
        return os.environ.get(env_var), "env"
    config_val = get_nested(config, key)
    if config_val is not None:
        return config_val, "config"
    return default, "default"


# === Context ===

def read_stdin_history() -> str:
    if sys.stdin.isatty():
        return ""
    return sys.stdin.read()

def read_session_file(path: str, limit: int = 10) -> str:
    if not path or not os.path.exists(path):
        return ""
    try:
        with open(path, "r") as f:
            content = f.read()
        entries = [e.strip() for e in content.split("---") if e.strip()]
        return "\n---\n".join(entries[-limit:])
    except Exception:
        return ""

def build_context_messages(history: str, session_context: str, dir_context: str) -> list[dict]:
    context_parts = []
    if dir_context.strip():
        context_parts.append(f"Current directory:\n{dir_context}")
    if session_context.strip():
        context_parts.append(f"Recent commands with exit codes:\n{session_context}")
    if history.strip():
        context_parts.append(f"Shell history:\n{history}")

    if not context_parts:
        return []

    return [
        {"role": "user", "content": "Here's context from my terminal session:\n\n" + "\n\n".join(context_parts)},
        {"role": "assistant", "content": "Got it, I'll use this context to understand your next request."},
    ]


# === API ===

def call_openai(query: str, history: str = "", session_context: str = "", dir_context: str = "", model: str = DEFAULT_MODEL, extra_prompt: str = "") -> CommandResponse:
    client = OpenAI()
    system_content = SYSTEM_PROMPT + extra_prompt
    messages = [{"role": "system", "content": system_content}]
    messages.extend(build_context_messages(history, session_context, dir_context))
    messages.append({"role": "user", "content": query})

    response = client.beta.chat.completions.parse(
        model=model,
        messages=messages,
        response_format=CommandResponse,
        temperature=0.1,
    )
    return response.choices[0].message.parsed


# === CLI ===

def require_api_key():
    if not os.environ.get("OPENAI_API_KEY"):
        print_error("OPENAI_API_KEY environment variable not set")
        sys.exit(EXIT_ERROR)

def parse_args():
    parser = argparse.ArgumentParser(
        description="AI-powered shell command generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
commands:
  config              Show current configuration (--sources for details)
  set <key> <value>   Set a configuration value
  unset <key>         Remove a configuration value
"""
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="Hide explanation of what the command does")
    parser.add_argument("--model", help="Model to use for generation")

    args, remaining = parser.parse_known_args()

    # Check for subcommands
    if remaining and remaining[0] == "config":
        args.command = "config"
        args.sources = "--sources" in remaining
        args.query = []
    elif remaining and remaining[0] == "set":
        args.command = "set"
        if len(remaining) >= 3:
            args.key = remaining[1]
            args.value = remaining[2]
        else:
            print_error("Usage: shai set <key> <value>")
            sys.exit(EXIT_ERROR)
        args.query = []
    elif remaining and remaining[0] == "unset":
        args.command = "unset"
        if len(remaining) >= 2:
            args.key = remaining[1]
        else:
            print_error("Usage: shai unset <key>")
            sys.exit(EXIT_ERROR)
        args.query = []
    else:
        args.command = None
        args.query = remaining

    return args

def get_exit_code(result: CommandResponse) -> int:
    return EXIT_DESTRUCTIVE if result.is_destructive else EXIT_SUCCESS

def parse_bool(value: str) -> bool:
    """Parse a string as a boolean value."""
    return value.lower() in ("true", "1", "yes", "on")

def cmd_config(args):
    """Handle 'shai config' command - display current configuration."""
    config = load_config()

    # Resolve all config values with their sources
    settings = [
        ("model", "SHAI_MODEL", DEFAULT_MODEL),
        ("quiet", "SHAI_QUIET", DEFAULT_QUIET),
        ("session.enabled", "SHAI_SESSION_ENABLED", False),
        ("session.dir", "SHAI_SESSION_DIR", "~/.shai_session"),
        ("session.size", "SHAI_SESSION_SIZE", 50),
        ("aliases.enabled", "SHAI_ALIASES_ENABLED", False),
        ("feedback.file", "SHAI_FEEDBACK_FILE", "~/.shai_feedback.jsonl"),
    ]

    table = Table(title="ShAI Configuration", show_header=True)
    table.add_column("Key", style="cyan")
    table.add_column("Value", style="green")
    if args.sources:
        table.add_column("Source", style="dim")

    for key, env_var, default in settings:
        value, source = resolve_config_value(key, None, env_var, config, default)
        if args.sources:
            table.add_row(key, str(value), source)
        else:
            table.add_row(key, str(value))

    err.print(table)
    err.print(f"\n[dim]Config file: {CONFIG_FILE}[/dim]")

def cmd_set(args):
    """Handle 'shai set <key> <value>' command."""
    key = args.key
    value = args.value

    if key not in VALID_CONFIG_KEYS:
        print_error(f"Unknown config key: {key}")
        print_info(f"Valid keys: {', '.join(sorted(VALID_CONFIG_KEYS))}")
        sys.exit(EXIT_ERROR)

    # Parse value to appropriate type
    if value.lower() in ("true", "false"):
        value = parse_bool(value)
    elif value.isdigit():
        value = int(value)

    config = load_config()
    set_nested(config, key, value)
    save_config(config)
    print_info(f"Set {key} = {value}")

def cmd_unset(args):
    """Handle 'shai unset <key>' command."""
    key = args.key

    if key not in VALID_CONFIG_KEYS:
        print_error(f"Unknown config key: {key}")
        print_info(f"Valid keys: {', '.join(sorted(VALID_CONFIG_KEYS))}")
        sys.exit(EXIT_ERROR)

    config = load_config()
    if unset_nested(config, key):
        save_config(config)
        print_info(f"Unset {key}")
    else:
        print_warning(f"{key} was not set")


# === Main ===

def main():
    args = parse_args()

    # Handle subcommands that don't need API key
    if args.command == "config":
        cmd_config(args)
        sys.exit(EXIT_SUCCESS)
    elif args.command == "set":
        cmd_set(args)
        sys.exit(EXIT_SUCCESS)
    elif args.command == "unset":
        cmd_unset(args)
        sys.exit(EXIT_SUCCESS)

    # For query command, need API key
    require_api_key()

    # Check if we have a query
    if not args.query:
        print_error("No query provided. Usage: shai \"your command description\"")
        sys.exit(EXIT_ERROR)

    # Load config and resolve values
    config = load_config()
    model, _ = resolve_config_value("model", args.model, "SHAI_MODEL", config, DEFAULT_MODEL)
    quiet, _ = resolve_config_value("quiet", args.quiet if args.quiet else None, "SHAI_QUIET", config, DEFAULT_QUIET)

    query = " ".join(args.query)
    history = read_stdin_history()
    session_enabled, _ = resolve_config_value("session.enabled", None, "SHAI_SESSION_ENABLED", config, False)
    session_dir, _ = resolve_config_value("session.dir", None, "SHAI_SESSION_DIR", config, "~/.shai_session")
    session_file = os.path.expanduser(session_dir) + "/session" if session_enabled else None
    session_context = read_session_file(session_file)
    dir_context = ""

    try:
        result = call_openai(query, history, session_context, dir_context, model=model)
        if not quiet:
            print_explanation(result)
        print_danger_warning(result)
        output_command(result.command)
        sys.exit(get_exit_code(result))
    except Exception as e:
        print_error(f"Error: {e}")
        sys.exit(EXIT_ERROR)


if __name__ == "__main__":
    main()
