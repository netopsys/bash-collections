#!/bin/bash
# ==============================================================================
# Script: git_commit_push.sh
# Description: Helper to commit and push with proper message and optional signing
# Author: netopsys
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Helper log functions
log_info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Git commit types convention (Conventional Commits)
show_commit_conventions() {
  cat << EOF

Conventional commit types:
  feat     - New feature
  fix      - Bug fix
  docs     - Documentation only
  style    - Formatting only (no functional change)
  refactor - Code change without functional effect
  perf     - Performance improvement
  test     - Adding/fixing tests
  chore    - Misc tasks / maintenance

EOF
}

# Check if signing key is configured
check_signing_key() {
  if ! git config --get user.signingkey &>/dev/null; then
    log_error "No GPG or SSH signing key configured in Git (user.signingkey)"
    echo "→ Tip: You can set it with:"
    echo "    git config --global user.signingkey <your-key>"
    exit 1
  fi
}

# Main logic
main() {

  log_info "Git log:"
  git log --oneline

  log_info "Git working tree status:"
  if [[ -z $(git status --porcelain) ]]; then
    echo "[ℹ️] Working tree clean — nothing to commit."
    exit 0
  fi

  echo ""
  git status
  read -rp "👉 Do you want to commit? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    log_error "commit aborted by user."
    exit 0
  fi

  echo ""
  show_commit_conventions
  read -rp "👉 Enter your commit message: " message
  if [[ -z "$message" ]]; then
    log_error "Commit message cannot be empty."
    exit 1
  fi

  check_signing_key

  log_info "Staging all changes..."
  git add .

  log_info "Creating signed commit..."
  git commit -S -m "$message"

  read -rp "👉 Do you want to push? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    log_error "push aborted by user."
    exit 0
  fi

  log_info "Pushing to remote..."
  git push

  log_success "✔ Commit and push completed successfully."
}

main "$@"
