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
from openai import OpenAI
from pydantic import BaseModel, Field
from rich.console import Console
from rich.syntax import Syntax
from rich.padding import Padding


# === Constants ===

COLOR_CODE_BG = "#555555"
COLOR_INFO = "cyan"
COLOR_WARNING = "yellow"
COLOR_ERROR = "red"

EXIT_SUCCESS = 0
EXIT_ERROR = 1
EXIT_DESTRUCTIVE = 2

SYSTEM_PROMPT = """You are a shell command generator. Convert the user's natural language request into a single shell command.

Rules:
- Use standard Unix/Linux commands that work on macOS and Linux
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
    highlighted.stylize(f"on {COLOR_CODE_BG}")
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
            err.print(f"{i}.")
            print_code(f"{step.command}\n# {step.explanation}")

def print_danger_warning(result: CommandResponse):
    if result.is_destructive:
        print_warning(f"⚠️  {result.danger_reason}")

def output_command(command: str):
    print(command)


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

def call_openai(query: str, history: str = "", session_context: str = "", dir_context: str = "") -> CommandResponse:
    client = OpenAI()
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages.extend(build_context_messages(history, session_context, dir_context))
    messages.append({"role": "user", "content": query})

    response = client.beta.chat.completions.parse(
        model="gpt-5.1-2025-11-13",
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
    parser = argparse.ArgumentParser(description="Convert natural language to shell commands")
    parser.add_argument("-q", "--quiet", action="store_true", help="Hide explanation of what the command does")
    parser.add_argument("--session-file", help="Path to session file with recent command history and exit codes")
    parser.add_argument("--dir-context", help="Current directory info (pwd + ls output)")
    parser.add_argument("query", nargs="+", help="Natural language description of the command you want")
    return parser.parse_args()

def get_exit_code(result: CommandResponse) -> int:
    return EXIT_DESTRUCTIVE if result.is_destructive else EXIT_SUCCESS


# === Main ===

def main():
    args = parse_args()
    require_api_key()

    query = " ".join(args.query)
    history = read_stdin_history()
    session_context = read_session_file(args.session_file)
    dir_context = args.dir_context or ""

    try:
        result = call_openai(query, history, session_context, dir_context)
        if not args.quiet:
            print_explanation(result)
        print_danger_warning(result)
        output_command(result.command)
        sys.exit(get_exit_code(result))
    except Exception as e:
        print_error(f"Error: {e}")
        sys.exit(EXIT_ERROR)


if __name__ == "__main__":
    main()
