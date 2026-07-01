#!/bin/bash
# ============================================================
#   CHANELOG VPN SCRIPT - MAIN MENU (FANCY 2-COLUMN LAYOUT)
# ============================================================

SCRIPT_DIR="/etc/vpn-script"
source "$SCRIPT_DIR/lib.sh"

show_header() {
  clear
  
  # ─── Get all info ───────────────────────────────────────
  local domain=$(get_domain)
  local ip=$(get_server_ip)
  local os=$(get_os_info)
  local kernel=$(get_kernel)
  local cores=$(get_cpu_cores)
  local mem=$(free -h | awk 'NR==2 {print $3 " / " $2}')
  local uptime=$(uptime -p 2>/dev/null | sed 's/up //')
  local load=$(uptime | awk -F'load average: ' '{print $2}' | cut -d, -f1)
  local net=$(get_network_usage)
  local vmess_count=$(count_vmess)
  local vless_count=$(count_vless)
  local date_now=$(date +"%d/%m/%Y")
  local time_now=$(date +"%H:%M:%S")

  local xray_st nginx_st db_st sshws_st
  systemctl is-active --quiet xray     && xray_st="${GREEN}ON${NC}"    || xray_st="${RED}OFF${NC}"
  systemctl is-active --quiet nginx    && nginx_st="${GREEN}ON${NC}"   || nginx_st="${RED}OFF${NC}"
  systemctl is-active --quiet dropbear && db_st="${GREEN}ON${NC}"      || db_st="${RED}OFF${NC}"
  if [[ -f /usr/local/bin/sshws ]] || [[ -f /etc/vpn-script/ws-ssh-proxy.py ]]; then
    systemctl is-active --quiet ssh-ws && sshws_st="${GREEN}ON${NC}" || sshws_st="${RED}OFF${NC}"
  else
    sshws_st="${YELLOW}N/A${NC}"
  fi

  # ─── ASCII Header ───────────────────────────────────────
  echo -e "${CYAN}"
  cat <<'HEADER'

        ░▒▓█►─═══════════════════════════════════════╔═══════════════════════════════════════◄─█▓▒░
        
         ██████╗██╗  ██╗ █████╗ ███╗   ██╗███████╗██╗      ██████╗  ██████╗
        ██╔════╝██║  ██║██╔══██╗████╗  ██║██╔════╝██║     ██╔═══██╗██╔════╝
        ██║     ███████║███████║██╔██╗ ██║█████╗  ██║     ██║   ██║██║  ███╗
        ██║     ██╔══██║██╔══██║██║╚██╗██║██╔══╝  ██║     ██║   ██║██║   ██║
        ╚██████╗██║  ██║██║  ██║██║ ╚████║███████╗███████╗╚██████╔╝╚██████╔╝
         ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝ ╚═════╝  ╚═════╝

        ░▒▓█►─═══════════════════════════════════════╚═══════════════════════════════════════◄─█▓▒░
HEADER
  echo -e "${NC}"

  # ─── 2-Column Layout ────────────────────────────────────
  printf '%s\n' \
    "${CYAN}┌─────────────────────────────────────┬──────────────────────────────────────┐${NC}" \
    "${CYAN}│${NC} ${WHITE}MENU MANAGEMENT${NC}                 ${CYAN}│${NC} ${WHITE}SYSTEM INFORMATION${NC}              ${CYAN}│${NC}"

  # ─── Menu Items (kiri) ──────────────────────────────────
  {
    printf '%s\n' \
      "${CYAN}│${NC}                                   ${CYAN}│${NC}  ${YELLOW}[S]${NC} System Os        ${WHITE}: $os${NC}" \
      "${CYAN}│${NC}  ${GREEN}[01.]${NC} SSH/OVPN/UDP        ${CYAN}│${NC}  ${YELLOW}[C]${NC} Core System      ${WHITE}: $cores${NC}" \
      "${CYAN}│${NC}  ${GREEN}[02.]${NC} VMESS              ${CYAN}│${NC}  ${YELLOW}[R]${NC} RAM Server       ${WHITE}: $mem${NC}" \
      "${CYAN}│${NC}  ${GREEN}[03.]${NC} VLESS              ${CYAN}│${NC}  ${YELLOW}[U]${NC} Uptime Server    ${WHITE}: $uptime${NC}" \
      "${CYAN}│${NC}  ${GREEN}[04.]${NC} TROJAN             ${CYAN}│${NC}  ${YELLOW}[D]${NC} Domain           ${WHITE}: $domain${NC}" \
      "${CYAN}│${NC}  ${GREEN}[05.]${NC} SHADOWSOCKS        ${CYAN}│${NC}  ${YELLOW}[I]${NC} IP VPS           ${WHITE}: $ip${NC}" \
      "${CYAN}│${NC}  ${GREEN}[06.]${NC} NOOBZVPN           ${CYAN}│${NC}  ${YELLOW}[T]${NC} Tanggal          ${WHITE}: $date_now${NC}" \
      "${CYAN}│${NC}  ${GREEN}[07.]${NC} Settings           ${CYAN}│${NC}  ${YELLOW}[Z]${NC} Jam              ${WHITE}: $time_now${NC}" \
      "${CYAN}│${NC}  ${GREEN}[08.]${NC} Reinstall          ${CYAN}│${NC} " \
      "${CYAN}│${NC}  ${GREEN}[09.]${NC} Backup & Restore   ${CYAN}│${NC}  ${YELLOW}[●]${NC} Bandwidth        ${WHITE}: $net${NC}" \
      "${CYAN}│${NC}  ${GREEN}[10.]${NC} Update             ${CYAN}│${NC} " \
      "${CYAN}│${NC}  ${GREEN}[11.]${NC} Rebuild            ${CYAN}│${NC}  ${YELLOW}[●]${NC} SSH/OVPN/UDP     ${WHITE}: $sshws_st${NC}" \
      "${CYAN}│${NC}  ${GREEN}[12.]${NC} Speedctrl          ${CYAN}│${NC}  ${YELLOW}[●]${NC} VMESS            ${WHITE}: $xray_st${NC}"
  } | column -t -s '│' | sed 's/^/│/' | sed 's/$/│/'

  echo "${CYAN}├─────────────────────────────────────┼──────────────────────────────────────┤${NC}"

  # ─── Service Status (bawah kiri) ─────────────────────────
  printf '%s\n' \
    "${CYAN}│${NC}  ${YELLOW}[●]${NC} SSH         ${WHITE}: $sshws_st   │  ${YELLOW}[●]${NC} VLESS            ${WHITE}: $xray_st${NC}" \
    "${CYAN}│${NC}  ${YELLOW}[●]${NC} WS          ${WHITE}: $nginx_st    │  ${YELLOW}[●]${NC} TROJAN           ${WHITE}: ${YELLOW}N/A${NC}" \
    "${CYAN}│${NC}  ${YELLOW}[●]${NC} NGINX       ${WHITE}: $nginx_st    │  ${YELLOW}[●]${NC} SHADOWSOCKS      ${WHITE}: ${YELLOW}N/A${NC}" \
    "${CYAN}│${NC}  ${YELLOW}[●]${NC} DROPBEAR    ${WHITE}: $db_st       │  ${YELLOW}[●]${NC} NOOBZVPN        ${WHITE}: ${YELLOW}N/A${NC}" \
    "${CYAN}│${NC}  ${YELLOW}[●]${NC} XRAY        ${WHITE}: $xray_st     │" \
    "${CYAN}│${NC}  ${YELLOW}[●]${NC} HAPROXY     ${WHITE}: ${YELLOW}N/A${NC}    │  ${YELLOW}Total VMESS Accounts${NC}: ${WHITE}$vmess_count${NC}" \
    "${CYAN}│${NC}  ${YELLOW}[●]${NC} NOOBZVPN    ${WHITE}: ${YELLOW}OFF${NC}    │  ${YELLOW}Total VLESS Accounts${NC}: ${WHITE}$vless_count${NC}"

  echo "${CYAN}└─────────────────────────────────────┴──────────────────────────────────────┘${NC}"

  # ─── Notes ──────────────────────────────────────────────
  echo ""
  echo -e "${WHITE}Note:${NC}"
  echo -e "  ${YELLOW}•${NC} Menu dengan nomor ${GREEN}[01-06]${NC} adalah tunnel protocols (belum fully integrated)"
  echo -e "  ${YELLOW}•${NC} Gunakan ${GREEN}[07]${NC} untuk konfigurasi dasar (VMess, VLess, Nginx, Dropbear, SSHWS, etc)"
  echo -e "  ${YELLOW}•${NC} Status ${YELLOW}[N/A]${NC} = belum diimplementasikan / tidak tersedia saat ini"
  echo ""
}

main_menu() {
  show_header
  echo -ne "  ${WHITE}Select menu${NC} ${CYAN}{${NC} ${GREEN}0${NC} - ${GREEN}12${NC} ${CYAN}}${NC} ${WHITE}:${NC} "
  read -r choice

  case "$choice" in
    1|01)
      echo -e "\n  ${YELLOW}[i]${NC} SSH/OVPN/UDP - Feature belum tersedia di menu ini"
      echo -e "  ${YELLOW}[i]${NC} Gunakan menu [07] Settings → untuk akses lengkap"
      sleep 2; main_menu ;;
    
    2|02)
      bash $SCRIPT_DIR/menu/vmess.sh ;;
    
    3|03)
      bash $SCRIPT_DIR/menu/vless.sh ;;
    
    4|04)
      echo -e "\n  ${YELLOW}[i]${NC} TROJAN - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    5|05)
      echo -e "\n  ${YELLOW}[i]${NC} SHADOWSOCKS - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    6|06)
      echo -e "\n  ${YELLOW}[i]${NC} NOOBZVPN - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    7|07)
      settings_menu ;;
    
    8|08)
      echo -e "\n  ${YELLOW}[i]${NC} Reinstall - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    9|09)
      echo -e "\n  ${YELLOW}[i]${NC} Backup & Restore - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    10)
      echo -e "\n  ${YELLOW}[i]${NC} Update - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    11)
      echo -e "\n  ${YELLOW}[i]${NC} Rebuild - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    12)
      echo -e "\n  ${YELLOW}[i]${NC} Speedctrl - Feature belum tersedia"
      sleep 2; main_menu ;;
    
    0)
      clear; exit 0 ;;
    
    *)
      echo -e "\n  ${RED}[!] Pilihan tidak valid!${NC}"
      sleep 1; main_menu ;;
  esac
}

settings_menu() {
  clear
  echo -e "${CYAN}┌───────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC} ${WHITE}SETTINGS & ADVANCED MANAGEMENT${NC}     ${CYAN}│${NC}"
  echo -e "${CYAN}├───────────────────────────────────────────┤${NC}"
  echo -e "${CYAN}│${NC}                                         ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[1]${NC}  VMess WebSocket              ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[2]${NC}  VLess WebSocket              ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[3]${NC}  SSH WebSocket (SSHWS)        ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[4]${NC}  OHP Redirector               ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[5]${NC}  Nginx Management             ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[6]${NC}  Dropbear SSH Management      ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[7]${NC}  System Information           ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${GREEN}[8]${NC}  Change Domain                ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${RED}[9]${NC}  Uninstall Script             ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}                                         ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${DIM}[0]${NC}  Kembali ke Menu Utama         ${CYAN}│${NC}"
  echo -e "${CYAN}└───────────────────────────────────────────┘${NC}"
  echo ""
  echo -ne "  ${WHITE}Pilih${NC} ${CYAN}{${NC} ${GREEN}0${NC} - ${GREEN}9${NC} ${CYAN}}${NC} ${WHITE}:${NC} "
  read -r choice

  case "$choice" in
    1) bash $SCRIPT_DIR/menu/vmess.sh ;;
    2) bash $SCRIPT_DIR/menu/vless.sh ;;
    3) bash $SCRIPT_DIR/menu/sshws.sh ;;
    4) bash $SCRIPT_DIR/menu/ohp.sh ;;
    5) bash $SCRIPT_DIR/menu/nginx.sh ;;
    6) bash $SCRIPT_DIR/menu/dropbear.sh ;;
    7) bash $SCRIPT_DIR/menu/sysinfo.sh ;;
    8) bash $SCRIPT_DIR/menu/changedomain.sh ;;
    9) bash $SCRIPT_DIR/menu/uninstall.sh ;;
    0) main_menu ;;
    *) echo -e "  ${RED}[!] Pilihan tidak valid!${NC}"; sleep 1; settings_menu ;;
  esac
}

main_menu
