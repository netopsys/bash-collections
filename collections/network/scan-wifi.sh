#!/bin/bash

# ==============================================================================
# Module : scan-wifi.sh
# Description : NETWORK  - Scan Wi-Fi 
# Author : netopsys
# License : GPL-3.0
# ==============================================================================

#DEBUG=1
set -euo pipefail 
[ -n "${DEBUG:-}" ] && set -x 

LOGFILE="/var/log/network-wifi.log"
INTERVAL=3 

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() {
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - NETWORK - Scan Wi-Fi "
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

log_info()  { printf "%s ${CYAN}[INFO]${RESET} %s\n"  "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
log_ok()    { printf "%s ${GREEN}✔${RESET}   %s\n"  "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
log_warn()  { printf "%s ${YELLOW}[WARN]${RESET} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
log_error() { printf "%s ${RED}[ERROR]${RESET} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
check_dependencies() {
  local deps=(nmcli)
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

manage_network_state_wifi() {

    log_info "WiFi Status:"
    nmcli radio 
    echo ""
    read -rp "➤ Enable or disable WiFi? (on/off): " choiceWiFi
    if [[ "$choiceWiFi" == "on" ]]; then
        nmcli radio wifi on
        log_ok "WiFi set to on"
    elif [[ "$choiceWiFi" == "off" ]]; then
        nmcli radio wifi off
    else
        log_info "Skipped..." 
    fi 
}

scan_wifi() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S') 
    nmcli -t -f BSSID,SSID,SIGNAL dev wifi list | while IFS=: read -r bssid ssid signal; do
        if [[ -n "$bssid" ]]; then
            log_info "Wi-Fi | BSSID=$bssid SSID=\"$ssid\" Signal=${signal}%" | tee -a "$LOGFILE"
        fi
    done 
}

# scan_wifi() {
#     log_info "Scan Wi-Fi en cours..."
#     if command -v nmcli &>/dev/null; then
#         while true; do
#             clear
#             nmcli dev wifi list
#             sleep 2
#         done
#         # echo "nmcli dev wifi list"
#         # exit 0
#     elif command -v iwlist &>/dev/null; then
#         sudo iwlist scan | grep -E "Cell|ESSID|Signal"
#     else
#         log_error "Aucun outil Wi-Fi trouvé (nmcli ou iwlist)."
#     fi
# }
 
# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------
main() {

    print_banner
    check_dependencies
    manage_network_state_wifi 

    read -rp "➤ Scan wifi? [y/N] : " CHOICE
    CHOICE="${CHOICE:-n}"
    if [[ "$CHOICE" == "y" ]]; then
        log_info "Logs: $LOGFILE"
        while true; do
            clear
            print_banner
            scan_wifi 
            sleep "$INTERVAL"
        done
    else
        log_warn "Scan wifi skipped."
    fi
}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
