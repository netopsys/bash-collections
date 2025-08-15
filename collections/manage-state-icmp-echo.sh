#!/bin/bash

# ==============================================================================
# Module : manage-icmp-echo.sh
# Description : SECURITY - Manage state icmp echo
# Author      : netopsys (https://github.com/netopsys)
# License     : GPL-3.0
# ==============================================================================

#DEBUG=1
set -euo pipefail 
[ -n "${DEBUG:-}" ] && set -x  

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() { 
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - SECURITY - Manage state icmp echo "
  echo "==========================================================="  
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
readonly CYAN='\033[0;36m' 
readonly GREEN="\033[0;32m" 
readonly RESET="\033[0m"

log_info()  { printf "[%s] ${CYAN}[INFO]${RESET} %s\n"  "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_ok()    { printf "[%s] ${GREEN}[OK]${RESET}   %s\n"  "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; } 

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
confirm_step() {
  read -rp "➤ $1? (y/N): " confirm
  [[ "$confirm" =~ ^[Yy]$ ]]
}

enabled_icmp_echo() {
	log_info "Enabling ping replies..."
  echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all > /dev/null
  systemctl reload NetworkManager.service
  systemctl daemon-reload
  status_icmp=$(sudo cat /proc/sys/net/ipv4/icmp_echo_ignore_all)
  log_info "ICMP STATUS (0=on 1=off): $status_icmp"
  log_ok "Ping responses are now ENABLED."
  exit 0
}

disabled_icmp_echo() {
  log_info "Disabling ping replies..."
  echo 1 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all > /dev/null
  systemctl reload NetworkManager.service
  systemctl daemon-reload
  status_icmp=$(sudo cat /proc/sys/net/ipv4/icmp_echo_ignore_all)
  log_info "ICMP STATUS (0=on 1=off): $status_icmp"
  log_ok "Ping responses are now DISABLED."
  exit 0
}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  echo "Usage: $(basename "$0")"
  exit 0
}

# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------
main() {
  
  print_banner 

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) 
        print_usage 
        ;; 
    esac
    shift
  done
  
  status_icmp=$(sudo cat /proc/sys/net/ipv4/icmp_echo_ignore_all)
  log_info "ICMP STATUS (0=on 1=off): $status_icmp"
  confirm_step "Do you want to ENABLE ping response"  && enabled_icmp_echo 
  confirm_step "Do you want to DISABLED ping response"  && disabled_icmp_echo 
  exit 0 

}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
