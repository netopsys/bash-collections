#!/bin/bash

# ==============================================================================
# Module : manage-state-network-device.sh
# Description : SECURITY - Manage state network interfaces (Ethernet, Wi-Fi, Bluetooth) 
# Author : netopsys
# License : GPL-3.0
# ==============================================================================

#DEBUG=1
set -euo pipefail 
[ -n "${DEBUG:-}" ] && set -x 

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() { 
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - SECURITY - Manage state network interfaces (Ethernet, Wi-Fi, Bluetooth)"
  echo "==========================================================="
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
CYAN='\033[0;36m'
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

log_info()  { printf "%s ${CYAN}[INFO]${RESET} %s\n"  "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_ok()    { printf "%s ${GREEN}✔${RESET}   %s\n"  "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_warn()  { printf "%s ${YELLOW}[WARN]${RESET} %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_error() { printf "%s ${RED}[ERROR]${RESET} %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "Please run this script as root."
    exit 1
  fi
}

show_status() {

    echo ""
    log_info "Network Interfaces Status:"
    for i in /sys/class/net/*; do
        iface=$(basename "$i")
        state=$(cat "$i/operstate")
        echo "$iface: $state"
    done

    log_info "WiFi Status:"
    nmcli radio 

    log_info "Bluetooth Status:"
    if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
        echo -e "${RED}disable${RESET}"
    else
        echo -e "${GREEN}enable${RESET}"
    fi
    echo ""
}

enabled_icmp_echo() {
  log_info "Enabling ping replies..."
  echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all > /dev/null
  systemctl reload NetworkManager.service
  systemctl daemon-reload
  status_icmp=$(sudo cat /proc/sys/net/ipv4/icmp_echo_ignore_all)
  log_info "ICMP STATUS (0=on 1=off): $status_icmp"
  log_ok "Ping responses are now ENABLED." 
}

disabled_icmp_echo() {
  log_info "Disabling ping replies..."
  echo 1 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all > /dev/null
  systemctl reload NetworkManager.service
  systemctl daemon-reload
  status_icmp=$(sudo cat /proc/sys/net/ipv4/icmp_echo_ignore_all)
  log_info "ICMP STATUS (0=on 1=off): $status_icmp"
  log_ok "Ping responses are now DISABLED." 
}

manage_network_state_wifi() {

    log_info "WiFi Status:"
    nmcli radio 
    echo ""
    read -rp "➤ Enable or disable WiFi? (on/off): " choiceWiFi
    if [[ "$choiceWiFi" == "on" ]]; then
        nmcli radio wifi on
        log_ok "WiFi set to on"
    elif [[ "$choiceWiFi" == "off" ]]; then
        nmcli radio wifi off
    else
        log_info "Skipped..." 
    fi 
}

manage_network_state_ethernet() {

    log_info "Network Interfaces Status:"
    for i in /sys/class/net/*; do
        iface=$(basename "$i")
        state=$(cat "$i/operstate")
        echo "$iface: $state"
    done

    IFACE=$(nmcli dev status | awk '/ethernet/ {print $1; exit}')
    if [ -z "$IFACE" ]; then
        echo "No Ethernet interface detected."
        return
    fi

    read -rp "➤ [1/3] Enable or disable Ethernet ($IFACE)? (up/down): " choiceEthernet
    if [[ "$choiceEthernet" == "up" ]]; then
        sudo ip link set "$IFACE" up
        log_ok "Ethernet $IFACE set to up"
    elif [[ "$choiceEthernet" == "down" ]]; then
        sudo ip link set "$IFACE" down
        log_ok "Ethernet $IFACE set to down"
    else
        log_info "Skipped..."
    fi 

    read -rp "➤ [2/3] Enable or disable Arp ($IFACE)? (on/off): " choiceArp
    if [[ "$choiceArp" == "on" ]]; then
        sudo ip link set dev "$IFACE" arp on
        log_ok "Arp $IFACE set to on"
    elif [[ "$choiceArp" == "off" ]]; then
        sudo ip link set dev "$IFACE" arp off
        log_ok "Arp $IFACE set to off"
    else
        log_info "Skipped..."
    fi

    status_icmp=$(sudo cat /proc/sys/net/ipv4/icmp_echo_ignore_all)
    log_info "ICMP STATUS (0=on 1=off): $status_icmp"
    read -rp "➤ [3/3] Enable or disable ping replies? (on/off): " choicePing
    if [[ "$choicePing" == "on" ]]; then
        enabled_icmp_echo
    elif [[ "$choicePing" == "off" ]]; then
        disabled_icmp_echo
    else
        log_info "Skipped..." 
    fi
}

manage_network_state_bluetooth() {

    log_info "Bluetooth Status:"
    if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
        echo -e "${RED}disable${RESET}"
    else
        echo -e "${GREEN}enable${RESET}"
    fi
    echo ""
    read -rp "➤ Enable or disable Bluetooth? (on/off): " choiceBluetooth
    if [[ "$choiceBluetooth" == "on" ]]; then
        rfkill unblock bluetooth
        log_ok "Bluetooth set to on"
    elif [[ "$choiceBluetooth" == "off" ]]; then
        rfkill block bluetooth
        log_ok "Bluetooth set to off"
    else
        log_info "Skipped..." 
    fi
}


# ------------------------------------------------------------------------------
# Main prog
# ------------------------------------------------------------------------------
while true; do

    print_banner
    check_root
    # show_status 
    
    echo "Menu:" 
    echo "   1) WiFi"
    echo "   2) Ethernet"
    echo "   3) Bluetooth" 
    echo "   q) Exit"
    echo ""
    read -rp "➤ Choose an option:" opt

    case $opt in
        1) manage_network_state_wifi ;;
        2) manage_network_state_ethernet ;;
        3) manage_network_state_bluetooth ;; 
        q) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
 