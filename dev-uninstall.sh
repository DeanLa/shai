#!/usr/bin/env bash
# Removes manual shai install to allow clean dev testing
# Does NOT modify .zshrc (assumes it has the [[ -f ... ]] guard)

INSTALL_DIR="${SHAI_INSTALL_DIR:-$HOME/.local/bin}"

rm -f "$INSTALL_DIR/shai.py" "$INSTALL_DIR/shai.zsh"

echo "Removed manual install from $INSTALL_DIR"
echo "Dev usage: source $PWD/shai.zsh"
