#!/usr/bin/env bash

# =========================================================
# Server Monitor Manager
# Created with assistance from GPT-5.5
# =========================================================

set -uo pipefail

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ---------- Global ----------
REPORT_FILE="/tmp/server_monitor_report_$(date +%F_%H-%M-%S).txt"

# ---------- Helpers ----------
print_header() {
    clear
    echo -e "${BLUE}=========================================================${RESET}"
    echo -e "${CYAN}              Server Monitor Manager${RESET}"
    echo -e "${BLUE}=========================================================${RESET}"
    echo
}

print_section() {
    echo -e
    echo -e "${YELLOW}---------------------------------------------------------${RESET}"
    echo -e "${GREEN}$1${RESET}"
    echo -e "${YELLOW}---------------------------------------------------------${RESET}"
}

pause() {
    echo
    read -rp "Press Enter to continue..."
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}[!] Please run this script as root or with sudo.${RESET}"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect the active/default interface safely
detect_interface() {
    local iface=""

    iface="$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"

    if [[ -z "${iface}" ]]; then
        iface="$(ip route 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
    fi

    if [[ -z "${iface}" ]]; then
        iface="$(ip -br link 2>/dev/null | awk '$1 !~ /lo/ {print $1; exit}')"
    fi

    if [[ -n "${iface}" ]] && ip link show "${iface}" >/dev/null 2>&1; then
        echo "${iface}"
        return 0
    fi

    return 1
}

show_interface_info() {
    print_section "Interface Information"
    ip -br link 2>/dev/null || true
    echo
    ip -br addr 2>/dev/null || true
    echo
    if iface="$(detect_interface)"; then
        echo -e "${GREEN}[+] Detected active interface:${RESET} ${iface}"
    else
        echo -e "${RED}[!] Could not detect active network interface.${RESET}"
    fi
}

# ---------- Monitoring ----------
live_bandwidth() {
    print_section "Live Bandwidth Monitor"

    local iface=""
    iface="$(detect_interface || true)"

    if [[ -z "${iface}" ]]; then
        echo -e "${RED}[!] Could not detect a valid interface automatically.${RESET}"
        echo -e "${YELLOW}Available interfaces:${RESET}"
        ip -br link 2>/dev/null || true
        echo
        read -rp "Enter interface manually: " iface
    fi

    if [[ -z "${iface}" ]] || ! ip link show "${iface}" >/dev/null 2>&1; then
        echo -e "${RED}[!] Invalid interface.${RESET}"
        pause
        return
    fi

    echo -e "${GREEN}[+] Using interface:${RESET} ${iface}"
    echo

    if command_exists iftop; then
        echo -e "${CYAN}Starting iftop on ${iface}...${RESET}"
        echo -e "${YELLOW}Press q to quit.${RESET}"
        sleep 1
        iftop -i "${iface}"
    elif command_exists nload; then
        echo -e "${CYAN}Starting nload on ${iface}...${RESET}"
        echo -e "${YELLOW}Press q to quit.${RESET}"
        sleep 1
        nload "${iface}"
    elif command_exists bmon; then
        echo -e "${CYAN}Starting bmon...${RESET}"
        echo -e "${YELLOW}Look for interface ${iface}. Press q to quit.${RESET}"
        sleep 1
        bmon
    else
        echo -e "${RED}[!] No supported live bandwidth tool found.${RESET}"
        echo "Install one of: iftop, nload, bmon"
    fi

    pause
}

process_traffic() {
    print_section "Per-Process Traffic Monitor"

    local iface=""
    iface="$(detect_interface || true)"

    if command_exists nethogs; then
        if [[ -n "${iface}" ]] && ip link show "${iface}" >/dev/null 2>&1; then
            echo -e "${GREEN}[+] Detected interface:${RESET} ${iface}"
            echo -e "${CYAN}Starting nethogs on ${iface}...${RESET}"
            echo -e "${YELLOW}If this fails, the script will retry with -a.${RESET}"
            sleep 1

            if ! nethogs "${iface}"; then
                echo
                echo -e "${YELLOW}[!] nethogs failed on ${iface}. Retrying with all interfaces (-a)...${RESET}"
                sleep 1
                nethogs -a || echo -e "${RED}[!] nethogs could not monitor traffic on this system.${RESET}"
            fi
        else
            echo -e "${YELLOW}[!] Could not detect a valid interface. Trying nethogs -a...${RESET}"
            sleep 1
            nethogs -a || echo -e "${RED}[!] nethogs could not monitor traffic on this system.${RESET}"
        fi
    else
        echo -e "${RED}[!] nethogs is not installed.${RESET}"
        echo "Install it with:"
        echo "  Debian/Ubuntu: sudo apt install nethogs"
        echo "  RHEL/Rocky/Alma: sudo dnf install nethogs"
    fi

    pause
}

active_connections() {
    print_section "Active Connections"

    if command_exists ss; then
        ss -tuna
    else
        echo -e "${RED}[!] ss command not found.${RESET}"
    fi

    pause
}

listening_services() {
    print_section "Listening Ports and Services"

    if command_exists ss; then
        ss -tulpn
    else
        echo -e "${RED}[!] ss command not found.${RESET}"
    fi

    pause
}

top_remote_ips() {
    print_section "Top Remote IPs"

    if command_exists ss; then
        ss -ntu 2>/dev/null | awk 'NR>1 {print $5}' | sed 's/.*ffff://g' | cut -d: -f1 | \
            grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr | head -20
    else
        echo -e "${RED}[!] ss command not found.${RESET}"
    fi

    pause
}

suspicious_connections() {
    print_section "Basic Suspicious Connection Review"

    if command_exists ss; then
        echo -e "${CYAN}Connections by remote IP:${RESET}"
        ss -ntu 2>/dev/null | awk 'NR>1 {print $5}' | sed 's/.*ffff://g' | cut -d: -f1 | \
            grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr | head -30

        echo
        echo -e "${CYAN}Top established connections:${RESET}"
        ss -nt state established 2>/dev/null | awk 'NR>1 {print $5}' | \
            sed 's/.*ffff://g' | cut -d: -f1 | \
            grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr | head -30
    else
        echo -e "${RED}[!] ss command not found.${RESET}"
    fi

    pause
}

firewall_status() {
    print_section "Firewall Status"

    if command_exists ufw; then
        echo -e "${CYAN}UFW Status:${RESET}"
        ufw status verbose || true
        echo
    fi

    if command_exists iptables; then
        echo -e "${CYAN}iptables Rules:${RESET}"
        iptables -L -n -v || true
        echo
    fi

    if command_exists nft; then
        echo -e "${CYAN}nftables Ruleset:${RESET}"
        nft list ruleset || true
        echo
    fi

    pause
}

auth_logs() {
    print_section "Authentication Logs"

    if [[ -f /var/log/auth.log ]]; then
        tail -n 50 /var/log/auth.log
    elif [[ -f /var/log/secure ]]; then
        tail -n 50 /var/log/secure
    else
        echo -e "${YELLOW}[!] No auth log file found. Trying journalctl...${RESET}"
        if command_exists journalctl; then
            journalctl -n 50 -u ssh -u sshd --no-pager || true
        else
            echo -e "${RED}[!] journalctl not available.${RESET}"
        fi
    fi

    pause
}

web_logs() {
    print_section "Web Server Logs"

    local found=0

    if [[ -f /var/log/nginx/access.log ]]; then
        echo -e "${CYAN}Nginx Access Log:${RESET}"
        tail -n 50 /var/log/nginx/access.log
        found=1
    fi

    if [[ -f /var/log/nginx/error.log ]]; then
        echo
        echo -e "${CYAN}Nginx Error Log:${RESET}"
        tail -n 50 /var/log/nginx/error.log
        found=1
    fi

    if [[ -f /var/log/apache2/access.log ]]; then
        echo
        echo -e "${CYAN}Apache Access Log:${RESET}"
        tail -n 50 /var/log/apache2/access.log
        found=1
    fi

    if [[ -f /var/log/apache2/error.log ]]; then
        echo
        echo -e "${CYAN}Apache Error Log:${RESET}"
        tail -n 50 /var/log/apache2/error.log
        found=1
    fi

    if [[ "${found}" -eq 0 ]]; then
        echo -e "${YELLOW}[!] No common web server logs found.${RESET}"
    fi

    pause
}

docker_info() {
    print_section "Docker Information"

    if command_exists docker; then
        docker ps -a
    else
        echo -e "${YELLOW}[!] Docker is not installed.${RESET}"
    fi

    pause
}

system_report() {
    print_section "Generating System Report"

    {
        echo "========== SERVER MONITOR REPORT =========="
        echo "Generated: $(date)"
        echo

        echo "===== HOSTNAME ====="
        hostnamectl 2>/dev/null || hostname
        echo

        echo "===== UPTIME ====="
        uptime
        echo

        echo "===== INTERFACES ====="
        ip -br addr 2>/dev/null || true
        echo

        echo "===== ROUTING ====="
        ip route 2>/dev/null || true
        echo

        echo "===== LISTENING PORTS ====="
        ss -tulpn 2>/dev/null || true
        echo

        echo "===== ACTIVE CONNECTIONS ====="
        ss -tuna 2>/dev/null || true
        echo

        echo "===== TOP REMOTE IPS ====="
        ss -ntu 2>/dev/null | awk 'NR>1 {print $5}' | sed 's/.*ffff://g' | cut -d: -f1 | \
            grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr | head -30 || true
        echo

        echo "===== FIREWALL ====="
        if command_exists ufw; then ufw status verbose || true; fi
        if command_exists iptables; then iptables -L -n -v || true; fi
        if command_exists nft; then nft list ruleset || true; fi
        echo

        echo "===== DOCKER ====="
        if command_exists docker; then docker ps -a || true; fi
        echo
    } > "${REPORT_FILE}"

    echo -e "${GREEN}[+] Report saved to:${RESET} ${REPORT_FILE}"
    pause
}

block_ip() {
    print_section "Block an IP Address"

    local ip
    read -rp "Enter IP to block: " ip

    if [[ -z "${ip}" ]]; then
        echo -e "${RED}[!] No IP entered.${RESET}"
        pause
        return
    fi

    echo
    echo -e "${YELLOW}[!] Warning:${RESET} Blocking the wrong IP can lock out users or even yourself."
    echo -e "${YELLOW}[!] Make sure you have another active SSH session before continuing.${RESET}"
    echo
    read -rp "Are you sure you want to block ${ip}? (yes/no): " confirm

    if [[ "${confirm}" != "yes" ]]; then
        echo -e "${YELLOW}Operation cancelled.${RESET}"
        pause
        return
    fi

    if command_exists ufw; then
        ufw deny from "${ip}" && echo -e "${GREEN}[+] Blocked ${ip} using UFW.${RESET}"
    elif command_exists iptables; then
        iptables -I INPUT -s "${ip}" -j DROP && echo -e "${GREEN}[+] Blocked ${ip} using iptables.${RESET}"
    elif command_exists nft; then
        echo -e "${RED}[!] nftables blocking is not automatically implemented in this script.${RESET}"
        echo -e "${YELLOW}Add nft rule manually to avoid damaging your ruleset.${RESET}"
    else
        echo -e "${RED}[!] No supported firewall tool found.${RESET}"
    fi

    pause
}

install_tools() {
    print_section "Install Monitoring Tools"

    echo "This helper only prints suggested commands."
    echo
    if command_exists apt; then
        echo "Debian/Ubuntu:"
        echo "sudo apt update && sudo apt install -y iftop nethogs vnstat iptraf-ng bmon nload lsof net-tools"
    elif command_exists dnf; then
        echo "RHEL/Rocky/Alma/Fedora:"
        echo "sudo dnf install -y iftop nethogs vnstat iptraf-ng bmon nload lsof net-tools"
    elif command_exists yum; then
        echo "Older RHEL/CentOS:"
        echo "sudo yum install -y iftop nethogs vnstat iptraf-ng bmon nload lsof net-tools"
    else
        echo -e "${YELLOW}[!] Package manager not recognized.${RESET}"
    fi

    pause
}

show_menu() {
    print_header
    echo "1) Show network interface info"
    echo "2) Live bandwidth monitor"
    echo "3) Per-process traffic monitor"
    echo "4) Active connections"
    echo "5) Listening ports/services"
    echo "6) Top remote IPs"
    echo "7) Suspicious connection review"
    echo "8) Firewall status"
    echo "9) Authentication logs"
    echo "10) Web server logs"
    echo "11) Docker info"
    echo "12) Generate system report"
    echo "13) Block an IP"
    echo "14) Installation helper"
    echo "0) Exit"
    echo
}

main() {
    require_root

    while true; do
        show_menu
        read -rp "Select an option: " choice
        echo

        case "${choice}" in
            1) show_interface_info ;;
            2) live_bandwidth ;;
            3) process_traffic ;;
            4) active_connections ;;
            5) listening_services ;;
            6) top_remote_ips ;;
            7) suspicious_connections ;;
            8) firewall_status ;;
            9) auth_logs ;;
            10) web_logs ;;
            11) docker_info ;;
            12) system_report ;;
            13) block_ip ;;
            14) install_tools ;;
            0)
                echo -e "${GREEN}Goodbye.${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Invalid option.${RESET}"
                pause
                ;;
        esac
    done
}

main "$@"
