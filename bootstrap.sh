#!/usr/bin/env bash
# bootstrap.sh — one-button system restore for my_os
#
# Runs AFTER a fresh Debian 13 install done via preseed.
# Orchestrates system apps (ansible), user dotfiles (chezmoi),
# and per-user tools (atuin, rustup, go tools).
#
# Usage:
#   cd ~/mr/workspace/my_os
#   ./bootstrap.sh              # run everything
#   ./bootstrap.sh ansible      # only system apps
#   ./bootstrap.sh dotfiles     # only chezmoi
#   ./bootstrap.sh user-tools   # only atuin/rustup/go
#
# Safe to re-run: every step is idempotent.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------------
# Pretty printing
# --------------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------
# Step: system apps via ansible (sudo)
# --------------------------------------------------------------------
step_ansible() {
    log "System apps (ansible playbook)"

    command -v ansible-playbook >/dev/null \
        || die "ansible-playbook not found. Install via 'sudo apt install ansible'"

    cd "$REPO_DIR/ansible"
    sudo ansible-playbook -i inventory.ini site.yml
}

# --------------------------------------------------------------------
# Step: dotfiles via chezmoi
# --------------------------------------------------------------------
# TODO(user): set DOTFILES_REPO to your own repo URL when it exists.
DOTFILES_REPO=""     # example: https://github.com/<you>/dotfiles.git

step_dotfiles() {
    log "Dotfiles (chezmoi)"

    if [ -z "$DOTFILES_REPO" ]; then
        warn "DOTFILES_REPO not set. Skipping chezmoi."
        warn "Edit bootstrap.sh and set DOTFILES_REPO to enable."
        return 0
    fi

    command -v chezmoi >/dev/null \
        || die "chezmoi not found (should be installed via preseed)"

    chezmoi init --apply "$DOTFILES_REPO"
}

# --------------------------------------------------------------------
# Step: user-level tools (run as regular user, not root)
# --------------------------------------------------------------------
step_user_tools() {
    log "User-level tools (atuin, rustup, go tools)"

    # --- atuin (shell history sync) ---
    if ! command -v atuin >/dev/null; then
        log "  atuin: install via official script"
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
        if ! grep -q 'atuin init bash' "$HOME/.bashrc" 2>/dev/null; then
            echo 'eval "$(atuin init bash)"' >> "$HOME/.bashrc"
        fi
    else
        log "  atuin: already installed, skipping"
    fi

    # --- rustup + Rust toolchain ---
    if ! command -v rustup >/dev/null; then
        log "  rustup: install stable toolchain"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    else
        log "  rustup: already installed, skipping"
    fi

    # --- Go tools ---
    if command -v go >/dev/null; then
        export PATH="$HOME/go/bin:$PATH"
        for pkg in \
            github.com/go-delve/delve/cmd/dlv@latest \
            golang.org/x/tools/gopls@latest \
            honnef.co/go/tools/cmd/staticcheck@latest
        do
            tool="${pkg##*/}"; tool="${tool%@latest}"
            tool="${tool%/cmd*}"   # strip /cmd/dlv → dlv
            if command -v "$tool" >/dev/null; then
                log "  go tool: $tool already installed, skipping"
            else
                log "  go install $pkg"
                go install "$pkg"
            fi
        done
    else
        warn "go not found. Install 'golang-go' or run: sudo apt install golang-go"
    fi
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------
main() {
    local target="${1:-all}"
    case "$target" in
        all)
            step_ansible
            step_dotfiles
            step_user_tools
            log "All steps complete."
            ;;
        ansible)     step_ansible ;;
        dotfiles)    step_dotfiles ;;
        user-tools)  step_user_tools ;;
        -h|--help|help)
            sed -n '2,/^set -/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            ;;
        *)
            die "Unknown target '$target'. See: $0 --help"
            ;;
    esac
}

main "$@"
