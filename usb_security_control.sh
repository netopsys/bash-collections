#!/bin/bash
#
# ==============================================================================
# Script Name : usb_security_control.sh
# Description : USB security control — allows or blocks unauthorized USB devices.
# Author      : netopsys (https://github.com/netopsys)
# Version     : 1.1.0
# License     : MIT
# Created     : 2025-07-25
# Updated     : 2025-07-25
# ============================================================================

# Copyright (c) 2025 netopsys
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -euo pipefail
trap 'log_warn "Interrupted by user"; exit 1' SIGINT

# ============================================================================
# Colors & Logging
# ============================================================================
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }

# ============================================================================
# Functions
# ============================================================================
show_help() {
  cat << EOF
🛡️  USB Security Control — Manage USB access using USBGuard

Usage:
  $0 [options]

Options:
  -h, --help        Show this help message
  --dry-run         Only list USB devices, take no action
  --json            Output device list in JSON format

Examples:
  $0                Interactively allow/block USB devices
  $0 --dry-run      Just list USB devices
  $0 --json         Output JSON list for automation

Requirements:
  - Must be run as root
  - 'usbguard' must be installed
EOF
  exit 0
}

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "Please run this script as root."
    exit 1
  fi
}

check_dependencies() {
  local dependencies=(usbguard)
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

list_devices() {
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
    usbguard list-devices
  fi
}

interactive_mode() {
  log_info "Listing USB devices..."
  list_devices

  echo
  read -rp "👉 Action: Allow or Block device? (a/b): " CHOICE
  [[ "$CHOICE" =~ ^[ab]$ ]] || { log_error "Invalid choice"; exit 1; }

  read -rp "👉 Enter device ID: " DEVICE_ID
  read -rp "👉 Confirm $([[ $CHOICE == "a" ]] && echo allow || echo block) device ID $DEVICE_ID? (y/n): " CONFIRM

  if [[ "$CONFIRM" != "y" ]]; then
    log_warn "Operation aborted by user."
    exit 0
  fi

  if [[ "$CHOICE" == "a" ]]; then
    usbguard allow-device "$DEVICE_ID"
    log_ok "Device $DEVICE_ID allowed."
  else
    usbguard block-device "$DEVICE_ID"
    log_ok "Device $DEVICE_ID blocked."
  fi

  log_info "Operation complete."
}

# ============================================================================
# Main
# ============================================================================
main() {
  OUTPUT_JSON=false
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help ;;
      --json)    OUTPUT_JSON=true ;;
      --dry-run) DRY_RUN=true ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
    shift
  done

  check_root
  check_dependencies

  echo "==========================================================="
  echo "🛡️  USB Security Control — Manage USB Access with USBGuard"
  echo "==========================================================="
  echo "Author : netopsys (https://github.com/netopsys)"
  echo "Version: 1.1.0"
  echo "Date   : $(date +%Y-%m-%d)"
  echo "==========================================================="
  echo

  if [[ "$DRY_RUN" == true || "$OUTPUT_JSON" == true ]]; then
    list_devices
    exit 0
  fi

  interactive_mode
}

main "$@"