# AI Command Generator - Zsh Integration
# Add this to your .zshrc or source this file

# Path to the Python script - adjust if needed
AI_CMD_SCRIPT="${AI_CMD_SCRIPT:-$HOME/.local/bin/ai_cmd.py}"

# Session capture configuration (opt-in)
AI_CMD_SESSION_ENABLED="${AI_CMD_SESSION_ENABLED:-0}"
AI_CMD_SESSION_DIR="${AI_CMD_SESSION_DIR:-$HOME/.ai_cmd_session}"
AI_CMD_SESSION_SIZE="${AI_CMD_SESSION_SIZE:-50}"

# Session file for this shell instance (PID-based)
_AI_CMD_SESSION_FILE="${AI_CMD_SESSION_DIR}/$$"

# Variables to hold command info between preexec and precmd
_ai_cmd_last_cmd=""
_ai_cmd_last_timestamp=""
_ai_cmd_last_cwd=""

# Create session directory if needed
_ai_cmd_init_session() {
  [[ "$AI_CMD_SESSION_ENABLED" != "1" ]] && return
  mkdir -p "$AI_CMD_SESSION_DIR"
}

# Trim session file to keep only last N entries
_ai_cmd_trim_session() {
  [[ ! -f "$_AI_CMD_SESSION_FILE" ]] && return

  local temp_file=$(mktemp)
  local count=0
  local in_entry=false
  local entries=()
  local current_entry=""

  # Read file and split into entries (separated by ---)
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "---" ]]; then
      entries+=("$current_entry---")
      current_entry=""
    else
      current_entry+="$line"$'\n'
    fi
  done <"$_AI_CMD_SESSION_FILE"

  # Keep only last N entries
  local total=${#entries[@]}
  local start=$((total - AI_CMD_SESSION_SIZE))
  [[ $start -lt 0 ]] && start=0

  : >"$_AI_CMD_SESSION_FILE"
  for (( i = start; i < total; i++ )); do
    printf '%s\n' "${entries[$i]}" >>"$_AI_CMD_SESSION_FILE"
  done
}

# preexec hook - called before command execution
_ai_cmd_preexec() {
  [[ "$AI_CMD_SESSION_ENABLED" != "1" ]] && return

  _ai_cmd_last_cmd="$1"
  _ai_cmd_last_timestamp=$(date -Iseconds)
  _ai_cmd_last_cwd="$PWD"
}

# precmd hook - called after command execution
_ai_cmd_precmd() {
  local exit_code=$?

  [[ "$AI_CMD_SESSION_ENABLED" != "1" ]] && return
  [[ -z "$_ai_cmd_last_cmd" ]] && return

  # Append entry to session file
  {
    echo "[${_ai_cmd_last_timestamp}] [exit:${exit_code}] [cwd:${_ai_cmd_last_cwd}]"
    echo "$ ${_ai_cmd_last_cmd}"
    echo "---"
  } >>"$_AI_CMD_SESSION_FILE"

  # Clear for next command
  _ai_cmd_last_cmd=""

  # Trim if needed (every 10 commands to avoid overhead)
  if [[ -f "$_AI_CMD_SESSION_FILE" ]]; then
    local line_count=$(wc -l <"$_AI_CMD_SESSION_FILE")
    if ((line_count > AI_CMD_SESSION_SIZE * 4)); then
      _ai_cmd_trim_session
    fi
  fi
}

# Cleanup on shell exit
_ai_cmd_zshexit() {
  [[ "$AI_CMD_SESSION_ENABLED" != "1" ]] && return
  rm -f "$_AI_CMD_SESSION_FILE"
}

# Register hooks
_ai_cmd_init_session
autoload -Uz add-zsh-hook
add-zsh-hook preexec _ai_cmd_preexec
add-zsh-hook precmd _ai_cmd_precmd
add-zsh-hook zshexit _ai_cmd_zshexit

# Function that generates command and pre-populates the buffer
ai() {
  local debug=false
  local -a python_flags
  local -a query_parts

  # Parse all arguments - separate debug flag, python flags, and query
  for arg in "$@"; do
    case "$arg" in
    --debug)
      debug=true
      ;;
    -*)
      python_flags+=("$arg")
      ;;
    *)
      query_parts+=("$arg")
      ;;
    esac
  done

  local query="${query_parts[*]}"

  # Pass --help directly to Python without capturing
  if [[ " ${python_flags[*]} " == *" --help "* ]] || [[ " ${python_flags[*]} " == *" -h "* ]]; then
    "$AI_CMD_SCRIPT" "${python_flags[@]}"
    return 0
  fi

  if [[ -z "$query" ]]; then
    echo "Usage: ai [--debug] [flags...] <natural language query>"
    return 1
  fi

  local cmd
  local history_context

  $debug && echo "[DEBUG] Query: $query"
  $debug && echo "[DEBUG] Python flags: ${python_flags[*]}"

  # Get recent shell history for context
  history_context=$(fc -l -n -10 2>/dev/null | tail -10)

  $debug && echo "[DEBUG] History context:"
  $debug && echo "$history_context"
  $debug && echo "[DEBUG] ---"

  # Add session file if session capture is enabled
  local session_args=()
  if [[ "$AI_CMD_SESSION_ENABLED" == "1" ]] && [[ -f "$_AI_CMD_SESSION_FILE" ]]; then
    session_args+=(--session-file "$_AI_CMD_SESSION_FILE")
    $debug && echo "[DEBUG] Session file: $_AI_CMD_SESSION_FILE"
  fi

  $debug && echo "[DEBUG] Calling: $AI_CMD_SCRIPT ${session_args[*]} ${python_flags[*]} $query"

  # Call the script - stderr shows warnings, stdout captured as command
  local stderr_file=$(mktemp)
  cmd=$(echo "$history_context" | "$AI_CMD_SCRIPT" "${session_args[@]}" "${python_flags[@]}" "$query" 2>"$stderr_file")
  local exit_code=$?
  local stderr_output=$(<"$stderr_file")
  rm -f "$stderr_file"

  $debug && echo "[DEBUG] Exit code: $exit_code"
  $debug && echo "[DEBUG] Stderr: $stderr_output"
  $debug && echo "[DEBUG] Command: $cmd"

  # Show warnings/errors from stderr
  [[ -n "$stderr_output" ]] && echo "$stderr_output" >&2

  # Exit codes: 0 = success, 1 = error, 2 = destructive (don't auto-load)
  if [[ $exit_code -eq 1 ]]; then
    return 1
  fi

  if [[ $exit_code -eq 2 ]]; then
    # Destructive command - show it but don't load into buffer
    echo "" >&2
    echo "⛔ DANGEROUS - not auto-pasted. Copy manually:" >&2
    echo "" >&2
    echo "  $cmd" >&2
    echo "" >&2
    return 0
  fi

  $debug && echo "[DEBUG] Loading into buffer with print -z"

  # Pre-populate the command line buffer with the generated command
  print -z "$cmd"
}

# Alternative: Zle widget version (bind to a key)
# This version lets you type the query inline and press a key combo
_ai_generate_widget() {
  local query="$BUFFER"

  if [[ -z "$query" ]]; then
    return
  fi

  # Clear the line and show thinking indicator
  BUFFER=""
  zle -M "Generating command..."

  local cmd
  cmd=$("$AI_CMD_SCRIPT" "$query" 2>&1)

  if [[ $? -eq 0 ]]; then
    BUFFER="$cmd"
    CURSOR=${#BUFFER}
    zle -M "→ Generated from: $query"
  else
    BUFFER="$query"
    CURSOR=${#BUFFER}
    zle -M "Error: $cmd"
  fi
}

zle -N _ai_generate_widget

# Bind Ctrl+G to generate (G for Generate)
# Type your query, press Ctrl+G, and it transforms into a command
bindkey '^G' _ai_generate_widget

#mkdir dean
#ai "remove that folder"