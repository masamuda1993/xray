#!/bin/bash
# ============================================================
#   CHANELOG VPN SCRIPT - SSHWS MENU
#   Engine: ws-ssh-proxy.py (custom, transparan, open-source)
#   Akun SSHWS = user sistem Linux (useradd/chpasswd), expired
#   otomatis tersimpan di database mirip VMess/VLess.
# ============================================================

SCRIPT_DIR="/etc/vpn-script"
source "$SCRIPT_DIR/lib.sh"

LINE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SSHWS_PROXY="$SCRIPT_DIR/ws-ssh-proxy.py"
SSHWS_SERVICE="/etc/systemd/system/ssh-ws.service"
SSHWS_CONFIG="/etc/ssh-ws/config"

sshws_installed() {
  [[ -f "$SSHWS_PROXY" ]]
}

_write_config() {
  local ssh_port="${1:-22}"
  mkdir -p /etc/ssh-ws
  cat > "$SSHWS_CONFIG" <<EOF
SSH_PORT=$ssh_port
WS_PORT_TLS=20001
WS_PORT_NTLS=20002
EOF
}

_cfg() {
  grep "^$1=" "$SSHWS_CONFIG" 2>/dev/null | cut -d= -f2
}

_write_service() {
  local ssh_port=$(_cfg SSH_PORT); ssh_port=${ssh_port:-22}
  local port_tls=$(_cfg WS_PORT_TLS); port_tls=${port_tls:-20001}
  local port_ntls=$(_cfg WS_PORT_NTLS); port_ntls=${port_ntls:-20002}

  cat > "$SSHWS_SERVICE" <<EOF
[Unit]
Description=SSH WebSocket Proxy (custom, transparan)
After=network.target

[Service]
User=root
ExecStart=/usr/bin/python3 $SSHWS_PROXY --listen-host 127.0.0.1 --port-tls $port_tls --port-ntls $port_ntls --ssh-host 127.0.0.1 --ssh-port $ssh_port
Restart=on-failure
RestartSec=3
LimitNOFILE=65536
StandardOutput=append:/var/log/ssh-ws.log
StandardError=append:/var/log/ssh-ws.log

[Install]
WantedBy=multi-user.target
EOF
}

_add_nginx_sshws() {
  local nginx_conf="/etc/nginx/conf.d/xray.conf"
  grep -q "location /sshws {" "$nginx_conf" 2>/dev/null && return

  python3 - "$nginx_conf" <<'PYEOF' 2>/dev/null
import sys
conf_file = sys.argv[1]
with open(conf_file, 'r') as f:
    content = f.read()

sshws_tls = """
    location /sshws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:20001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 3600s;
    }

"""
sshws_ntls = """
    location /sshws-ntls {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:20002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 3600s;
    }

"""
if '/sshws' not in content:
    content = content.replace('    location /vless-ws {', sshws_tls + '    location /vless-ws {', 1)
if '/sshws-ntls' not in content:
    content = content.replace('    location / {\n        return 301', sshws_ntls + '    location / {\n        return 301', 1)

with open(conf_file, 'w') as f:
    f.write(content)
PYEOF

  nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null
}

_remove_nginx_sshws() {
  local nginx_conf="/etc/nginx/conf.d/xray.conf"
  python3 - "$nginx_conf" <<'PYEOF' 2>/dev/null
import sys, re
conf_file = sys.argv[1]
with open(conf_file, 'r') as f:
    content = f.read()
content = re.sub(r'\n\s*location /sshws[^{]*\{[^}]*\}\n', '\n', content)
with open(conf_file, 'w') as f:
    f.write(content)
PYEOF
  nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null
}

install_sshws() {
  clear
  local domain=$(get_domain)
  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}          ⚡  INSTALL SSH WEBSOCKET  ⚡${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo ""
  echo -e "  ${WHITE}Pilih SSH backend yang akan dipakai:${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${GREEN}[1]${NC}  OpenSSH  ${DIM}(sshd standar, port 22)${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[2]${NC}  Dropbear ${DIM}(port 442)${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${DIM}[0]${NC}  Batal"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${WHITE}Pilih [0-2]${NC}: "
  read -r choice

  local ssh_port
  case "$choice" in
    1) ssh_port=22 ;;
    2) ssh_port=442 ;;
    0) sshws_menu; return ;;
    *) echo -e "  ${RED}[!] Tidak valid${NC}"; sleep 1; install_sshws; return ;;
  esac

  echo ""
  echo -e "  ${CYAN}[*]${NC} Memastikan python3 tersedia..."
  command -v python3 &>/dev/null || apt-get install -y -qq python3 2>/dev/null

  if [[ ! -f "$SSHWS_PROXY" ]]; then
    echo -e "  ${RED}[!] File ws-ssh-proxy.py tidak ditemukan di $SCRIPT_DIR${NC}"
    echo -ne "\n  ${DIM}Tekan Enter...${NC}"; read -r
    sshws_menu; return
  fi

  echo -e "  ${CYAN}[*]${NC} Menulis konfigurasi & service..."
  _write_config "$ssh_port"
  _write_service

  systemctl daemon-reload
  systemctl enable ssh-ws 2>/dev/null
  systemctl restart ssh-ws 2>/dev/null

  echo -e "  ${CYAN}[*]${NC} Menambahkan lokasi nginx..."
  _add_nginx_sshws

  mkdir -p "$DB_DIR"
  touch "$DB_SSHWS"

  sleep 1
  if systemctl is-active --quiet ssh-ws; then
    echo -e "  ${GREEN}[✓] SSHWS berhasil diinstall dan berjalan${NC}"
  else
    echo -e "  ${RED}[!] Service gagal start, cek log: journalctl -u ssh-ws -n 30${NC}"
  fi
  sleep 2
  sshws_menu
}

sshws_header() {
  clear
  local domain=$(get_domain)
  local count=$(count_sshws)
  local sshws_st ssh_port

  if ! sshws_installed; then
    sshws_st="${RED}● TIDAK TERINSTALL${NC}"
    ssh_port="N/A"
  else
    systemctl is-active --quiet ssh-ws \
      && sshws_st="${GREEN}● RUNNING${NC}" || sshws_st="${RED}● STOPPED${NC}"
    ssh_port=$(_cfg SSH_PORT); ssh_port=${ssh_port:-22}
  fi

  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}             ⚡  SSH WEBSOCKET MENU  ⚡${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Domain       ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}Status       ${NC}: $sshws_st"
  echo -e "  ${YELLOW}SSH Backend  ${NC}: ${WHITE}127.0.0.1:$ssh_port${NC}"
  echo -e "  ${YELLOW}Port TLS     ${NC}: ${WHITE}443${NC}   Path: ${WHITE}/sshws${NC}"
  echo -e "  ${YELLOW}Port nTLS    ${NC}: ${WHITE}80${NC}    Path: ${WHITE}/sshws-ntls${NC}"
  echo -e "  ${YELLOW}Total Akun   ${NC}: ${WHITE}$count akun${NC}"
  echo -e "${CYAN}$LINE${NC}"
}

sshws_menu() {
  sshws_header

  if ! sshws_installed; then
    echo ""
    echo -e "  ${RED}[!] SSHWS belum terinstall${NC}"
    echo -e "  ${CYAN}$LINE${NC}"
    echo -e "  ${GREEN}[1]${NC}  Install SSHWS"
    echo -e "  ${CYAN}$LINE${NC}"
    echo -e "  ${DIM}[0]${NC}  Kembali ke Menu Utama"
    echo -e "  ${CYAN}$LINE${NC}"
    echo ""
    echo -ne "  ${WHITE}Pilih [0-1]${NC}: "
    read -r choice
    case "$choice" in
      1) install_sshws ;;
      0) bash $SCRIPT_DIR/menu.sh ;;
      *) echo -e "  ${RED}[!] Tidak valid${NC}"; sleep 1; sshws_menu ;;
    esac
    return
  fi

  echo ""
  echo -e "  ${WHITE}SSH WS — TLS & non-TLS${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${GREEN}[1]${NC}  Buat Akun SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${GREEN}[2]${NC}  Info Akun SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${RED}[3]${NC}  Hapus Akun SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[4]${NC}  Perpanjang Akun SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${CYAN}[5]${NC}  List Semua Akun SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${WHITE}[6]${NC}  Status & Log Service"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[7]${NC}  Start / Stop / Restart Service"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[8]${NC}  Ganti SSH Backend (OpenSSH ↔ Dropbear)"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${RED}[9]${NC}  Uninstall SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${DIM}[0]${NC}  Kembali ke Menu Utama"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${WHITE}Pilih [0-9]${NC}: "
  read -r choice

  case "$choice" in
    1) do_create_sshws ;;
    2) do_info_sshws ;;
    3) do_delete_sshws ;;
    4) do_renew_sshws ;;
    5) do_list_sshws ;;
    6) _show_status_log ;;
    7) _service_control ;;
    8) _switch_backend ;;
    9) _uninstall_sshws ;;
    0) bash $SCRIPT_DIR/menu.sh ;;
    *) echo -e "  ${RED}[!] Tidak valid${NC}"; sleep 1; sshws_menu ;;
  esac
}

do_create_sshws() {
  sshws_header
  echo ""
  echo -e "  ${WHITE}BUAT AKUN SSHWS BARU${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${YELLOW}Username     ${NC}: "; read -r username
  if [[ -z "$username" ]]; then
    echo -e "  ${RED}[!] Username kosong!${NC}"; sleep 2; sshws_menu; return
  fi
  if ! [[ "$username" =~ ^[a-z][a-z0-9_]{2,31}$ ]]; then
    echo -e "  ${RED}[!] Username harus huruf kecil/angka, mulai huruf, 3-32 karakter${NC}"
    sleep 2; sshws_menu; return
  fi
  if id "$username" &>/dev/null; then
    echo -e "  ${RED}[!] Username sudah ada di sistem!${NC}"; sleep 2; sshws_menu; return
  fi

  echo -ne "  ${YELLOW}Password     ${NC}: "; read -r password
  [[ -z "$password" ]] && { echo -e "  ${RED}[!] Password kosong!${NC}"; sleep 2; sshws_menu; return; }

  echo -ne "  ${YELLOW}Masa aktif (hari)${NC}: "; read -r days; days=${days:-30}
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo -e "  ${RED}[!] Harus angka!${NC}"; sleep 2; sshws_menu; return
  fi

  local result=$(create_sshws_account "$username" "$password" "$days")
  if [[ "$result" != "OK" ]]; then
    echo -e "  ${RED}[!] Gagal membuat akun (kode: $result)${NC}"
    sleep 2; sshws_menu; return
  fi

  local domain=$(get_domain)
  local exp=$(get_exp_date "$days")
  local ssh_port=$(_cfg SSH_PORT); ssh_port=${ssh_port:-22}

  clear
  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}           ✓  AKUN SSHWS BERHASIL DIBUAT${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Username   ${NC}: ${WHITE}$username${NC}"
  echo -e "  ${YELLOW}Password   ${NC}: ${WHITE}$password${NC}"
  echo -e "  ${YELLOW}Domain     ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}Dibuat     ${NC}: ${WHITE}$(date +"%Y-%m-%d")${NC}"
  echo -e "  ${YELLOW}Expired    ${NC}: ${WHITE}$exp${NC}"
  echo -e "  ${YELLOW}Masa Aktif ${NC}: ${WHITE}$days hari${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${WHITE}WS TLS  — Host: $domain  Port: 443  Path: /sshws${NC}"
  echo -e "  ${WHITE}WS nTLS — Host: $domain  Port: 80   Path: /sshws-ntls${NC}"
  echo -e "  ${WHITE}SSH Backend Port (lokal): $ssh_port${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${WHITE}URL WS TLS :${NC}  ${GREEN}wss://$domain:443/sshws${NC}"
  echo -e "  ${WHITE}URL WS nTLS:${NC}  ${YELLOW}ws://$domain:80/sshws-ntls${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${DIM}Tekan Enter untuk kembali...${NC}"; read -r
  sshws_menu
}

do_info_sshws() {
  sshws_header
  echo ""
  echo -e "  ${WHITE}INFO AKUN SSHWS${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${YELLOW}Username${NC}: "; read -r username
  local info=$(get_sshws_info "$username")
  [[ -z "$info" ]] && { echo -e "  ${RED}[!] Akun tidak ditemukan!${NC}"; sleep 2; sshws_menu; return; }

  local exp=$(echo "$info" | cut -d'|' -f2)
  local created=$(echo "$info" | cut -d'|' -f3)
  local remaining=$(days_until_exp "$exp")
  local sc="${GREEN}"; local st="AKTIF"
  [[ $remaining -lt 0 ]] && { sc="${RED}";     st="EXPIRED"; }
  [[ $remaining -le 3 && $remaining -ge 0 ]] && { sc="${YELLOW}"; st="SEGERA EXPIRED"; }

  echo ""
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Username  ${NC}: ${WHITE}$username${NC}"
  echo -e "  ${YELLOW}Dibuat    ${NC}: ${WHITE}$created${NC}"
  echo -e "  ${YELLOW}Expired   ${NC}: ${WHITE}$exp${NC}"
  echo -e "  ${YELLOW}Sisa      ${NC}: ${WHITE}$remaining hari${NC}"
  echo -e "  ${YELLOW}Status    ${NC}: ${sc}● $st${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${DIM}Tekan Enter untuk kembali...${NC}"; read -r
  sshws_menu
}

do_delete_sshws() {
  sshws_header
  echo ""
  echo -e "  ${RED}HAPUS AKUN SSHWS${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  do_list_sshws_simple
  echo ""
  echo -ne "  ${YELLOW}Username yang dihapus${NC}: "; read -r username
  [[ -z "$(get_sshws_info "$username")" ]] && { echo -e "  ${RED}[!] Akun tidak ditemukan!${NC}"; sleep 2; sshws_menu; return; }
  echo -ne "  ${RED}Konfirmasi hapus '$username'? [y/N]${NC}: "; read -r c
  [[ ! "$c" =~ ^[Yy]$ ]] && { echo -e "  ${YELLOW}Dibatalkan${NC}"; sleep 1; sshws_menu; return; }
  delete_sshws_account "$username"
  echo -e "  ${GREEN}[✓] Akun '$username' dihapus!${NC}"; sleep 2; sshws_menu
}

do_renew_sshws() {
  sshws_header
  echo ""
  echo -e "  ${YELLOW}PERPANJANG AKUN SSHWS${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  do_list_sshws_simple
  echo ""
  echo -ne "  ${YELLOW}Username${NC}: "; read -r username
  local info=$(get_sshws_info "$username")
  [[ -z "$info" ]] && { echo -e "  ${RED}[!] Akun tidak ditemukan!${NC}"; sleep 2; sshws_menu; return; }
  local old_exp=$(echo "$info" | cut -d'|' -f2)
  echo -e "  ${YELLOW}Expired saat ini${NC}: ${WHITE}$old_exp${NC}"
  echo -ne "  ${YELLOW}Perpanjang (hari)${NC}: "; read -r days; days=${days:-30}
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo -e "  ${RED}[!] Harus angka!${NC}"; sleep 2; sshws_menu; return
  fi
  renew_sshws_account "$username" "$days"
  echo -e "  ${GREEN}[✓] Diperpanjang hingga ${WHITE}$(get_exp_date "$days")${NC}"; sleep 2; sshws_menu
}

do_list_sshws_simple() {
  local count=0
  printf "  ${CYAN}%-20s %-12s %-12s${NC}\n" "USERNAME" "EXPIRED" "SISA HARI"
  echo -e "  ${CYAN}$LINE${NC}"
  while IFS='|' read -r user exp created; do
    [[ -z "$user" ]] && continue
    local r=$(days_until_exp "$exp")
    local c="${WHITE}"
    [[ $r -lt 0 ]] && c="${RED}"
    [[ $r -le 3 && $r -ge 0 ]] && c="${YELLOW}"
    printf "  ${c}%-20s %-12s %-12s${NC}\n" "$user" "$exp" "$r hari"
    ((count++))
  done < <(list_sshws)
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Total${NC}: ${WHITE}$count akun${NC}"
}

do_list_sshws() {
  clear
  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}              ◈  DAFTAR AKUN SSHWS  ◈${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo ""
  do_list_sshws_simple
  echo ""
  echo -ne "  ${DIM}Tekan Enter untuk kembali...${NC}"; read -r
  sshws_menu
}

_show_status_log() {
  echo ""
  echo -e "  ${CYAN}$LINE${NC}"
  systemctl status ssh-ws --no-pager -l 2>/dev/null | head -15 | sed 's/^/  /'
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${WHITE}Log terbaru:${NC}"
  tail -25 /var/log/ssh-ws.log 2>/dev/null | sed 's/^/  /' \
    || echo -e "  ${YELLOW}Log kosong${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -ne "\n  ${DIM}Tekan Enter...${NC}"; read -r
  sshws_menu
}

_service_control() {
  sshws_header
  echo ""
  echo -e "  ${GREEN}[1]${NC}  Start"
  echo -e "  ${RED}[2]${NC}  Stop"
  echo -e "  ${YELLOW}[3]${NC}  Restart"
  echo -e "  ${DIM}[0]${NC}  Batal"
  echo ""
  echo -ne "  ${WHITE}Pilih${NC}: "; read -r c
  case "$c" in
    1) systemctl start ssh-ws 2>/dev/null && echo -e "  ${GREEN}[✓] Started${NC}" ;;
    2) systemctl stop ssh-ws 2>/dev/null && echo -e "  ${YELLOW}[✓] Stopped${NC}" ;;
    3) systemctl restart ssh-ws 2>/dev/null && echo -e "  ${GREEN}[✓] Restarted${NC}" ;;
  esac
  sleep 2; sshws_menu
}

_switch_backend() {
  sshws_header
  local cur_port=$(_cfg SSH_PORT)
  echo ""
  echo -e "  ${WHITE}GANTI SSH BACKEND${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Backend saat ini${NC}: port ${WHITE}$cur_port${NC}"
  echo ""
  echo -e "  ${GREEN}[1]${NC}  OpenSSH (port 22)"
  echo -e "  ${YELLOW}[2]${NC}  Dropbear (port 442)"
  echo -e "  ${DIM}[0]${NC}  Batal"
  echo ""
  echo -ne "  ${WHITE}Pilih${NC}: "; read -r c

  local new_port
  case "$c" in
    1) new_port=22 ;;
    2) new_port=442 ;;
    *) sshws_menu; return ;;
  esac

  sed -i "s/^SSH_PORT=.*/SSH_PORT=$new_port/" "$SSHWS_CONFIG"
  _write_service
  systemctl daemon-reload
  systemctl restart ssh-ws 2>/dev/null
  echo -e "  ${GREEN}[✓] Backend diganti ke port $new_port, service direstart${NC}"
  sleep 2; sshws_menu
}

_uninstall_sshws() {
  sshws_header
  echo ""
  echo -e "  ${RED}UNINSTALL SSHWS${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[!] Semua akun SSHWS (user sistem) juga akan dihapus${NC}"
  echo -ne "  ${RED}Konfirmasi uninstall? [y/N]${NC}: "; read -r c
  [[ ! "$c" =~ ^[Yy]$ ]] && { echo -e "  ${YELLOW}Dibatalkan${NC}"; sleep 1; sshws_menu; return; }

  systemctl stop ssh-ws 2>/dev/null
  systemctl disable ssh-ws 2>/dev/null
  rm -f "$SSHWS_SERVICE"
  rm -rf /etc/ssh-ws
  rm -f /var/log/ssh-ws.log
  _remove_nginx_sshws

  while IFS='|' read -r user exp created; do
    [[ -n "$user" ]] && userdel "$user" 2>/dev/null
  done < <(list_sshws)
  rm -f "$DB_SSHWS"

  systemctl daemon-reload 2>/dev/null

  echo -e "  ${GREEN}[✓] SSHWS berhasil diuninstall${NC}"
  sleep 2
  bash $SCRIPT_DIR/menu.sh
}

sshws_menu
