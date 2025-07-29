#!/bin/bash

# ==============================================================================
# Script Name : scan-network-hosts-up.sh
# Description : Scanner Network Hosts Up
# Author      : netopsys (https://github.com/netopsys)
# License     : GPL-3.0 
# ==============================================================================

# set -euo pipefail
trap 'echo -e "\n${YELLOW}[WARN] Interrupted by user.${RESET}"; exit 1' SIGINT

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"
LOG_DIR='/tmp'
INTERFACE=""
MY_IP=""
NETWORK=""
LOG_FILE=""

# ------------------------------------------------------------------------------
# Log / Affichage
# ------------------------------------------------------------------------------
log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
usage() {
  echo "Usage: $(basename "$0")"
  exit 0
}

header_script() {
  echo "==========================================================="
  echo "🛡️  NETOPSYS - Bash Collections                            "
  echo "                                                           "
  echo "   Script : netopsys-scan-network-hosts-up.sh - Scanner Network Hosts Up      "
  echo "   Author : netopsys (https://github.com/netopsys)         "
  echo "==========================================================="
  echo
}

warning_script() {
  echo -e "${YELLOW}[!] Responsibility warning${RESET}"
  echo -e "--------------------------"
  echo -e "This script is provided for educational purposes and testing on systems you own"
  echo -e "or for which you have explicit authorization. Any unauthorized use"
  echo -e "may be illegal and lead to prosecution."
  echo -e "You are solely responsible for the use of this tool."
  read -rp "➤ Confirm you want to continue? (y/n): " CONFIRM

  if [[ "$CONFIRM" != "y" ]]; then
    log_warn "Operation aborted by user."
    exit 0
  fi
}

check_root() {
  [[ "$EUID" -ne 0 ]] && { log_error "Run this script as root."; exit 1; }
}

check_dependencies() {
  local deps=(ipcalc arp-scan nmap)
  local missing=()

  for cmd in "${deps[@]}"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  if (( ${#missing[@]} > 0 )); then
    log_error "Missing packages: ${missing[*]}"
    echo "To install them: sudo apt install ${missing[*]}"
    exit 1
  fi

  log_ok "All dependencies are installed."
}
get_interfaces() {
  ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo'
}

select_interface() {
  local interfaces
  interfaces=$(get_interfaces)

  if [[ -z "$interfaces" ]]; then
    log_error "No network interfaces found."
    exit 1
  fi

  log_info "Available interfaces:"
  echo "$interfaces" | while read -r iface; do
    log_info "- $iface"
  done

  read -rp "➤ Select an interface (ex: eth0): " INTERFACE
  if ! ip a show "$INTERFACE" &>/dev/null; then
    log_error "Invalid interface selected."
    exit 1
  fi
}

set_network_info() {
  MY_IP=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}' | cut -d'/' -f1)
  MY_IP_WITH_MASK=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}')
  NETWORK=$(ipcalc -n -b "$MY_IP_WITH_MASK" | awk '/Network:/ {print $2}')
  LOG_FILE="$LOG_DIR/$(date +'%Y%m%d_%H%M%S')_hosts_up.log"

  log_info "IP: $MY_IP"
  log_info "Network: $NETWORK"
}

scan_hosts_up() {
  log_info "Scanning for live hosts on $NETWORK..."
  arp-scan -I "$INTERFACE" -g "$NETWORK" -q |
    grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' |
    grep -v "$MY_IP" |
    tee "$LOG_FILE"
}

scan_ports() {
  while IFS= read -r ip; do
    log_info "Scanning host: $ip"
    local mac_info
    local open_ports

    mac_info=$(nmap -sn "$ip" | grep "MAC Address:" || echo "MAC: Unknown")
    open_ports=$(nmap -Pn -T4 --open "$ip" | grep -E "^[0-9]+/tcp\s+open")

    echo "$mac_info"
    echo "$open_ports"
  done < "$LOG_FILE"
}

cleanup_logs() {
  read -rp "➤ Delete log file $LOG_FILE? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    rm -f "$LOG_FILE"
    log_ok "Log file deleted."
  else
    log_info "Log file kept: $LOG_FILE"
  fi
}

# ------------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------------
main() {

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage ;; 
    esac
    shift
  done

  header_script
  warning_script
  check_root
  check_dependencies
  select_interface
  set_network_info

  read -rp "➤ Scan for live hosts? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    scan_hosts_up
  else
    log_warn "Scan skipped"
  fi

  read -rp "➤ Scan ports on discovered hosts? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    scan_ports
  else
    log_warn "Port scan skipped."
  fi

  cleanup_logs
}

main "$@"
