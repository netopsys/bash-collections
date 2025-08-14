#!/bin/bash

# ==============================================================================
# Module : scan-recon-enum.sh
# Description : SECURITY - Pentest recon phases on a network target
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
  echo -e "${CYAN}"
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - SECURITY - Pentest recon phases on a network target"
  echo "==========================================================="
  echo -e "${RESET}"
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"
 
log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }
section()   { echo -e "---------------------- ${YELLOW}$*${RESET} -----------------------------------"; }

# ------------------------------------------------------------------------------
# Constantes & Variables
# ------------------------------------------------------------------------------
target=""
log_enabled=false
output_dir=""
ip_target=""

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

warning_script() {
  echo -e "${YELLOW}[!] Responsibility warning${RESET}"
  echo -e "--------------------------"
  echo -e "This script is provided for educational purposes and testing on systems you own"
  echo -e "or for which you have explicit authorization. Any unauthorized use"
  echo -e "may be illegal and lead to prosecution."
  echo -e "You are solely responsible for the use of this tool."
  read -rp "➤ Confirm you want to continue? [Y/n] : " CHOICE
  CHOICE="${CHOICE:-y}"

  if [[ "$CHOICE" != "y" ]]; then
    log_warn "Operation aborted by user."
    exit 0
  fi
}

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "Please run this script as root."
    exit 1
  fi
}

check_dependencies() {
  local dependencies=(whois geoiplookup host nslookup dig ping traceroute)
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

start_script() {
  if [[ "$log_enabled" == true ]]; then
    output_dir="/tmp/$(date +'%Y%m%d-%H%M%S')-report-pentest-recon"
    mkdir -p "$output_dir"
    log_info "Logging enabled: $output_dir"
  fi
  log_info "Target: $target"
}

resume_script() {
  log_info "Reconnaissance completed."
  [[ "$log_enabled" == true ]] && log_info "Results available in: $output_dir"
}

check_whois() {
  section "WHOIS"
  if [[ "$log_enabled" == true ]]; then
    whois "$target" | grep -v "#" | head -10 | tee -a "$output_dir/whois.log" 2>/dev/null
  else
    whois "$target" | grep -v "#" | head -10 2>/dev/null
  fi
}

check_geoip() {
  section "Geoip"
  if [[ "$log_enabled" == true ]]; then
    geoiplookup "$target" | tee -a "$output_dir/geoip.log" 2>/dev/null
  else
    geoiplookup "$target" 2>/dev/null
  fi
}

check_dns() {
  section "DNS"
  local ip=""
  {
    host "$target"
    nslookup "$target"
    dig "$target" ANY +short
    dig "$target" ANY +noall +CHOICE
    dig A "$target" +short
    dig MX "$target" +short
    dig NS "$target" +short
    dig -x "$target" +short
  } | tee >(if [[ "$log_enabled" == true ]]; then tee -a "$output_dir/dns.log" > /dev/null; fi)

  ip=$(dig +short "$target" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
  [[ -z "$ip" ]] && ip="$target"
  echo "$ip"
  ip_target="$ip"
}

check_ping() {
  section "Ping"
  if [[ "$log_enabled" == true ]]; then
    ping -c 3 "$1" | tee -a "$output_dir/ping.log" 2>/dev/null
  else
    ping -c 3 "$1" 2>/dev/null
  fi
}

check_traceroute() {
  section "Traceroute"
  if [[ "$log_enabled" == true ]]; then
    traceroute -n "$1" | tee -a "$output_dir/traceroute.log" 2>/dev/null
  else
    traceroute -n "$1" 2>/dev/null
  fi
}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  cat << EOF
Usage:
  $(basename "$0") -t <target> [--log]
  $(basename "$0") -h | --help

Options:
  -t, --target <target>  Target.
  --log                  Enables result logging into /tmp/<timestamp>_report_pentest_reconnaissance
  -h, --help             Show this help message.

Examples:
  $(basename "$0") -t example.com
  $(basename "$0") --target example.com --log
EOF
  exit 0
}
# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------
main() {
  print_banner

  if [[ $# -eq 0 ]]; then
    log_error "Missing Options"
    print_usage
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --log)
        log_enabled=true
        shift
        ;;
      -t|--target)
        if [[ -n "$2" ]]; then
          target="$2"
          shift 2
        else
          log_error "Option $1 requires an argument."
          print_usage
        fi
        ;;
      -h|--help)
        print_usage
        ;;
      *)
        log_error "Unknown option: $1"
        print_usage
        ;;
    esac
  done

  if [[ -z "$target" ]]; then
    log_error "Missing target."
    print_usage
  fi

  check_root
  check_dependencies  
  warning_script
  start_script
  check_whois
  check_geoip
  check_dns
  check_ping "$ip_target"
  check_traceroute "$ip_target"
  resume_script
}

main "$@"
