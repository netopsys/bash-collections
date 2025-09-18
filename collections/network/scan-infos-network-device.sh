#!/bin/bash

# ==============================================================================
# Module : scan-infos-network-device.sh
# Description : NETWORK  - Scan Device Network infos
# Author      : netopsys (https://github.com/netopsys)
# License     : GPL-3.0   
# =============================================================================

#DEBUG=1
set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x  

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() { 
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - NETWORK - Scan Device Network infos"
  echo "===========================================================" 
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

log_info()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${GREEN}✔${RESET} $*"; }
log_warn()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${RESET} $*"; }
separator() { echo -e "${CYAN}--------------------------------------------------------${RESET}"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
check_dependencies() {
  local missing=()
  local dependencies=(hostnamectl whoami ps lsof lastlog df uptime dmidecode lshw lspci sensors ip systemctl netplan curl ethtool ss ping netstat nethogs ifstat vnstat tcpdump jq)
  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    log_error "Missing commands: ${missing[*]}"
    echo "Install them with: sudo apt install ${missing[*]}"
    exit 1 
  fi
}

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root (sudo)."
    exit 1
  fi
}
 
gather_network_info() {
  local interface 
  local ipv4 
  local mac_address 
  local subnet_mask 
  local gateway_address 
  local ipcalc 
  local dns_servers 
  local routes 

  log_info "==== 🖧 NETWORK DIAGNOSTIC ===="
  separator

  interface=$(ip route | awk '/default/ {print $5}' | head -n 1)
  ipv4=$(ip -4 addr show "$interface" | awk '/inet / {print $2}' | cut -d/ -f1)
  mac_address=$(ip link show "$interface" | awk '/ether/ {print $2}')
  subnet_mask=$(ip -4 addr show "$interface" | awk '/inet / {print $2}' | cut -d/ -f2)
  gateway_address=$(ip route | awk '/default/ {print $3}')
  ipcalc=$(ipcalc "$ipv4"/"$subnet_mask")
  dns_servers=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf)
  routes=$(ip route)

  log_info "Main interface: $interface"
  echo "IP: $(ip -4 addr show "$interface" | awk '/inet / {print $2}' | cut -d/ -f1)"
  echo "MAC: $mac_address"
  echo "Subnet: /$subnet_mask"
  echo "Gateway: $gateway_address"
  echo "DNS: $dns_servers"
  echo "Routes: $routes"
  echo -e "${CYAN}ipcalc result:${RESET}\n$ipcalc"
  separator

  log_info "Interface bandwidth"
  ethtool "$interface"
  separator

  log_info "Public IP info (via ipinfo.io)"
  curl -s https://ipinfo.io/json | jq
  separator

  log_info "NetworkManager status"
  systemctl is-active NetworkManager || echo "unknown"
  separator

  log_info "Netplan configuration"
  netplan status --all 2>/dev/null || echo "not available"
  separator

  log_info "Active connections (lsof -i -n -P)"
  lsof -i -n -P 
  separator

  log_info "Active connections (ss -tunap)"
  ss -tunap 
  separator
  # gw=$(ip route | grep default | head -n1 | awk '{print $3}')
  # log_info "Ping test to gateway ($gw):"
  # ping -c 2 "$gw"
  # separator

  log_info "Live traffic (ifstat 15s)"
  ifstat -t 1 15
  separator

  log_info "Network traffic history (vnstat)"
  vnstat -d
  separator

  log_info "Quick traffic analysis (tcpdump 15s)"
  timeout 15 tcpdump -i any -n -c 50
  separator

  # log_info "Top processes using the network (nethogs 15s)"
  # timeout 15 nethogs -t
  # separator
}

cleanup_logs() {
  log_info "Logs: $LOG_FILE"
  read -rp "➤ Delete Logs $LOG_FILE? [Y/n] : " CHOICE
  CHOICE="${CHOICE:-y}"
  if [[ "$CHOICE" == "y" ]]; then
    rm -f "$LOG_FILE"
    log_ok "Logs deleted."
  else
    log_info "Logs kept: $LOG_FILE"
  fi
}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Display system network information.

Options:
  -h, --help    Show this help message and exit 

Examples:
  $(basename "$0") --hardware

EOF
  exit 0
}

# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------

main() {
  local LOG_FILE
 
  print_banner
  # [[ "$1" == "-h" || "$1" == "--help" ]] && print_usage
  check_root
  check_dependencies

  LOG_FILE="/var/log/network_infos_$(date +%Y%m%d_%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1 

  gather_network_info 

  log_info "Date: $(date)"
  log_info "Hostname: $(hostname)"
  log_ok "✔ Full report completed: $LOG_FILE"
  cleanup_logs
}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
