#!/bin/bash

# ==============================================================================
# Script Name : shellcheck-control.sh 
# Description : Check Quality Script Bash 
# Author      : netopsys (https://github.com/netopsys)
# License     : gpl-3.0
# ==============================================================================

set -euo pipefail
trap 'log_warn "Interrupted by user"; exit 1' SIGINT

# ============================================================================
# Variables
# ============================================================================
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly WHITE="\033[0;37m"
readonly RESET="\033[0m"

log()  { echo -e " ${WHITE}$*${RESET}" >&2; }
log_info()  { echo -e "   ${WHITE}[INFO]${RESET} $*" >&2; }
log_ok()    { echo -e "   ${GREEN}[OK]${RESET} $*" >&2; }
log_warn()  { echo -e "   ${YELLOW}[WARN]${RESET} $*" >&2; }
log_error() { echo -e "   ${RED}[ERROR]${RESET} $*" >&2; }
log_excellent()  { echo -e "   ${GREEN}[PERFECT]${RESET} $*" >&2; }

# ==============================================================================
# Functions 
# ==============================================================================
usage() {
  cat << EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help        Show this help message 
  <path_directory>  Path directory to check

Examples:
  $(basename "$0") --help 
  $(basename "$0") <path_directory> 

Requirements:
  - Must be run as root

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
  local dependencies=(shellcheck)
  local missing=()

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

score_to_grade() {
  local score=$1
  if (( score >= 90 )); then
    echo "5"
  elif (( score >= 75 )); then
    echo "4"
  elif (( score >= 50 )); then
    echo "3"
  elif (( score >= 25 )); then
    echo "2"
  else
    echo "1"
  fi
}

log_summary() {
  local score=$1
  local message=$2

  if (( score == 100 )); then
    log_ok "$message"
  else
    log_warn "$message"
  fi
}

log_section() {
  echo -e "\n$1"
}

check_shellcheck() {
  local file=$1
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck "$file" >/dev/null; then
      echo 100
    else
      echo 0
    fi
  else
    echo 50
  fi
}

# ============================================================================
# Main script logic
# ============================================================================
main() {

  if [[ $# -eq 0 ]]; then
    usage
  fi

  local DIR="$1"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage ;; 
    esac
    shift
  done
  
  echo "==========================================================="
  echo "🛡️  NETOPSYS - Bash Collections                            "
  echo "                                                           "
  echo "   Script : shellcheck-control - Check Quality Scripts Bash"
  echo "   Author : netopsys (https://github.com/netopsys)         "
  echo "==========================================================="
  echo

  check_root
  check_dependencies

  # Check is directory
  if [[ ! -d "$DIR" ]]; then
    echo -e "[ERROR] '$DIR' is not a valid directory."
    usage 
  fi

  # Get files
  mapfile -d '' sh_files < <(find "$DIR" -type f -perm /u+x \( -name "*.sh" -o -exec grep -Iq "/bin/bash" {} \; \) -print0)
  if [[ ${#sh_files[@]} -eq 0 ]]; then
    log_warn "No .sh files found in $DIR"
    exit 0
  fi

  local total_score=0
  local file_count=0
  local shellcheck_s=0

  # Check Quality Script Bash
  echo "Scan shellcheck : $DIR"
  for file in "${sh_files[@]}"; do 

    shellcheck_score=$(check_shellcheck "$file")
    
    # Calcul score and log résult
    sum=$(( shellcheck_s + shellcheck_score ))
    global_score=$(( sum / 1 ))
    log_summary "$global_score" "$(basename "$file")"

    total_score=$(( total_score + global_score ))
    file_count=$(( file_count + 1 ))
  done
  
  # Summary score for all scripts in folder
  if (( file_count > 0 )); then
    avg_score=$(( total_score / file_count ))
    avg_grade=$(score_to_grade "$avg_score")
    echo ""
    echo "===========================================================" 
    log_summary "$avg_score" "$DIR : score: $avg_score/100 - Level: $avg_grade"
    echo "==========================================================="
  fi

}

main "$@"
