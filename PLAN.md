# AI Command Generator - Feature Roadmap

## 1. Safety & UX
1. **Confirmation mode** (`--confirm` / `-c`) - require explicit "y" before loading into buffer
2. **Dry run mode** (`--dry-run`) - show what the command would do without generating it
3. **Undo tracking** - save last generated command to a file for easy recall

## 2. Context & Intelligence

### Terminal session capture (foundation for many features below)
- Hook into shell to capture command + stdout + stderr for recent commands
- Options: `script` command, zsh preexec/precmd hooks, or custom PROMPT_COMMAND
- Store in ring buffer file (~/.ai_cmd_session) with recent N commands
- Format: `[timestamp] [exit_code] [cwd] command\n---stdout---\n...\n---stderr---\n...`
- Privacy: configurable, opt-in, auto-truncate large outputs

### Features
1. ~~**Current directory awareness** - pass `pwd` and `ls` output to the model for better context~~ ✅
2. ~~**OS detection** - adjust commands for macOS vs Linux (e.g., `gdate` vs `date`)~~ ✅
3. ~~**Alias awareness** - read user's aliases and prefer them when applicable~~ ✅
4. **Git context** - detect if in a repo, current branch, dirty state, remote info
5. **Project type detection** - recognize package.json, Cargo.toml, pyproject.toml and suggest appropriate tools
6. **Environment variables** - optionally include relevant env vars (PATH tools, EDITOR, etc.)
7. **Installed tools detection** - check what's available (brew, apt, docker, kubectl) before suggesting
8. **Shell detection** - adapt for zsh vs bash vs fish specific syntax
9. **User context file** - read optional `.ai_context` in project root for project-specific hints
10. **Recent errors** - use session capture to get last stderr, enable "fix that error" requests
11. **Command output context** - "do that again but with verbose" knows what "that" outputted
12. **Failed command retry** - detect non-zero exit, suggest fix automatically

## 3. Configuration
1. **Config file** (`~/.ai_cmd.yaml`) - default model, temperature, custom system prompt
2. **Model flag** (`--model gpt-4o`) - switch models on the fly
3. **Custom prompts** - domain-specific modes like `--git`, `--docker`, `--k8s`

## 4. Output Options
1. **Multiple suggestions** (`-n 3`) - show 3 alternatives to choose from
2. **Chain commands** - generate multi-step scripts for complex requests
3. **Clipboard mode** (`--copy`) - copy to clipboard instead of buffer

## 5. History & Learning
1. ~~**Feedback loop** - track which commands user actually ran, use for fine-tuning prompts~~ ✅
2. **Favorites** - save frequently used query→command mappings locally
3. **Session memory** - remember context beyond just shell history