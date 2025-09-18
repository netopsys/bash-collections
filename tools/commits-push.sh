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
  INITIAL_COMIT = '🎉'
  VERSION_TAG = '🔖'
  FEAT = '✨'
  FIX = '🐛'
  HOT_FIX = '🚑'
  DEPLOYING = '🚀'
  METADATA = '📇'
  DOCUMENTATION = '📚'
  DOCUMENTING_SOURCE_CODE = '💡'
  PEFORMANCE = '🐎'
  COSMETIC = '💄'
  TESTS = '🚨'
  ADD_TEST = '✔'
  TEST_PASS = '✔️'
  GENERAL_UPDATE = '⚡'
  IMPROVE_FORMAT_STRUCTURE = '🎨'
  REFACTOR = '🔨'
  REMOVE_CODE = '🔥'
  CI = '💚'
  SECURITY = '🔒'
  UPGRADING = '⬆️'
  DOWNGRADING = '⬇️'
  LINT = '👕'
  TRANSLATION = '👽'
  TEXT = '📝'
  FIXING_MACOS = '🍎'
  FIXING_LINUX = '🐧'
  FIXING_WINDOWS = '🏁'
  WORK_IN_PROGRESS = '🚧'
  ADDING_CI_BUILD = '👷'
  TRACKING_CODE = '📈'
  REMOVING_DEPENDENCY = '➖'
  ADDING_DEPENDENCY = '➕'
  DOCKER = '🐳'
  CONFIGURATION_FILES = '🔧'
  PACKAGE_JSON_IN_JS = '📦'
  MERGING_BRANCHES = '🔀'
  BAD_CODE_NEED_IMPROVE = '💩'
  BREAKING_CHANGES = '💥'
  CODE_REVIEW_CHANGES = '👌'
  ACCESSIBILITY = '♿'
  STOP = '⛔️'
  FAIL = '❌'
  OK = '✔️'

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
# Main prog
# ------------------------------------------------------------------------------
base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$base_dir" ]]; then
  log_error "Directory '$base_dir' not found."
  exit 1
fi
 
log_info "git log pretty..."
git log --pretty=format:"%h | %ad | %an | %ae | %s %d" --date=iso -n 10
 
if [[ -n $(git status --porcelain) ]]; then
  git status
  read -rp "➤ You want to add change? [Y/n] : " CHOICE
  CHOICE="${CHOICE:-y}"

  if [[ "$CHOICE" == "y" ]]; then

    check_signing_key
    git add -f . 

    read -rp "➤ You want to commit change? [Y/n] : " CHOICE
    CHOICE="${CHOICE:-y}"
    if [[ "$CHOICE" == "y" ]]; then
      show_commit_conventions
      read -rp "➤ Write message commit : " MESSAGE
      git commit -am "$MESSAGE"

      read -rp "➤ You want to push? [Y/n] : " CHOICE
      CHOICE="${CHOICE:-y}"
      if [[ "$CHOICE" == "y" ]]; then
        git push
      fi

    fi
  fi

else

  log_info "git status..."
  git status
  has_branch_is_ahead=$(git status | grep "Your branch is ahead of")

  if [[ -n "$has_branch_is_ahead" ]]; then
    read -rp "➤ You want to push commits? [Y/n] : " CHOICE
    CHOICE="${CHOICE:-y}"
    if [[ "$CHOICE" == "y" ]]; then
      git push
    fi
    
  fi
fi
 
log_info "git log graph..."
git log --oneline --graph --decorate --all -n 10
