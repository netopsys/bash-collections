#!/bin/bash
#
# ==============================================================================
# Script Name : packages_security_control.sh
# Description : Display installed or upgradable packages with version, dependencies and license info.
# Author      : netopsys (https://github.com/netopsys)
# License     : MIT
# Created     : 2025-07-25
# Updated     : 2025-07-25
# ==============================================================================
 
set -o pipefail

# ============================================================================
# Variables
# ============================================================================
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

declare -A LICENSE_COUNT
TOTAL_PACKAGES=0
TOTAL_INSTALLED_SIZE=0

# ============================================================================
# Functions
# ============================================================================
usage() {
  echo "Usage: $0 [--installed | --upgradable | --help]"
  exit 1
}

check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${YELLOW}[!] Command '$1' is not installed.${NC}"
    exit 1
  fi
}

get_license() {
  local pkg=$1
  local file="/usr/share/doc/$pkg/copyright"
  if [[ -f "$file" ]]; then
    local lic
    lic=$(grep -i '^License:' "$file" | head -1 | sed 's/License:\s*//I')
    if [[ -n "$lic" ]]; then
      echo "$lic"
      return
    fi
  fi
  echo "Unknown"
}

audit_package() {
  local pkg="$1"
  local info="$2"

  echo -e "\n📦 ${GREEN}Package:${NC} $pkg"

  local version architecture maintainer priority section homepage installed_size
  version=$(echo "$info" | cut -d'|' -f1)
  architecture=$(echo "$info" | cut -d'|' -f2)
  maintainer=$(echo "$info" | cut -d'|' -f3)
  priority=$(echo "$info" | cut -d'|' -f4)
  section=$(echo "$info" | cut -d'|' -f5)
  homepage=$(echo "$info" | cut -d'|' -f6)
  installed_size=$(echo "$info" | cut -d'|' -f7)
  status=$(echo "$info" | cut -d'|' -f8) 
  description=$(echo "$info" | cut -d'|' -f9)

  if [[ -z "$installed_size" ]]; then
    installed_size="Unknown"
  fi
  echo " - Version: $version"
  echo " - Architecture: $architecture"
  echo " - Maintainer: $maintainer"
  echo " - Priority: $priority"
  echo " - Section: $section"
  echo " - Homepage: $homepage"
  echo " - Installed-Size: ${installed_size} KB"
  echo " - Status: ${status}" 
  echo " - Description: ${description}"

  ((TOTAL_PACKAGES++))

    if [[ "$installed_size" =~ ^[0-9]+$ ]]; then
    ((TOTAL_INSTALLED_SIZE += installed_size))
    fi

  local license
  license=$(get_license "$pkg")
  echo " - License: $license"
  ((LICENSE_COUNT["$license"]++))

}

print_summary() {
  echo -e "\n📊 ${YELLOW}Summary:${NC}"
  echo "Total packages Installed: $TOTAL_PACKAGES"

  local size_gb
  size_gb=$(awk "BEGIN {printf \"%.2f\", $TOTAL_INSTALLED_SIZE / 1048576}")
  echo "Total Installed-Size: $TOTAL_INSTALLED_SIZE KB (~$size_gb GB)"

  echo -e "\n🔖 Top 10 licenses:"
  for lic in "${!LICENSE_COUNT[@]}"; do
    echo -e "${LICENSE_COUNT[$lic]}\t$lic"
  done | sort -rn | head -10 | awk -F'\t' '{printf " - %-25s %s packages\n", $2, $1}'
}

run_audit() {
  local mode="$1"
  declare -A PKG_INFO_MAP
  while IFS="|" read -r pkg ver arch maint maint_prio sec home size; do
    PKG_INFO_MAP["$pkg"]="$ver|$arch|$maint|$maint_prio|$sec|$home|$size"
  done < <(dpkg-query -W -f='${binary:Package}|${Version}|${Architecture}|${Maintainer}|${Priority}|${Section}|${Homepage}|${Installed-Size}|${Status}|${Description}\n')

  for pkg in "${pkgs[@]}"; do

    info="${PKG_INFO_MAP[$pkg]}"
    if [[ -z "$info" ]]; then
        echo -e "\n📦 ${YELLOW}Warning:${NC} Info not found for package '$pkg'"
        continue
    fi
    audit_package "$pkg" "$info"

  done

  print_summary
}

# ============================================================================
# Main script logic
# ============================================================================

case "$1" in
  --installed)
    echo -e "${GREEN}✔ Installed packages:${NC}"
    mapfile -t pkgs < <(dpkg-query -W -f='${binary:Package}\n' | sort)
    run_audit full
    ;;
  --upgradable)
    echo -e "${YELLOW}⇪ Upgradable packages:${NC}"
    mapfile -t pkgs < <(apt list --upgradable 2>/dev/null | grep -v "^Listing" | cut -d/ -f1)
    run_audit full
    ;;
  --help | *)
    usage
    ;;
esac
