#!/bin/bash

# ==============================================================================
# Module : scan-hardware.sh
# Description : SYSTEM   - Scan Hardware infos
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
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - SYSTEM - Scan Hardware infos"
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
separator() { echo -e "--------------------------------------------------------"; }

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
  
gather_hardware_info() {
  log_info "==== 🖥️  HARDWARE INFORMATION ===="
  separator

  log_info "DMI Decode (Motherboard, BIOS, etc.)"
  sudo dmidecode | grep -A5 'System Information'
  separator

  log_info "Processor information (lscpu)"
  lscpu | grep -E 'Model name|Socket|Thread|CPU\(' 
  separator

  log_info "Memory (free -h)"
  free -h
  separator

  log_info "Disks (lsblk)"
  lsblk
  separator

  log_info "Sensors (sensors)"
  sensors
  separator

  log_info "PCI Devices (lspci)"
  lspci | grep -E 'VGA|3D|Ethernet'
  separator

  log_info "Detailed hardware info (lshw)"
  lshw -short
  separator
}

cleanup_logs() { 
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

Display system hardware and network information.

Options:
  -h, --help    Show this help message and exit 

Examples:
  $(basename "$0") 

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

  LOG_FILE="/var/log/hardware_infos_$(date +%Y%m%d_%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1 

  gather_hardware_info  

  log_info "Date: $(date)"
  log_info "Hostname: $(hostname)"
  log_info "Log: $LOG_FILE"

  cleanup_logs
}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
