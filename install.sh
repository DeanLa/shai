#!/usr/bin/env bash
set -e

# ShAI Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/DeanLa/shai/main/install.sh | bash

INSTALL_DIR="${SHAI_INSTALL_DIR:-$HOME/.local/bin}"
REPO_URL="https://raw.githubusercontent.com/DeanLa/shai/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}▶${NC} $1"; }
warn() { echo -e "${YELLOW}▶${NC} $1"; }
error() { echo -e "${RED}▶${NC} $1"; exit 1; }

check_deps() {
    if ! command -v uv &>/dev/null; then
        warn "uv not found. Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
    command -v uv &>/dev/null || error "Failed to install uv. See https://docs.astral.sh/uv/"
    info "uv: $(uv --version)"
}

install_files() {
    mkdir -p "$INSTALL_DIR"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "$script_dir/shai.py" ]]; then
        cp "$script_dir/shai.py" "$INSTALL_DIR/shai.py"
        cp "$script_dir/shai.zsh" "$INSTALL_DIR/shai.zsh"
    else
        curl -fsSL "$REPO_URL/shai.py" -o "$INSTALL_DIR/shai.py"
        curl -fsSL "$REPO_URL/shai.zsh" -o "$INSTALL_DIR/shai.zsh"
    fi

    chmod +x "$INSTALL_DIR/shai.py"
    info "Installed to $INSTALL_DIR"
}

configure_shell() {
    local zshrc="$HOME/.zshrc"
    local source_line="[[ -f \"$INSTALL_DIR/shai.zsh\" ]] && source \"$INSTALL_DIR/shai.zsh\""

    if grep -q "shai.zsh" "$zshrc" 2>/dev/null; then
        info "Already in .zshrc"
        return
    fi

    echo "$source_line" >> "$zshrc"
    info "Added to .zshrc"
}

main() {
    echo ""
    echo "Installing ShAI"
    echo "==============="
    echo ""

    check_deps
    install_files
    configure_shell

    echo ""
    echo -e "${GREEN}✓ Installed!${NC}"
    echo ""
    echo "Make sure OPENAI_API_KEY is set, then:"
    echo -e "  ${YELLOW}shai \"list large files\"${NC}"
    echo ""

    # Replace current shell with fresh zsh to load shai
    exec zsh
}

main "$@"
