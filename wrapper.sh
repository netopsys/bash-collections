#!/bin/bash

# ==============================================================================
# Script Name : runner.sh
# Description : Bash Wrapper for Netopsys Collections
# Author      : netopsys (https://github.com/netopsys)
# License     : GPL-3.0
# Created     : 2025-07-26
# Updated     : 2025-07-29
# ==============================================================================

set -euo pipefail
trap 'log_warn "Interrupted by user"; exit 1' SIGINT

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo "==========================================================="
echo "🛡️  NETOPSYS - Bash Collections"
echo "                                                           "
echo "   Script : Wrapper for Bash Collections                   "
echo "   Author : netopsys (https://github.com/netopsys)         "
echo "==========================================================="
echo

# ------------------------------------------------------------------------------
# Logging Helpers
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

# ------------------------------------------------------------------------------
# Constantes & Variables
# ------------------------------------------------------------------------------
readonly SCRIPT_ROOT="collections"
scripts=()
selected_script=""
args=()

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
get_description() {
  local file="$1"
  grep -m1 "^# *Description *:" "$file" | sed -E 's/^# *Description *: *//' || echo "(no description)"
}

list_scripts() {
  log_info "Displaying '$SCRIPT_ROOT'..."

  mapfile -t scripts < <(
    find "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_ROOT" -type f -perm /u+x \
      -exec grep -IlE '^#! */(usr/)?bin/(env )?bash' {} + | sort
  )

  if [[ ${#scripts[@]} -eq 0 ]]; then
    log_error "No executable Bash scripts found under '$SCRIPT_ROOT'."
    exit 1
  fi

  for i in "${!scripts[@]}"; do
    script_path="${scripts[$i]}"
    script_name="$(basename "$script_path")"
    description=$(get_description "$script_path")

    printf " %2d) %-35s %s\n" $((i + 1)) "$script_name" "$description"
  done


  echo
}

select_script() {
  read -rp "➤ Select a script number to run: " choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#scripts[@]} )); then
    log_error "Invalid selection: $choice"
    exit 1
  fi

  selected_script="${scripts[$((choice - 1))]}"
}

ask_show_help() {
  read -rp "➤ Show help for this script first? [y/N] : " CHOICE
  CHOICE="${CHOICE:-n}" 
  if [[ "$CHOICE" =~ ^[Yy]$ ]]; then
    log_info "Displaying help..."
    if ! bash "$selected_script" --help &> /dev/null && ! bash "$selected_script" -h &> /dev/null; then
      log_warn "No help output available or --help/-h not supported."
    else
      bash "$selected_script" --help 2>/dev/null || bash "$selected_script" -h
    fi
    echo
  fi
}

prompt_args() {
  read -rp "➤ Enter options/arguments to pass (or leave empty): " user_args
  IFS=' ' read -r -a args <<< "$user_args"
}

run_script() {
  # log_info "Running: bash \"$selected_script\" ${args[*]}"
  # echo
  bash "$selected_script" "${args[@]}"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
  list_scripts
  select_script
  ask_show_help
  prompt_args
  run_script
}

main "$@"
