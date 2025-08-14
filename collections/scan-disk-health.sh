#!/bin/bash

# ==============================================================================
# Module : scan-disk-health.sh
# Description : DISK - Show Disk health infos
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
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - DISK - Show Disk health infos  "
  echo "==========================================================="  
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
log_error() { printf "[%s] ${RED}[ERROR]${RESET} %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
 

# ============================================================================
# Root check
# ============================================================================
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR]${RESET} This script must be run as root (sudo)."
  exit 1
fi

print_banner
log_info "Detecting disks..."

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
convert_size() {
  local size=$1
  if (( size >= 1073741824 )); then
    awk "BEGIN { printf \"%.1fGB\", $size/1073741824 }"
  elif (( size >= 1048576 )); then
    awk "BEGIN { printf \"%.1fMB\", $size/1048576 }"
  elif (( size >= 1024 )); then
    awk "BEGIN { printf \"%.1fKB\", $size/1024 }"
  else
    echo "${size}B"
  fi
}

check_disk_security() {
  echo "$1" | grep -qE "^\s+enabled"              || return 1
  echo "$1" | grep -qE "^\s+locked"               || return 1
  echo "$1" | grep -qE "^\s+not\s+frozen"         || return 1
  echo "$1" | grep -qE "^\s+supported"            || return 1
  echo "$1" | grep -qE "^\s+supported: enhanced erase" || return 1
  return 0
}

# ============================================================================
# Disk listing
# ============================================================================
echo "#1"
lsblk -o MODEL,TYPE,NAME,FSTYPE,UUID,SIZE,FSAVAIL,FSUSE%,RO,MOUNTPOINT

echo "#2"
for disk in /sys/block/sd*; do
  name=$(basename "$disk")
  sys="/sys/block/$name"

  # Detect type (SSD / HDD)
  if [[ -f "$sys/queue/rotational" ]]; then
    rot=$(cat "$sys/queue/rotational")
    type=$([[ "$rot" == "0" ]] && echo "SSD" || echo "HDD")
  else
    type="Unknown"
  fi

  # Detect bus type
  if udevadm info --query=property --name="/dev/$name" | grep -q "ID_BUS=usb"; then
    bus="USB"
  elif [[ "$name" == nvme* ]]; then
    bus="NVMe"
  else
    bus="SATA/SCSI"
  fi

  size=$(lsblk -bdn -o SIZE "/dev/$name")
  size=$(convert_size "$size")
  model=$(cat "$sys/device/model" 2>/dev/null || echo "-")

  echo "/dev/$name : $size - $type ($bus) - $model - rotational $rot"
done

# ============================================================================
# Analysis
# ============================================================================
read -rp "➤ Enter the name of the disk to analyze (e.g., sdb) : " DISK
DISK_PATH="/dev/$DISK"

log_info "Analyzing $DISK_PATH..."

# if [ ! -b "$DISK_PATH" ]; then
#   echo "[⛔] Disk $DISK_PATH does not exist."
#   exit 1
# fi

SECINFO=$(hdparm -I "$DISK_PATH" 2>/dev/null | grep -A20 "Security:")

log_info "PARTITION TABLE TEST"
PART_INFO=$(parted -s "$DISK_PATH" print 2>&1)
if echo "$PART_INFO" | grep -q "unrecognised disk label"; then
  log_info "$PART_INFO"
  log_error "No partition table detected."
else
  log_info "$PART_INFO"
  log_ok "Partition table detected."
fi

log_info "HDPARM TEST"
if check_disk_security "$SECINFO"; then
  log_info "$SECINFO"
  log_ok "Disk $DISK is in an ideal security state."
else

  log_info "Ideal desired state...
Security:
        Master password revision code = xxxxx
            supported
            enabled
            locked
        not frozen
        not expired: security count
            supported: enhanced erase
"
  log_info "Current state of $DISK_PATH..."
  log_info "$SECINFO"
  log_error "Disk $DISK_PATH is not in an ideal security state."
fi

# ============================================================================
# S.M.A.R.T. Test
# ============================================================================
log_info "S.M.A.R.T TEST"
if smartctl -i "$DISK_PATH" &> /dev/null; then
  smartctl -i "$DISK_PATH"
  smart_status=$(smartctl -H "$DISK_PATH" | awk '/overall-health/ {print $NF}')
  
  if [[ "$smart_status" == "PASSED" ]]; then
    log_ok "SMART status: $smart_status"
  else
    log_error "SMART status: ISSUE ($smart_status)"
  fi
else
  log_error "SMART not supported on $DISK_PATH"
fi

# ============================================================================
# Disk usage check
# ============================================================================
if [ "$DISK_PATH" == "/dev/sda" ]; then
  log_info "DISK SPACE USAGE TEST"
  used_pct=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  if [ "$used_pct" -ge 90 ]; then
    log_error "Disk is almost full! (${used_pct}%)"
  else
    log_ok "Used space: ${used_pct}%"
  fi
fi

# ============================================================================
# Badblocks Scan (read-only)
# ============================================================================
log_info "BAD BLOCKS TEST"
read -rp "➤ Scan for bad blocks (read-only, slow)? [y/N] : " CHOICE
CHOICE="${CHOICE:-n}" 
if [[ "$CHOICE" == "yes" ]]; then
  LOG="/tmp/badblocks_disk_${DISK}.log"
  badblocks -svn "$DISK_PATH" | tee -a "$LOG" 2>/dev/null

  if [ -s "$LOG" ]; then
    log_error "Bad blocks detected!"
    cat "$LOG"
  else
    log_ok "No bad blocks detected." | tee -a "$LOG"
  fi
else
  log_warn "[Skipped] BAD BLOCKS TEST"
fi

# ============================================================================
# Done
# ============================================================================
log_ok "Analysis of $DISK_PATH completed."
