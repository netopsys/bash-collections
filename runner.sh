#!/bin/bash

# ==============================================================================
# Module : runner.sh
# Description : Bash runner Netopsys Collections
# Author      : netopsys (https://github.com/netopsys)
# License     : GPL-3.0 
# ==============================================================================

#DEBUG=1
set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x 

# trap 'log_warn "Interrupted by user"; exit 1' SIGINT
# ------------------------------------------------------------------------------
# Trap cleanup
# ------------------------------------------------------------------------------
cleanup() {
  log_warn "Interrupted by user, exiting..."
  exit 130
}
trap cleanup INT TERM

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() {
  clear
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - Bash Collections          " 
  echo "===========================================================" 
  echo
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
readonly RED="\033[0;31m" 
readonly YELLOW="\033[0;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"
 
log_info()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${CYAN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${RESET} $*"; } 

# ------------------------------------------------------------------------------
# Constants & Variables
# ------------------------------------------------------------------------------
readonly SCRIPT_ROOT="collections"
scripts=()
selected_script=""
args=()

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
 
# Extract the description from the script file header. 
get_description() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "(file not found)"
    return
  fi

  local desc
  desc=$(grep -m1 "^# *Description *:" "$file" || true)
  if [[ -z "$desc" ]]; then
    echo "(no description)"
  else
    echo "$desc" | sed -E 's/^# *Description *: *//'
  fi
}
 
# List executable Bash scripts under SCRIPT_ROOT. 
list_scripts() {
  # log_info "Programs :\n" 

  local base_dir
  base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_ROOT"

  if [[ ! -d "$base_dir" ]]; then
    log_error "Directory '$base_dir' not found."
    exit 1
  fi

  mapfile -t scripts < <(
    find "$base_dir" -type f -perm /u+x -exec grep -IlE '^#! */(usr/)?bin/(env )?bash' {} + 2>/dev/null | sort
  )

  if [[ ${#scripts[@]} -eq 0 ]]; then
    log_error "No executable Bash scripts found under '$SCRIPT_ROOT'."
    exit 1
  fi
  
  echo "Menu:" 
  for i in "${!scripts[@]}"; do
    # local script_name 
    local description
    # script_name="$(basename "${scripts[i]}")"
    description="$(get_description "${scripts[i]}")"
    printf "%5d) %-5s\n" $((i + 1)) "$description"
  done
  echo 
}
 
# Prompt user to select a script number. 
select_script() {
  local choice
  while true; do
    read -rp "➤ Select number: " choice || {
      exit 1
    }

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#scripts[@]} )); then
      selected_script="${scripts[$((choice - 1))]}"
 
      local base_dir
      base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_ROOT"
      if [[ "$selected_script" != "$base_dir"* ]]; then
        log_error "Invalid script path (outside of allowed directory)!"
        exit 1
      fi

      break
    else
      log_warn "Invalid selection: $choice. Please enter a valid number."
    fi
  done
}
 
# Ask user if they want to see help output for the selected script. 
ask_print_usage_script() {
  local CHOICE
  read -rp "➤ Show help? [y/N]: " CHOICE || CHOICE="n"
  CHOICE="${CHOICE:-n}"

  if [[ "$CHOICE" =~ ^[Yy]$ ]]; then
    # log_info "Displaying help for '$(basename "$selected_script")'..."
    if bash "$selected_script" --help &>/dev/null; then
      bash "$selected_script" --help
    elif bash "$selected_script" -h &>/dev/null; then
      bash "$selected_script" -h
    else
      log_warn "No help output available or --help/-h not supported."
    fi
    echo
  fi
}
 
# Prompt user to enter arguments to pass to the selected script. 
prompt_args() {
  read -rp "➤ Enter options/arguments to pass (or leave empty): " user_args || user_args=""
  # shellcheck disable=SC2206
  args=($user_args)
}
  
# Run the selected script with the provided arguments. 
run_script() {
  echo 
  if bash "$selected_script" "${args[@]}"; then 
    exit 0 
  fi
  # log_error "Exited 1..."
  # exit 1
}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  cat << EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help         Show this help message and exit.
  -l, --list         List available scripts and exit. 

If no options are provided, the script lists available scripts and prompts for selection.

EOF
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
  # Parse arguments
  if [[ $# -gt 0 ]]; then
    case "$1" in
      -h|--help)
        print_banner
        print_usage
        exit 0
        ;;
      -l|--list)
        print_banner
        list_scripts
        exit 0
        ;; 
      *)
        log_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
  fi

  # Default interactive flow
  print_banner
  list_scripts
  select_script
  ask_print_usage_script
  prompt_args
  run_script
}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
