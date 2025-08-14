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
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m" 
readonly YELLOW="\033[1;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"
 
log_info()  { printf "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { printf "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; } 
log_warn()  { printf "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { printf "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }

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
        log_info "Ping responses are now ENABLED."
        systemctl reload NetworkManager.service
        systemctl daemon-reload
        exit 0
}

disabled_icmp_echo() {
        log_info "Disabling ping replies..."
        echo 1 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all > /dev/null
        log_info "Ping responses are now DISABLED."
        systemctl reload NetworkManager.service
        systemctl daemon-reload
        exit 0
}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  printf "Usage: $(basename "$0")"
  exit 0
}
# ------------------------------------------------------------------------------
# MAIN
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
  confirm_step "Do you want to DISABLED ping response"  && enabled_icmp_echo 
  exit 0 

}

main "$@"
