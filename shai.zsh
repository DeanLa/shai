# ShAI - Shell AI Command Generator - Zsh Integration
# Add this to your .zshrc or source this file

# Path to the Python script - adjust if needed
SHAI_SCRIPT="${SHAI_SCRIPT:-$HOME/.local/bin/shai.py}"

# Session capture configuration (opt-in)
SHAI_SESSION_ENABLED="${SHAI_SESSION_ENABLED:-0}"
SHAI_SESSION_DIR="${SHAI_SESSION_DIR:-$HOME/.shai_session}"
SHAI_SESSION_SIZE="${SHAI_SESSION_SIZE:-50}"

# Session file for this shell instance (PID-based)
_SHAI_SESSION_FILE="${SHAI_SESSION_DIR}/$$"

# Variables to hold command info between preexec and precmd
_shai_last_cmd=""
_shai_last_timestamp=""
_shai_last_cwd=""

# Create session directory if needed
_shai_init_session() {
  [[ "$SHAI_SESSION_ENABLED" != "1" ]] && return
  mkdir -p "$SHAI_SESSION_DIR"
}

# Trim session file to keep only last N entries
_shai_trim_session() {
  [[ ! -f "$_SHAI_SESSION_FILE" ]] && return

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
  done <"$_SHAI_SESSION_FILE"

  # Keep only last N entries
  local total=${#entries[@]}
  local start=$((total - SHAI_SESSION_SIZE))
  [[ $start -lt 0 ]] && start=0

  : >"$_SHAI_SESSION_FILE"
  for (( i = start; i < total; i++ )); do
    printf '%s\n' "${entries[$i]}" >>"$_SHAI_SESSION_FILE"
  done
}

# preexec hook - called before command execution
_shai_preexec() {
  [[ "$SHAI_SESSION_ENABLED" != "1" ]] && return

  _shai_last_cmd="$1"
  _shai_last_timestamp=$(date -Iseconds)
  _shai_last_cwd="$PWD"
}

# precmd hook - called after command execution
_shai_precmd() {
  local exit_code=$?

  [[ "$SHAI_SESSION_ENABLED" != "1" ]] && return
  [[ -z "$_shai_last_cmd" ]] && return

  # Append entry to session file
  {
    echo "[${_shai_last_timestamp}] [exit:${exit_code}] [cwd:${_shai_last_cwd}]"
    echo "$ ${_shai_last_cmd}"
    echo "---"
  } >>"$_SHAI_SESSION_FILE"

  # Clear for next command
  _shai_last_cmd=""

  # Trim if needed (every 10 commands to avoid overhead)
  if [[ -f "$_SHAI_SESSION_FILE" ]]; then
    local line_count=$(wc -l <"$_SHAI_SESSION_FILE")
    if ((line_count > SHAI_SESSION_SIZE * 4)); then
      _shai_trim_session
    fi
  fi
}

# Cleanup on shell exit
_shai_zshexit() {
  [[ "$SHAI_SESSION_ENABLED" != "1" ]] && return
  rm -f "$_SHAI_SESSION_FILE"
}

# Register hooks
_shai_init_session
autoload -Uz add-zsh-hook
add-zsh-hook preexec _shai_preexec
add-zsh-hook precmd _shai_precmd
add-zsh-hook zshexit _shai_zshexit

# Function that generates command and pre-populates the buffer
shai() {
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
    "$SHAI_SCRIPT" "${python_flags[@]}"
    return 0
  fi

  if [[ -z "$query" ]]; then
    echo "Usage: shai [--debug] [flags...] <natural language query>"
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
  if [[ "$SHAI_SESSION_ENABLED" == "1" ]] && [[ -f "$_SHAI_SESSION_FILE" ]]; then
    session_args+=(--session-file "$_SHAI_SESSION_FILE")
    $debug && echo "[DEBUG] Session file: $_SHAI_SESSION_FILE"
  fi

  $debug && echo "[DEBUG] Calling: $SHAI_SCRIPT ${session_args[*]} ${python_flags[*]} $query"

  # Call the script - stderr shows warnings, stdout captured as command
  local stderr_file=$(mktemp)
  cmd=$(echo "$history_context" | "$SHAI_SCRIPT" "${session_args[@]}" "${python_flags[@]}" "$query" 2>"$stderr_file")
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
_shai_generate_widget() {
  local query="$BUFFER"

  if [[ -z "$query" ]]; then
    return
  fi

  # Clear the line and show thinking indicator
  BUFFER=""
  zle -M "Generating command..."

  local cmd
  cmd=$("$SHAI_SCRIPT" "$query" 2>&1)

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

zle -N _shai_generate_widget

# Bind Ctrl+G to generate (G for Generate)
# Type your query, press Ctrl+G, and it transforms into a command
bindkey '^G' _shai_generate_widget
