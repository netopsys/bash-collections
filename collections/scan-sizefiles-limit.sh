#!/bin/bash

# ==============================================================================
# Module : scan-sizefiles-limit.sh
# Description : DISK - Scan files metadata size limit
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
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - DISK - Scan files metadata size limit"
  echo "===========================================================" 
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RESET='\033[0m' 

log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }

# ------------------------------------------------------------------------------
# Human-Readable Size Conversion
# ------------------------------------------------------------------------------
convert_size() {
  local size=$1
  if (( size >= 1073741824 )); then
    awk "BEGIN { printf \"%.1fGiB\", $size/1073741824 }"
  elif (( size >= 1048576 )); then
    awk "BEGIN { printf \"%.1fMiB\", $size/1048576 }"
  elif (( size >= 1024 )); then
    awk "BEGIN { printf \"%.1fKiB\", $size/1024 }"
  else
    echo "${size}B"
  fi
}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
print_usage() {
  echo -e "
${CYAN}Usage:${RESET} $(basename "$0") <DIRECTORY> <EXTENSION>

Checks for file size limits for a given extension in a directory.

Arguments:
  DIRECTORY   Path to directory to scan
  EXTENSION   File extension to filter (e.g., .log, .mp4)

Example:
  $(basename "$0") /var/log .log

Options:
  -h, --help     Show this help and exit
"
  exit 0
}

# ------------------------------------------------------------------------------
# Constantes & Variables
# ------------------------------------------------------------------------------
declare -A EXT_LIMITS=(
  [".pdf"]=10000000 [".doc"]=10000000 [".docx"]=25000000 [".odt"]=15000000
  [".xls"]=15000000 [".xlsx"]=25000000 [".ods"]=15000000 [".ppt"]=25000000
  [".pptx"]=25000000 [".rtf"]=5000000 [".txt"]=10000000 [".md"]=10000000 [".log"]=100000000

  [".jpg"]=10000000 [".jpeg"]=10000000 [".png"]=10000000 [".gif"]=5000000
  [".tiff"]=15000000 [".tif"]=15000000 [".webp"]=8000000 [".raw"]=25000000
  [".cr2"]=25000000 [".nef"]=25000000 [".orf"]=25000000 [".heic"]=15000000 [".svg"]=5000000

  [".mp4"]=4000000000 [".mkv"]=4000000000 [".avi"]=2000000000 [".mov"]=2000000000
  [".wmv"]=2000000000 [".flv"]=1000000000 [".webm"]=1000000000

  [".mp3"]=10000000 [".wav"]=100000000 [".flac"]=50000000 [".aac"]=15000000
  [".ogg"]=15000000 [".wma"]=15000000 [".m4a"]=15000000

  [".zip"]=2000000000 [".rar"]=2000000000 [".7z"]=2000000000 [".tar"]=2000000000
  [".gz"]=2000000000 [".tgz"]=2000000000 [".bz2"]=2000000000 [".xz"]=2000000000
  [".iso"]=4000000000 [".img"]=4000000000

  [".py"]=5000000 [".js"]=5000000 [".ts"]=5000000 [".sh"]=1000000 [".bat"]=1000000
  [".php"]=5000000 [".rb"]=5000000 [".go"]=10000000 [".rs"]=10000000
  [".html"]=5000000 [".css"]=2000000 [".scss"]=2000000
)
 

# ------------------------------------------------------------------------------
# Validate Input Arguments
# ------------------------------------------------------------------------------
validate_args() {
  local dir=$1
  local ext=$2
  if [[ ! -d "$dir" ]]; then
    log_error "Directory '$dir' does not exist."
    exit 1
  fi

  if [[ -z "${EXT_LIMITS[$ext]+_}" ]]; then
    log_warn "No size limit defined for '$ext'. Skipping size check."
  fi
}

# ------------------------------------------------------------------------------
# Check Files Against Limit
# ------------------------------------------------------------------------------
check_limits() {
  local dir=$1
  local ext=$2
  local limit="${EXT_LIMITS[$ext]:-0}"

  log_info "Checking files with extension '$ext' in $dir"

  mapfile -d '' files < <(find "$dir" -type f -name "*$ext" -print0 2>/dev/null)
  log_info "Total files found: ${#files[@]}"

  for file in "${files[@]}"; do
    ((TOTAL_FILES +=1))
    size=$(stat -c%s "$file")
    sz_human=$(convert_size "$size")
    limit_human=$(convert_size "$limit")
    if (( size > limit )); then
      log_warn "$ext | $sz_human > $limit_human | $file"
    else
      log_ok "$ext | $sz_human <= $limit_human | $file"
    fi
  done

}

# ------------------------------------------------------------------------------
# Show Top 20 Largest Files
# ------------------------------------------------------------------------------
show_largest_files() {
  local dir=$1
  local ext=$2

  log_info "Top 20 largest '$ext' files in $dir"
  find "$dir" -type f -name "*$ext" -print0 2>/dev/null |
    xargs -0 stat --format="%s %n" 2>/dev/null |
    sort -nr | head -n 20 |
    awk '{ "numfmt --to=iec --suffix=B " $1 | getline size; print size "\t" $2 }'
}

# ------------------------------------------------------------------------------
# Show Directory Usage
# ------------------------------------------------------------------------------
show_directory_usage() {
  local dir=$1
  log_info "Directory disk usage (depth=1):"
  du -h --max-depth=1 "$dir" 2>/dev/null | sort -hr
}

# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------
main() {
  if [[ $# -lt 2 ]]; then
    print_usage
  fi

  case "$1" in
    -h|--help) print_usage ;;
  esac

  local dir=$1
  local ext=$2

  print_banner
  validate_args "$dir" "$ext"
  show_directory_usage "$dir"
  check_limits "$dir" "$ext"
  show_largest_files "$dir" "$ext"
}

# ------------------------------------------------------------------------------
# Execute prog
# ------------------------------------------------------------------------------
# Run only if executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
