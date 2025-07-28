#!/bin/bash
#
# ==============================================================================
# Script Name : packages_control.sh
# Description : Display installed or upgradable packages with version, dependencies and license info, list top 20 licenses.
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
readonly YELLOW="\033[1;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m" 

log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }

declare -A LICENSE_COUNT=0
declare -A TOTAL_PACKAGES=0
declare -A TOTAL_SIZE=0
# ============================================================================
# Functions
# ============================================================================
usage() {
  echo "Usage: $0 [--installed | --upgradable | --debug | --help]"
  exit 0
}

check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${YELLOW}[!] Command '$1' is not installed.${RESET}"
    exit 1
  fi
}

get_license() {
  local pkg=$1
  local file="/usr/share/doc/$pkg/copyright"
  if [[ -f "$file" ]]; then
    if [[ -n "$(grep -i '^License:' "$file" | head -1 | sed 's/License:\s*//I')" ]]; then
      echo -e "$(grep -i '^License:' "$file" | head -1 | sed 's/License:\s*//I')"
      return
    fi
  fi
  echo "Unknown"
}

audit_package() {
  local pkg="$1"
  local info="$2"

  echo -e "\n📦 ${GREEN}Package:${RESET} $pkg"
  echo " - Version: $(echo "$info" | cut -d'|' -f1)"
  echo " - Architecture: $(echo "$info" | cut -d'|' -f2)"
  echo " - Maintainer: $(echo "$info" | cut -d'|' -f3)"
  echo " - Priority: $(echo "$info" | cut -d'|' -f4)"
  echo " - Section: $(echo "$info" | cut -d'|' -f5)"
  echo " - Homepage: $(echo "$info" | cut -d'|' -f6)"
  echo " - Installed-Size: $(echo "$info" | cut -d'|' -f7) KB"
  echo " - Status: $(echo "$info" | cut -d'|' -f8)" 
  echo " - Description: $(echo "$info" | cut -d'|' -f9)"

  ((TOTAL_PACKAGES +=1))

  if [[ "$(echo "$info" | cut -d'|' -f7)" =~ ^[0-9]+$ ]]; then
    ((TOTAL_SIZE += $(echo "$info" | cut -d'|' -f7)))
  fi

  echo " - License: $(get_license "$pkg")"
  ((LICENSE_COUNT["$(get_license "$pkg")"]+=1))

}

print_summary() {
  echo -e "\n📊 ${YELLOW}Summary:${RESET}"
  echo "Package(s): $TOTAL_PACKAGES"
  echo "Size: $TOTAL_SIZE KB (~$(awk "BEGIN {printf \"%.2f\", $TOTAL_SIZE / 1048576}") GB)"

  echo -e "\n🔖 Top 10 licenses:"
  for pkg_license in "${!LICENSE_COUNT[@]}"; do
    echo -e "${LICENSE_COUNT[$pkg_license]}\t$pkg_license"
  done | sort -rn | head -10 | awk -F'\t' '{printf " - %-25s %s packages\n", $2, $1}'
}

run_audit() { 
  declare -A PKG_INFO_MAP
  while IFS="|" read -r pkg ver arch maint maint_prio sec home size status descr; do
    PKG_INFO_MAP["$pkg"]="$ver|$arch|$maint|$maint_prio|$sec|$home|$size|$status|$descr"
  done < <(dpkg-query -W -f='${binary:Package}|${Version}|${Architecture}|${Maintainer}|${Priority}|${Section}|${Homepage}|${Installed-Size}|${Status}|${Description}\n')

  for pkg in "${pkgs[@]}"; do

    if [[ -z "${PKG_INFO_MAP[$pkg]}" ]]; then
        echo -e "\n📦 ${YELLOW}Warning:${RESET} Info not found for package '$pkg'"
        continue
    fi
    audit_package "$pkg" "${PKG_INFO_MAP[$pkg]}"
  done

  print_summary
}

# ============================================================================
# Main script logic
# ============================================================================
main() {

echo "==========================================================="
echo "🛡️  NETOPSYS - Bash Collections                            "
echo "                                                           "
echo "   Script : packages-control - Display infos packages      "
echo "   Author : netopsys (https://github.com/netopsys)         "
echo "==========================================================="
echo

case "$1" in
  --installed)
    echo -e "${YELLOW}Installed packages:${RESET}"
    mapfile -t pkgs < <(dpkg-query -W -f='${binary:Package}\n' | sort)
    run_audit 
    ;;
  --upgradable)
    echo -e "${YELLOW}Upgradable packages:${RESET}"
    mapfile -t pkgs < <(apt list --upgradable 2>/dev/null | grep -v "^Listing" | cut -d/ -f1)
    run_audit  
    ;;
  --debug)
    set -x
    echo -e "${YELLOW}Installed packages:${RESET}"
    mapfile -t pkgs < <(dpkg-query -W -f='${binary:Package}\n' | sort)
    run_audit "--installed" 
    ;;
  -h|--help | *)
    usage
    ;;
esac

}

main "$@"
