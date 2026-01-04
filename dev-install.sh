#!/usr/bin/env bash
# Installs shai from local dev directory
set -e

INSTALL_DIR="${SHAI_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$INSTALL_DIR"

cp "$SCRIPT_DIR/shai.py" "$INSTALL_DIR/shai.py"
cp "$SCRIPT_DIR/shai.zsh" "$INSTALL_DIR/shai.zsh"
chmod +x "$INSTALL_DIR/shai.py"

echo "Installed to $INSTALL_DIR"
echo "Restart shell or: source $INSTALL_DIR/shai.zsh"
