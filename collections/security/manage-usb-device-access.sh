#!/bin/bash

# ==============================================================================
# Module : manage-usb-device-access.sh
# Description : SECURITY - Manage USB device access 
# Author      : netopsys (https://github.com/netopsys)
# License     : GPL-3.0 
# ============================================================================

#DEBUG=1
set -euo pipefail 
[ -n "${DEBUG:-}" ] && set -x 

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() { 
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - SECURITY - Manage USB device access "
  echo "==========================================================="
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"
 
log_info()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${GREEN}✔${RESET} $*"; }
log_warn()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${RESET} $*"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "Please run this script as root."
    exit 1
  fi
}

check_dependencies() {
  local dependencies=(usbguard)
  local missing=()

  # log_info "Checking dependencies..."

  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    log_error "Missing packages: ${missing[*]}"
    echo -e "\nTo install them:\n  sudo apt install ${missing[*]}"
    exit 1 
  fi
}

list_devices() {

  log_info  "Périphériques stockage mounted :"
  lsblk -o MODEL,TYPE,NAME,FSTYPE,UUID,SIZE,FSAVAIL,FSUSE%,RO,MOUNTPOINT,TRAN

  log_info  "Access périphériques :"
  ls -l /dev/sd*

  if [[ "$LIST" == true ]]; then
    OUTPUT_JSON=true
  fi

  log_info  "List périphériques USB connected :"
  lsusb

  log_info "List devices :"
  if [[ "$OUTPUT_JSON" == true ]]; then 

    usbguard list-devices | awk '
      BEGIN {
        print "["
      }
      {
        gsub(/^ *- /, "")
        id = $1
        $1 = ""
        printf "  {\"id\": \"%s\", \"info\": \"%s\"},\n", id, substr($0, 2)
      }
      END {
        print "]"
      }
    '
  else  
    usbguard list-devices -t
  fi

  if [[ "$LIST" == true ]]; then
    log_info "Exit..."
    exit 0
  fi
}

select_action() {
  echo
  read -rp "➤ Action: Allow or Block device? (allow/block/q): " CHOICE
  CHOICE="${CHOICE:-q}"

  if [[ "$CHOICE" == "quit" || "$CHOICE" == "q" ]]; then
    log_info "Exit..."; exit 1; 
  fi

  read -rp "➤ Select device ID: " DEVICE_ID
  read -rp "➤ Confirm $([[ $CHOICE == "allow" ]] && echo allow || echo block) device ID=$DEVICE_ID? [Y/n] : " CONFIRM
  CONFIRM="${CONFIRM:-y}"

  if [[ "$CONFIRM" != "y" ]]; then
    log_warn "Operation aborted by user."
    exit 0
  fi

  if [[ "$CHOICE" == "allow" ]]; then
    usbguard allow-device "$DEVICE_ID" 
    log_ok "Status: $(usbguard list-devices | grep "$DEVICE_ID:")"
  else
    usbguard block-device "$DEVICE_ID" 
    log_ok "Status: $(usbguard list-devices | grep "$DEVICE_ID:")"
  fi

  if [[ "$LIST" != true ]]; then
    log_info "Exit..."
    exit 0
  fi

}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  cat << EOF
Usage:
 $(basename "$0") [options]

Options:
  -h, --help        Show this help message
  --list            Only list USB devices, take no action

Examples:
  $(basename "$0")             Interactively allow/block USB devices
  $(basename "$0") --list      Just list USB devices 

EOF
  exit 0
}

# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------
main() {

  OUTPUT_JSON=false
  LIST=false

  print_banner 
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_usage ;;
      --list) LIST=true ;;
    esac
    shift
  done 

  check_root
  check_dependencies
  list_devices 
  select_action 
}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"