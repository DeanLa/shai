#!/usr/bin/env bash
set -e

INSTALL_DIR="${SHAI_INSTALL_DIR:-$HOME/.local/bin}"
ZSH_DIR="${SHAI_ZSH_DIR:-$HOME/.local/share/shai}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info() { echo -e "${GREEN}▶${NC} $1"; }

echo ""
echo "Uninstalling ShAI"
echo "================="
echo ""

# Remove files
[[ -f "$INSTALL_DIR/shai.py" ]] && rm "$INSTALL_DIR/shai.py" && info "Removed $INSTALL_DIR/shai.py"
[[ -d "$ZSH_DIR" ]] && rm -rf "$ZSH_DIR" && info "Removed $ZSH_DIR"

# Remove from .zshrc
if grep -q "shai.zsh\|SHAI_SCRIPT" "$HOME/.zshrc" 2>/dev/null; then
    info "Removing shai config from .zshrc..."
    sed -i.bak '/# ShAI/d; /SHAI_SCRIPT/d; /shai\.zsh/d' "$HOME/.zshrc"
    rm -f "$HOME/.zshrc.bak"
fi

echo ""
echo -e "${GREEN}✓ ShAI uninstalled${NC}"
echo "  Restart your terminal or run: source ~/.zshrc"
