#!/bin/bash

# ==============================================================================
# Module : scan-shellcheck.sh 
# Description : TOOLS - Shellcheck audit
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
  printf "%s\n" "==========================================================="
  printf "%s\n" "🛡️  NETOPSYS - TOOLS - Shellcheck audit                     " 
  printf "%s\n" "==========================================================="
  printf "\n"
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
readonly CYAN='\033[0;36m'
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m" 
readonly RESET="\033[0m"

log_info()  { printf "[%s] ${CYAN}[INFO]${RESET} %s\n"  "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_ok()    { printf "[%s] ${GREEN}[OK]${RESET}   %s\n"  "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_warn()  { printf "[%s] ${YELLOW}[WARN]${RESET} %s\n"  "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_error() { printf "[%s] [${RED}[ERROR]${RESET} %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Please run this script as root."
    exit 1
  fi
}

check_dependencies() {
  if ! command -v shellcheck >/dev/null 2>&1; then
    log_error "Missing required tool: shellcheck"
    printf "\nTo install it:\n  sudo apt install shellcheck\n"
    exit 1
  fi
}

score_to_grade() {
  score=$1
  if [ "$score" -ge 90 ]; then
    printf "⭐⭐⭐⭐⭐\n"
  elif [ "$score" -ge 75 ]; then
    printf "⭐⭐⭐⭐☆\n"
  elif [ "$score" -ge 50 ]; then
    printf "⭐⭐⭐☆☆\n"
  elif [ "$score" -ge 25 ]; then
    printf "⭐⭐☆☆☆\n"
  else
    printf "⭐☆☆☆☆\n"
  fi
}

log_summary() {
  score=$1
  message=$2

  if [ "$score" -eq 100 ]; then
    log_ok "$message"
  else
    log_warn "$message"
  fi
}

check_shellcheck() {
  file=$1
  if shellcheck -S warning "$file" >/dev/null 2>&1; then
    echo 100
  else
    echo 0
  fi
}

suggest_common_fixes() {
  local service="$1" 
  echo "1. Restart the service: sudo systemctl restart $service"
  echo "2. Reload unit files: sudo systemctl daemon-reexec"
  echo "3. Reinstall package: sudo apt reinstall <package>"
  echo "4. Purge config (if corrupted): mv ~/.config/$service ~/.config/${service}.bak"
  echo "5. Enable at boot: sudo systemctl enable $service"
}

# ------------------------------------------------------------------------------
# Print usage help.
# ------------------------------------------------------------------------------
print_usage() { 
  printf "Usage: %s [options]\n\n" "./$(basename "$0")"
  printf "Options:\n"
  printf "  -h, --help        Show this help message\n"
  printf "  -p, --path        Path directory to check\n\n"
  printf "Examples:\n"
  printf "  %s --help\n" "./$(basename "$0")"
  printf "  %s -p <path_directory>\n\n" "./$(basename "$0")"
  exit 0
}

# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------

main() {

  print_banner

  if [ "$#" -lt 2 ]; then
    print_usage
  fi

  DIR=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--path)
        if [ -n "${2-}" ]; then
          DIR=$2
          shift 2
        else
          log_error "Option $1 requires an argument."
          print_usage
        fi
        ;;
      -h|--help)
        print_usage
        ;;
      -d|--debug) DEBUG=1; set -x; shift ;;
      *)
        log_error "Unknown option: $1"
        print_usage
        ;;
    esac
  done
  check_root
  check_dependencies

  if [ ! -d "$DIR" ]; then
    log_error "'$DIR' is not a valid directory."
    print_usage
  fi

  total_score=0
  file_count=0
  shellcheck_s=0
  COUNT=0

  log_info "Shellcheck $DIR"

  # Manual file loop (POSIX find + test if executable + contains shebang or .sh)
  find "$DIR" -type f | while IFS= read -r file; do
    if [ -x "$file" ]; then
      case "$file" in
        *.md) continue ;;
      esac

      if grep -q "^#\!.*sh" "$file" 2>/dev/null || echo "$file" | grep -q '\.sh$'; then
        shellcheck_score=$(check_shellcheck "$file")
        COUNT=$((COUNT + 1))
        global_score=$((shellcheck_s + shellcheck_score))
        log_summary "$global_score" "$(basename "$file")"

        total_score=$((total_score + global_score))
        file_count=$((file_count + 1))
      fi
    fi
  done

  if [ "$file_count" -gt 0 ]; then
    avg_score=$(( total_score / file_count ))
    avg_grade=$(score_to_grade "$avg_score")
    printf "\n"
    printf "%s\n" "-----------------------------------------------------------"
    log_summary "$avg_score" "score: $avg_score/100 - Level: $avg_grade"
    printf "%s\n" "-----------------------------------------------------------"
  fi
}

main "$@"

