#!/bin/bash

# ==============================================================================
# Module : scan-process-by-id.sh
# Description : SYSTEM   - Scan process monitoring 
# Author      : netopsys (https://github.com/netopsys)
# License     : GPL-3.0
# ==============================================================================

#DEBUG=1
# set -euo pipefail
# [ -n "${DEBUG:-}" ] && set -x
IFS=$'\n\t'

# ------------------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------------------
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"

log_info()  { printf "%s ${CYAN}[INFO]${RESET} %s\n"  "$(date +'%F %T')" "$*"; }
log_ok()    { printf "%s ${GREEN}✔${RESET} %s\n"    "$(date +'%F %T')" "$*"; }
log_warn()  { printf "%s ${YELLOW}[WARN]${RESET} %s\n" "$(date +'%F %T')" "$*"; }
log_error() { printf "%s ${RED}[ERROR]${RESET} %s\n" "$(date +'%F %T')" "$*"; }

# ------------------------------------------------------------------------------
# Globals
# ------------------------------------------------------------------------------
LOG_DIR="/var/log"
PID=""
SCRIPT_NAME=$(basename "$0")

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  cat << EOF
Usage: $SCRIPT_NAME [--pid <PID>]

Options:
  --pid <PID>    Monitor specific process ID directly
  -h, --help     Show this help message

Interactive mode will be used if no PID is provided.
EOF
  exit 0
}

# ------------------------------------------------------------------------------
# Dependency check
# ------------------------------------------------------------------------------
check_dependencies() {
  local deps=(ps lsof ss strace timeout watch)
  local missing=()

  for d in "${deps[@]}"; do
    command -v "$d" >/dev/null 2>&1 || missing+=("$d")
  done

  if (( ${#missing[@]} > 0 )); then
    log_error "Missing dependencies: ${missing[*]}"
    echo "Install them (Debian/Ubuntu): apt install ${missing[*]}"
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# Trap cleanup
# ------------------------------------------------------------------------------
cleanup() {
  log_warn "Interrupted by user, exiting..."
  exit 130
}
trap cleanup INT TERM

# ------------------------------------------------------------------------------
# Process selection
# ------------------------------------------------------------------------------
select_process() {
  log_info "Listing active processes..."
  ps aux # | less

  read -rp "➤ Enter process name or PID to monitor: " input
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    PID="$input"
  else
    PID=$(pgrep -f "$input" | head -n 1 || true)
  fi

  if [[ -z "$PID" ]]; then
    log_error "No process found for \"$input\""
    exit 1
  fi

  log_ok "Process detected: PID=$PID"
}

# ------------------------------------------------------------------------------
# Monitoring actions
# ------------------------------------------------------------------------------
monitor_realtime() {
  read -rp "➤ Watch process in real time with 'ps'? [Y/n] " choice
  choice="${choice:-y}"
  if [[ "$choice" == "y" ]]; then
    log_info "Ctrl+C to exit watch mode"
    watch -n 1 "ps -p $PID -o pid,%cpu,%mem,etime,stat,cmd"
  fi
}

show_files() {
  read -rp "➤ Show open files (lsof)? [Y/n] " choice
  choice="${choice:-y}"
  if [[ "$choice" == "y" ]]; then
    lsof -p "$PID" 2>/dev/null 
  fi
}

show_network() {
  read -rp "➤ Show network connections? [Y/n] " choice
  choice="${choice:-y}"
  if [[ "$choice" == "y" ]]; then
    log_info "Active connections (ESTABLISHED):"
    lsof -nPi -p "$PID" 2>/dev/null | grep "$PID" || true

    log_info "Additional details with ss:"
    ss -p | grep "pid=$PID" || true
  fi
}

trace_syscalls() {
  read -rp "➤ Trace syscalls with strace for 10s? [Y/n] " choice
  choice="${choice:-y}"
  if [[ "$choice" == "y" ]]; then
    timeout 10 strace -p "$PID"
  fi
}

trace_process_monitor() {

  TS=$(date +"%Y%m%d_%H%M%S")
  ps -eo pid,ppid,uid,user,pcpu,pmem,state,stat,priority,psr,f,stime,etime,comm,cmd --no-headers \
    | awk 'BEGIN{OFS="|"} {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15}' \
    | jq -R -s -c '
      split("\n")[:-1] 
      | map(split("|")) 
      | map({
          pid: .[0],
          ppid: .[1],
          uid: .[2],
          user: .[3],
          pcpu: .[4],
          pmem: .[5],
          state: .[6],
          stat: .[7],
          priority: .[8],
          psr: .[9],
          f: .[10],
          stime: .[11],
          etime: .[12],
          comm: .[13],
          cmd: .[14]
      })' | jq "." | tee -a "$LOG_DIR/process_monitor_$TS.log"
}


save_logs() {
  read -rp "➤ Save logs to $LOG_DIR ? [Y/n] " choice
  choice="${choice:-y}"
  if [[ "$choice" == "y" ]]; then
    mkdir -p "$LOG_DIR"
    TS=$(date +"%Y%m%d_%H%M%S")

    lsof -p "$PID" > "$LOG_DIR/process_monitor_lsof_${PID}_$TS.log" 2>/dev/null 
    lsof -nPi -p "$PID" | grep ESTABLISHED > "$LOG_DIR/process_monitor_net_${PID}_$TS.log" || true
    timeout 10 strace -p "$PID" -o "$LOG_DIR/process_monitor_strace_${PID}_$TS.log"
    trace_process_monitor

    log_ok "Logs saved in $LOG_DIR/process_monitor_*.log"
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
  check_dependencies

  if [[ $# -gt 0 ]]; then
    case "$1" in
      -h|--help) print_usage ;;
      --pid) PID="$2"; shift 2 ;;
      *) print_usage ;;
    esac
  fi

  [[ -z "$PID" ]] && select_process

  # monitor_realtime
  show_files
  show_network
  trace_syscalls
  save_logs
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
