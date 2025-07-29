#!/bin/bash
 
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# Colors & Logging
# ============================================================================

# Colors
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"

# Helper log functions
log_info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------------
log_info "git log pretty..."
git log --pretty=format:"%h | %ad | %an | %ae | %s %d" --date=iso -n 5

log_info "git log graph..."
git log --oneline --graph --decorate --all -n 5

if [[ -n $(git status --porcelain) ]]; then
  git status
  read -rp "👉 You want to add change? (y/n): " CONFIRM

  if [[ "$CONFIRM" == "y" ]]; then

    check_signing_key
    git add .

    read -rp "👉 You want to commit change? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
      show_commit_conventions
      read -rp "👉 Write message commit : " MESSAGE
      git commit -am "$MESSAGE"

      read -rp "👉 You want to push? (y/n): " CONFIRM
      if [[ "$CONFIRM" == "y" ]]; then
        git push
      fi

    fi
  fi

else

  log_info "git status..."
  git status
  has_branch_is_ahead=$(git status | grep "Your branch is ahead of")

  if [[ -n "$has_branch_is_ahead" ]]; then
    read -rp "👉 You want to push commits? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
      git push
    fi
    
  fi
fi

log_info "git log pretty..."
git log --pretty=format:"%h | %ad | %an | %ae | %s %d" --date=iso -n 5

log_info "git log graph..."
git log --oneline --graph --decorate --all -n 5
