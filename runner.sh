#!/bin/bash

# ==============================================================================
# Script Name : runner.sh
# Description : Runner Bash Collections
# Author      : netopsys (https://github.com/netopsys)
# License     : gpl-3.0
# Created     : 2025-07-26
# Updated     : 2025-07-26
# ==============================================================================
set -euo pipefail
# trap 'log_warn "Interrupted by user"; exit 1' SIGINT

echo "==========================================================="
echo "🛡️  NETOPSYS - Bash Collections                            "
echo "                                                           "
echo "   Script : runner - Runner Scripts Bash Collections           "
echo "   Author : netopsys (https://github.com/netopsys)         "
echo "==========================================================="
echo

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"

log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }
 
# Get the absolute path of the current script, even if run via symlink
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly SCRIPT_ROOT="collections"
# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
list_scripts() {
  log_info "Looking for scripts under $SCRIPT_ROOT..."
  mapfile -t scripts < <(
    find "$SCRIPT_DIR/$SCRIPT_ROOT" -type f -perm /u+x \
      -exec grep -IlE '^#! */(usr/)?bin/(env )?bash' {} + | sort
  )

  if [[ ${#scripts[@]} -eq 0 ]]; then
    log_error "No scripts found under $SCRIPT_ROOT"
    exit 1
  fi

  log_info "Available scripts:"
  for i in "${!scripts[@]}"; do
    printf " %2d) %s\n" $((i + 1)) "$(basename "${scripts[$i]}")"
  done
}

select_script() {
  read -rp "➤ Select a script number to run: " choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#scripts[@]} )); then
    log_error "Invalid selection: $choice"
    exit 1
  fi

  readonly selected_script="${scripts[$((choice - 1))]}"
}

ask_show_help() {
  read -rp "➤ Do you want to see the help for this script before? (y/n): " show_help
  if [[ "$show_help" =~ ^[Yy]$ ]]; then
    log_info "Displaying help..."
    if ! bash "$selected_script" --help &> /dev/null && ! bash "$selected_script" -h &> /dev/null; then
      log_warn "No help output available or --help/-h not supported."
    else
      bash "$selected_script" --help 2>/dev/null || bash "$selected_script" -h
    fi
  fi
} 

prompt_args() {
  read -rp "➤ Enter options/arguments to pass like you launch script (or leave empty): " user_args
  IFS=' ' read -r -a args <<< "$user_args"
}

run_script() {
  log_info "Running: bash \"$selected_script\" ${args[*]}"
  bash "$selected_script" "${args[@]}"
}

# ------------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------------
main() {
  list_scripts
  select_script
  ask_show_help
  prompt_args
  run_script
}

main "$@"