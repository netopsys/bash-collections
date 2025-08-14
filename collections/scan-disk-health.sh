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
log_error() { printf "[%s] [${RED}[ERROR]${RESET} %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
 

# ============================================================================
# Root check
# ============================================================================
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR]${NC} This script must be run as root (sudo)."
  exit 1
fi

print_banner
echo -e "${BLUE}[🔍]${NC} Detecting disks..."

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

echo ""
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
echo ""
read -rp "➤ Enter the name of the disk to analyze (e.g., sdb) : " DISK
DISK_PATH="/dev/$DISK"

echo -e "${BLUE}[🔍]${NC} Analyzing $DISK_PATH..."

# if [ ! -b "$DISK_PATH" ]; then
#   echo "[⛔] Disk $DISK_PATH does not exist."
#   exit 1
# fi

SECINFO=$(hdparm -I "$DISK_PATH" 2>/dev/null | grep -A20 "Security:")

echo ""
echo -e "${BLUE}[+]${NC} PARTITION TABLE TEST"
PART_INFO=$(parted -s "$DISK_PATH" print 2>&1)
if echo "$PART_INFO" | grep -q "unrecognised disk label"; then
  echo "$PART_INFO"
  echo -e "${RED}[⛔]${NC} No partition table detected."
else
  echo "$PART_INFO"
  echo -e "${GREEN}[OK]${NC} Partition table detected."
fi

echo ""
echo -e "${BLUE}[+]${NC} HDPARM TEST"
if check_disk_security "$SECINFO"; then
  echo ""
  echo "$SECINFO"
  echo -e "${GREEN}[OK]${NC} $(date +"%Y-%m-%d_%H%M%S") Disk $DISK is in an ideal security state."
else
  echo ""
  echo "Ideal desired state...
Security:
        Master password revision code = xxxxx
            supported
            enabled
            locked
        not frozen
        not expired: security count
            supported: enhanced erase
"
  echo "Current state of $DISK_PATH..."
  echo "$SECINFO"
  echo -e "${RED}[⛔]${NC} Disk $DISK_PATH is not in an ideal security state."
fi

# ============================================================================
# S.M.A.R.T. Test
# ============================================================================
echo ""
echo -e "${BLUE}[+]${NC} S.M.A.R.T TEST"
if smartctl -i "$DISK_PATH" &> /dev/null; then
  smartctl -i "$DISK_PATH"
  smart_status=$(smartctl -H "$DISK_PATH" | awk '/overall-health/ {print $NF}')
  
  if [[ "$smart_status" == "PASSED" ]]; then
    echo -e "${GREEN}[OK]${NC} SMART status: $smart_status"
  else
    echo -e "${RED}[⛔]${NC} SMART status: ISSUE ($smart_status)"
  fi
else
  echo "[⛔] SMART not supported on $DISK_PATH"
fi

# ============================================================================
# Disk usage check
# ============================================================================
if [ "$DISK_PATH" == "/dev/sda" ]; then
  echo ""
  echo -e "${BLUE}[+]${NC} DISK SPACE USAGE TEST"
  used_pct=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  if [ "$used_pct" -ge 90 ]; then
    echo -e "${RED}[⛔]${NC} Disk is almost full! (${used_pct}%)"
  else
    echo -e "${GREEN}[OK]${NC} Used space: ${used_pct}%"
  fi
fi

# ============================================================================
# Badblocks Scan (read-only)
# ============================================================================
echo ""
echo -e "${BLUE}[+]${NC} BAD BLOCKS TEST"
read -rp "➤ Scan for bad blocks (read-only, slow)? [y/N] : " CHOICE
CHOICE="${CHOICE:-n}" 
if [[ "$CHOICE" == "yes" ]]; then
  LOG="/tmp/badblocks_disk_${DISK}.log"
  badblocks -svn "$DISK_PATH" | tee -a "$LOG" 2>/dev/null

  if [ -s "$LOG" ]; then
    echo -e "${RED}[⛔]${NC} Bad blocks detected!"
    cat "$LOG"
  else
    echo -e "${GREEN}[OK]${NC} No bad blocks detected." | tee -a "$LOG"
  fi
else
  echo -e "${ORANGE}[Skipped]${NC}"
fi

# ============================================================================
# Done
# ============================================================================
echo ""
echo -e "${GREEN}✅ Analysis of $DISK_PATH completed.${NC}"
