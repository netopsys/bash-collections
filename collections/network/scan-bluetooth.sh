#!/bin/bash

# ==============================================================================
# Module : scan-bluetooth.sh
# Description : NETWORK  - Scan Bluetooth 
# Author : netopsys
# License : GPL-3.0
# ==============================================================================

#DEBUG=1
set -euo pipefail 
[ -n "${DEBUG:-}" ] && set -x 
 

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() {
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - NETWORK - Scan Bluetooth "
  echo "==========================================================="
}
 
# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
CYAN='\033[0;36m'
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

log_info()  { printf "%s ${CYAN}[INFO]${RESET} %s\n"  "$(date '+%H:%M:%S')" "$*"; }
log_ok()    { printf "%s ${GREEN}✔${RESET}   %s\n"  "$(date '+%H:%M:%S')" "$*"; }
log_warn()  { printf "%s ${YELLOW}[WARN]${RESET} %s\n" "$(date '+%H:%M:%S')" "$*"; }
log_error() { printf "%s ${RED}[ERROR]${RESET} %s\n" "$(date '+%H:%M:%S')" "$*"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
check_dependencies() {
  local deps=(bluetoothctl)
  local missing=()

  for cmd in "${deps[@]}"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  if (( ${#missing[@]} > 0 )); then
    log_error "Missing packages: ${missing[*]}"
    echo "To install them: sudo apt install ${missing[*]}"
    exit 1
  fi 
}

show_status() {
 
    log_info "Bluetooth Status:"
    if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
        echo -e "${RED}disable${RESET}"
    else
        echo -e "${GREEN}enable${RESET}"
    fi
    echo ""
} 

# scan_bluetooth() {
#     local timestamp
#     timestamp=$(date '+%Y-%m-%d %H:%M:%S')
#     log_info "Bluetooth Scan" | tee -a "$LOGFILE"

#     sudo bluetoothctl --monitor
#     agent on >/dev/null 2>&1 
#     scan on >/dev/null 2>&1 &
#     SCAN_PID=$!
#     sleep 10   # laisse le scan tourner quelques secondes
#     exit
#     kill "$SCAN_PID" >/dev/null 2>&1 || true

#     bluetoothctl devices | while read -r _ mac name; do
#         log_info "Bluetooth | MAC=$mac Name=\"$name\"" | tee -a "$LOGFILE"
#     done 
# }

scan_bluetooth() { 
    if command -v bluetoothctl &>/dev/null; then
        echo "
        bluetoothctl power on
        bluetoothctl agent on
        bluetoothctl scan on &
        sleep 25
        bluetoothctl devices
        bluetoothctl scan off
        "
        exit 0
    elif command -v hcitool &>/dev/null; then
        hcitool scan
    else
        log_error "No tools (bluetoothctl or hcitool)."
    fi
}

# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------
main() {

    print_banner 
    check_dependencies
    show_status 
    read -rp "➤ Scan bluetooth? [y/N] : " CHOICE
    CHOICE="${CHOICE:-n}"
    if [[ "$CHOICE" == "y" ]]; then 
        scan_bluetooth  
    else
        log_warn "Scan bluetooth skipped."
    fi
}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
