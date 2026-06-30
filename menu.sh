#!/bin/bash
# ============================================================
#   CHANELOG VPN SCRIPT - MAIN MENU
# ============================================================

SCRIPT_DIR="/etc/vpn-script"
source "$SCRIPT_DIR/lib.sh"

LINE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

show_header() {
  clear
  local domain=$(get_domain)
  local ip=$(get_server_ip)
  local mem=$(get_mem_usage)
  local disk=$(get_disk_usage)
  local uptime=$(get_uptime)
  local os=$(get_os_info)
  local kernel=$(get_kernel)
  local load=$(get_load_avg)
  local cpu_cores=$(get_cpu_cores)
  local net=$(get_network_usage)
  local vmess_count=$(count_vmess)
  local vless_count=$(count_vless)

  # ─── Service Status ────────────────────────────────────
  local xray_st nginx_st db_st sshws_st
  systemctl is-active --quiet xray     && xray_st="${GREEN}● ON${NC}"    || xray_st="${RED}● OFF${NC}"
  systemctl is-active --quiet nginx    && nginx_st="${GREEN}● ON${NC}"   || nginx_st="${RED}● OFF${NC}"
  systemctl is-active --quiet dropbear && db_st="${GREEN}● ON${NC}"      || db_st="${RED}● OFF${NC}"

  # SSHWS: cek binary dulu, baru cek service
  if [[ -f /usr/local/bin/sshws ]]; then
    systemctl is-active --quiet sshws && sshws_st="${GREEN}● ON${NC}" || sshws_st="${RED}● OFF${NC}"
  else
    sshws_st="${YELLOW}● N/A${NC}"
  fi

  # ─── Protocol Status ───────────────────────────────────
  local xray_on nginx_on sshws_on
  systemctl is-active --quiet xray  && xray_on="${GREEN}ON${NC}"  || xray_on="${RED}OFF${NC}"
  systemctl is-active --quiet nginx && nginx_on="${GREEN}ON${NC}" || nginx_on="${RED}OFF${NC}"
  if [[ -f /usr/local/bin/sshws ]]; then
    systemctl is-active --quiet sshws && sshws_on="${GREEN}ON${NC}" || sshws_on="${RED}OFF${NC}"
  else
    sshws_on="${YELLOW}N/A${NC}"
  fi

  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}         ⚡  CHANELOG VPN TUNNEL MANAGER  ⚡${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Domain   ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}IP VPS   ${NC}: ${WHITE}$ip${NC}"
  echo -e "  ${YELLOW}OS       ${NC}: ${WHITE}$os${NC}"
  echo -e "  ${YELLOW}Kernel   ${NC}: ${WHITE}$kernel${NC}"
  echo -e "  ${YELLOW}CPU Core ${NC}: ${WHITE}$cpu_cores Core${NC}   ${YELLOW}Load Avg${NC}: ${WHITE}$load${NC}"
  echo -e "  ${YELLOW}Memory   ${NC}: ${WHITE}$mem${NC}"
  echo -e "  ${YELLOW}Disk     ${NC}: ${WHITE}$disk${NC}"
  echo -e "  ${YELLOW}Uptime   ${NC}: ${WHITE}$uptime${NC}"
  echo -e "  ${YELLOW}Network  ${NC}: ${WHITE}$net${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Nginx   ${NC}: $nginx_st   ${YELLOW}Xray${NC}: $xray_st   ${YELLOW}SSHWS${NC}: $sshws_st   ${YELLOW}Dropbear${NC}: $db_st"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${PURPLE}VMess TLS${NC}(443): $xray_on  ${PURPLE}VMess nTLS${NC}(80): $xray_on  ${PURPLE}VLess TLS${NC}(443): $xray_on  ${PURPLE}VLess nTLS${NC}(80): $xray_on"
  echo -e "  ${PURPLE}SSHWS TLS${NC}(443): $sshws_on  ${PURPLE}SSHWS nTLS${NC}(80): $sshws_on"
  echo -e "  ${YELLOW}Akun VMess${NC}: ${WHITE}$vmess_count${NC}   ${YELLOW}Akun VLess${NC}: ${WHITE}$vless_count${NC}"
  echo -e "${CYAN}$LINE${NC}"
}

main_menu() {
  show_header
  echo ""
  echo -e "  ${WHITE}MAIN MENU${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[1]${NC}  VMess WebSocket"
  echo -e "       ${DIM}WS TLS & non-TLS Management${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[2]${NC}  VLess WebSocket"
  echo -e "       ${DIM}WS TLS & non-TLS Management${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[3]${NC}  SSH WebSocket (SSHWS)"
  echo -e "       ${DIM}SSH via WS TLS (443) & non-TLS (80)${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[4]${NC}  Nginx Management"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[5]${NC}  Dropbear SSH Management"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[6]${NC}  System Information"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[7]${NC}  Change Domain"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${RED}[8]${NC}  Uninstall Script"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${DIM}[0]${NC}  Exit"
  echo -e "${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${WHITE}Pilih menu [0-8]${NC}: "
  read -r choice

  case "$choice" in
    1) bash $SCRIPT_DIR/menu/vmess.sh ;;
    2) bash $SCRIPT_DIR/menu/vless.sh ;;
    3) bash $SCRIPT_DIR/menu/sshws.sh ;;
    4) bash $SCRIPT_DIR/menu/nginx.sh ;;
    5) bash $SCRIPT_DIR/menu/dropbear.sh ;;
    6) bash $SCRIPT_DIR/menu/sysinfo.sh ;;
    7) bash $SCRIPT_DIR/menu/changedomain.sh ;;
    8) bash $SCRIPT_DIR/menu/uninstall.sh ;;
    0) clear; exit 0 ;;
    *) echo -e "  ${RED}[!] Pilihan tidak valid!${NC}"; sleep 1; main_menu ;;
  esac
}

main_menu
