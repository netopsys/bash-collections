#!/bin/bash

# ==============================================================================
# Script      : devices-info.sh
# Description : Display detailed Android device information via ADB
# Author      : netopsys
# License     : GPL-3.0
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() { 
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - Bash Collections          "
  echo "                                                           "
  echo "   Script : Android device infos via ADB                   "
  echo "   Author : netopsys (https://github.com/netopsys)         "
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
 
log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; } 
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }

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
  local dependencies=(adb)
  local missing=()

  log_info "Checking dependencies..."

  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    log_error "Missing packages: ${missing[*]}"
    echo -e "\nTo install them:\n  sudo apt install ${missing[*]}"
    exit 1
  else
    log_ok "All dependencies are met."
  fi
}

adb_getprop() {
  adb -s "$device" shell getprop "$1" 2>/dev/null | tr -d '\r'
}

# Print usage help.
print_usage() {
  echo "Usage: $(basename "$0")"
  exit 0
}
# ------------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------------
main() {

  if [[ $# -gt 0 ]]; then
    print_usage
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_usage ;; 
    esac
    shift
  done
  
  print_banner
  check_root
  check_dependencies
 
  DEVICE_IDS=$(adb devices | awk 'NR>1 && $2 == "device" {print $1}' || true)
  if [[ -z "$DEVICE_IDS" ]]; then
      log_warn "No Android device connected. Enable USB debugging."
      exit 1
  fi

  # Boucle sur chaque appareil connecté
  for device in $DEVICE_IDS; do
    log_info "Device detected: $device"

    log_info "Model               : $(adb_getprop ro.product.model)"
    log_info "Codename            : $(adb_getprop ro.product.device)"
    log_info "Android Version     : $(adb_getprop ro.build.version.release)"
    log_info "Security Patch      : $(adb_getprop ro.build.version.security_patch)"
    log_info "Manufacturer        : $(adb_getprop ro.product.manufacturer)"
    log_info "CPU Architecture    : $(adb_getprop ro.product.cpu.abi)"
    log_info "Screen Size         : $(adb -s "$device" shell wm size 2>/dev/null | awk '{print $3}')"
    log_info "Battery Level       : $(adb -s "$device" shell dumpsys battery | awk '/level/ {print $2}')%"
    log_info "Charging Status     : $(adb -s "$device" shell dumpsys battery | awk -F': ' '/status/ {print $2}' | xargs)"
    log_info "Uptime              : $(adb -s "$device" shell uptime -p 2>/dev/null | tr -d '\r')"
    log_info "User(s)             : $(adb -s "$device" shell pm list users | grep 'UserInfo' || echo "(none)")" 
    log_info "Root Access         : $(adb -s "$device" shell su -c id 2>/dev/null || echo "No root access")"
    log_info "Storage info          : $(adb -s "$device" shell df || warn "Could not retrieve storage info")"  
    log_info "Apps System:"
    adb -s "$device" shell pm list packages -s | cut -d: -f2 | sort | sed 's/^/System ➤ /'

    log_info "Apps User:"
    adb -s "$device" shell pm list packages -3 | cut -d: -f2 | sort | sed 's/^/User ➤ /'
  done
  exit 0
}

main "$@"