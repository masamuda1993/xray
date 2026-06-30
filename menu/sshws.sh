#!/bin/bash
# ============================================================
#   CHANELOG VPN SCRIPT - SSHWS MENU
#   Binary: ssh-ws.openssh / ssh-ws.dropbear dari chanelog/bin
# ============================================================

SCRIPT_DIR="/etc/vpn-script"
source "$SCRIPT_DIR/lib.sh"

LINE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SSHWS_BIN_OPENSSH="/usr/local/bin/ssh-ws.openssh"
SSHWS_BIN_DROPBEAR="/usr/local/bin/ssh-ws.dropbear"
SSHWS_BIN="/usr/local/bin/ssh-ws"          # symlink aktif
SSHWS_SERVICE="/etc/systemd/system/ssh-ws.service"
SSHWS_CONFIG="/etc/ssh-ws/config"
REPO="https://raw.githubusercontent.com/chanelog/bin/main"

# ─── Cek apakah binary sudah ada ─────────────────────────
sshws_installed() {
  [[ -f "$SSHWS_BIN_OPENSSH" ]] || [[ -f "$SSHWS_BIN_DROPBEAR" ]]
}

sshws_active_bin() {
  # Return binary mana yang sedang aktif (via symlink atau langsung)
  if [[ -L "$SSHWS_BIN" ]]; then
    readlink -f "$SSHWS_BIN"
  elif [[ -f "$SSHWS_BIN_OPENSSH" ]]; then
    echo "$SSHWS_BIN_OPENSSH"
  elif [[ -f "$SSHWS_BIN_DROPBEAR" ]]; then
    echo "$SSHWS_BIN_DROPBEAR"
  else
    echo "none"
  fi
}

sshws_mode() {
  local bin=$(sshws_active_bin)
  [[ "$bin" == *openssh* ]] && echo "OpenSSH" || echo "Dropbear"
}

# ─── Install binary dari chanelog/bin ─────────────────────
install_sshws() {
  clear
  local domain=$(get_domain)
  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}           ⚡  INSTALL SSH WEBSOCKET  ⚡${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo ""
  echo -e "  ${WHITE}Pilih mode SSH backend:${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${GREEN}[1]${NC}  OpenSSH  ${DIM}(gunakan sshd standar port 22)${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[2]${NC}  Dropbear ${DIM}(gunakan dropbear port 442/109/143)${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${DIM}[0]${NC}  Batal"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${WHITE}Pilih [0-2]${NC}: "
  read -r mode_choice

  local bin_remote bin_local ssh_port
  case "$mode_choice" in
    1)
      bin_remote="ssh-ws.openssh"
      bin_local="$SSHWS_BIN_OPENSSH"
      ssh_port=22
      ;;
    2)
      bin_remote="ssh-ws.dropbear"
      bin_local="$SSHWS_BIN_DROPBEAR"
      ssh_port=442
      ;;
    0) sshws_menu; return ;;
    *) echo -e "  ${RED}[!] Pilihan tidak valid${NC}"; sleep 1; install_sshws; return ;;
  esac

  echo ""
  echo -e "  ${CYAN}[*]${NC} Mendownload ${WHITE}$bin_remote${NC} dari chanelog/bin..."
  mkdir -p /etc/ssh-ws

  wget -q --timeout=30 "$REPO/$bin_remote" -O "$bin_local" 2>/dev/null
  if [[ $? -ne 0 ]] || [[ ! -s "$bin_local" ]]; then
    echo -e "  ${RED}[!] Gagal download $bin_remote${NC}"
    echo -e "  ${YELLOW}[i] Pastikan file '$bin_remote' sudah ada di repo chanelog/bin${NC}"
    rm -f "$bin_local"
    echo -ne "\n  ${DIM}Tekan Enter...${NC}"; read -r
    sshws_menu; return
  fi

  chmod +x "$bin_local"

  # Buat symlink aktif
  ln -sf "$bin_local" "$SSHWS_BIN"

  # Tulis config
  _write_config "$domain" "$ssh_port"

  # Buat systemd service
  _write_service

  systemctl daemon-reload
  systemctl enable ssh-ws 2>/dev/null
  systemctl start ssh-ws 2>/dev/null

  # Update nginx jika belum ada
  _add_nginx_sshws

  echo ""
  echo -e "  ${GREEN}[✓]${NC} SSH WebSocket (${WHITE}$bin_remote${NC}) berhasil diinstall"
  echo -e "  ${GREEN}[✓]${NC} Service ssh-ws: $(systemctl is-active ssh-ws 2>/dev/null)"
  sleep 2
  sshws_menu
}

# ─── Tulis config ssh-ws ──────────────────────────────────
_write_config() {
  local domain="$1"
  local ssh_port="${2:-22}"
  cat > "$SSHWS_CONFIG" <<EOF
# SSH WebSocket Config
# Binary: $(sshws_active_bin)
DOMAIN=$domain
SSH_PORT=$ssh_port
WS_PORT_TLS=20001
WS_PORT_NTLS=20002
PATH_TLS=/sshws
PATH_NTLS=/sshws-ntls
EOF
}

# ─── Baca nilai config ───────────────────────────────────
_cfg() {
  grep "^$1=" "$SSHWS_CONFIG" 2>/dev/null | cut -d= -f2
}

# ─── Tulis systemd service ────────────────────────────────
_write_service() {
  local ssh_port=$(_cfg SSH_PORT); ssh_port=${ssh_port:-22}
  local ws_tls=$(_cfg WS_PORT_TLS);   ws_tls=${ws_tls:-20001}
  local ws_ntls=$(_cfg WS_PORT_NTLS); ws_ntls=${ws_ntls:-20002}
  local path_tls=$(_cfg PATH_TLS);    path_tls=${path_tls:-/sshws}
  local path_ntls=$(_cfg PATH_NTLS);  path_ntls=${path_ntls:-/sshws-ntls}

  cat > "$SSHWS_SERVICE" <<EOF
[Unit]
Description=SSH WebSocket Proxy
After=network.target

[Service]
User=root
# ssh-ws.openssh/dropbear: listen WS, forward ke SSH backend
# Format flag disesuaikan dengan binary dari chanelog/bin
ExecStart=$SSHWS_BIN \\
  --ssh-port $ssh_port \\
  --ws-port $ws_tls \\
  --ntls-port $ws_ntls \\
  --path $path_tls \\
  --ntls-path $path_ntls
Restart=on-failure
LimitNOFILE=65536
StandardOutput=append:/var/log/ssh-ws.log
StandardError=append:/var/log/ssh-ws.log

[Install]
WantedBy=multi-user.target
EOF
}

# ─── Tambah nginx location untuk ssh-ws ───────────────────
_add_nginx_sshws() {
  local nginx_conf="/etc/nginx/conf.d/xray.conf"
  grep -q "location /sshws" "$nginx_conf" 2>/dev/null && return

  python3 - "$nginx_conf" <<'PYEOF' 2>/dev/null
import sys, re
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
# Sisipkan di block 443 sebelum location /vless-ws
if '/sshws' not in content:
    content = content.replace('    location /vless-ws {',
        sshws_tls + '    location /vless-ws {', 1)
# Sisipkan di block 80 sebelum location / (redirect)
    content = content.replace('    location / {\n        return 301',
        sshws_ntls + '    location / {\n        return 301', 1)

with open(conf_file, 'w') as f:
    f.write(content)
PYEOF

  nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null \
    && echo -e "  ${GREEN}[✓]${NC} Nginx location /sshws & /sshws-ntls ditambahkan" \
    || echo -e "  ${YELLOW}[!]${NC} Nginx reload gagal, cek config manual"
}

# ─── Hapus nginx location ssh-ws ──────────────────────────
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

# ─── Header menu ─────────────────────────────────────────
sshws_header() {
  clear
  local domain=$(get_domain)
  local sshws_st mode_info bin_info

  if ! sshws_installed; then
    sshws_st="${RED}● TIDAK TERINSTALL${NC}"
    mode_info="N/A"
    bin_info="N/A"
  else
    systemctl is-active --quiet ssh-ws \
      && sshws_st="${GREEN}● RUNNING${NC}" || sshws_st="${RED}● STOPPED${NC}"
    mode_info=$(sshws_mode)
    bin_info=$(sshws_active_bin)
  fi

  local ssh_port=$(_cfg SSH_PORT 2>/dev/null); ssh_port=${ssh_port:-22}

  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}          ⚡  SSH WEBSOCKET (SSHWS) MENU  ⚡${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Domain       ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}Status       ${NC}: $sshws_st"
  echo -e "  ${YELLOW}Mode         ${NC}: ${WHITE}$mode_info${NC}"
  echo -e "  ${YELLOW}Binary       ${NC}: ${WHITE}$bin_info${NC}"
  echo -e "  ${YELLOW}SSH Backend  ${NC}: ${WHITE}127.0.0.1:$ssh_port${NC}"
  echo -e "  ${YELLOW}WS TLS       ${NC}: ${WHITE}443${NC}  Path: ${WHITE}/sshws${NC}       → internal :20001"
  echo -e "  ${YELLOW}WS nTLS      ${NC}: ${WHITE}80${NC}   Path: ${WHITE}/sshws-ntls${NC}  → internal :20002"
  echo -e "${CYAN}$LINE${NC}"
}

# ─── Main menu ───────────────────────────────────────────
sshws_menu() {
  sshws_header

  if ! sshws_installed; then
    echo ""
    echo -e "  ${RED}[!] SSHWS belum terinstall${NC}"
    echo -e "  ${CYAN}$LINE${NC}"
    echo -e "  ${GREEN}[1]${NC}  Install SSHWS dari chanelog/bin"
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
  echo -e "  ${WHITE}SSHWS MANAGEMENT${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${GREEN}[1]${NC}  Start SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${RED}[2]${NC}  Stop SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[3]${NC}  Restart SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${WHITE}[4]${NC}  Lihat Status & Log"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${CYAN}[5]${NC}  Info Koneksi (URL & Payload)"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${WHITE}[6]${NC}  Lihat Konfigurasi"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[7]${NC}  Ganti Mode (OpenSSH ↔ Dropbear)"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}[8]${NC}  Update Binary"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${RED}[9]${NC}  Uninstall SSHWS"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${DIM}[0]${NC}  Kembali ke Menu Utama"
  echo -e "  ${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${WHITE}Pilih [0-9]${NC}: "
  read -r choice

  case "$choice" in
    1)
      systemctl start ssh-ws 2>/dev/null \
        && echo -e "\n  ${GREEN}[✓] SSHWS started${NC}" \
        || echo -e "\n  ${RED}[!] Gagal start SSHWS${NC}"
      sleep 2; sshws_menu ;;
    2)
      systemctl stop ssh-ws 2>/dev/null \
        && echo -e "\n  ${YELLOW}[✓] SSHWS stopped${NC}" \
        || echo -e "\n  ${RED}[!] Gagal stop SSHWS${NC}"
      sleep 2; sshws_menu ;;
    3)
      systemctl restart ssh-ws 2>/dev/null \
        && echo -e "\n  ${GREEN}[✓] SSHWS restarted${NC}" \
        || echo -e "\n  ${RED}[!] Gagal restart SSHWS${NC}"
      sleep 2; sshws_menu ;;
    4)
      echo ""
      echo -e "  ${CYAN}$LINE${NC}"
      echo -e "  ${WHITE}Status:${NC}"
      systemctl status ssh-ws --no-pager -l 2>/dev/null | head -15 | sed 's/^/  /'
      echo -e "  ${CYAN}$LINE${NC}"
      echo -e "  ${WHITE}Log terbaru:${NC}"
      tail -20 /var/log/ssh-ws.log 2>/dev/null | sed 's/^/  /' \
        || echo -e "  ${YELLOW}Log kosong${NC}"
      echo -e "  ${CYAN}$LINE${NC}"
      echo -ne "\n  ${DIM}Tekan Enter...${NC}"; read -r; sshws_menu ;;
    5) _show_conn_info ;;
    6)
      echo ""
      echo -e "  ${CYAN}$LINE${NC}"
      echo -e "  ${WHITE}Config ($SSHWS_CONFIG):${NC}"
      cat "$SSHWS_CONFIG" 2>/dev/null | sed 's/^/  /' \
        || echo -e "  ${RED}[!] File tidak ditemukan${NC}"
      echo -e "  ${CYAN}$LINE${NC}"
      echo -e "  ${WHITE}Systemd ExecStart:${NC}"
      grep "ExecStart" "$SSHWS_SERVICE" 2>/dev/null | sed 's/^/  /'
      echo -e "  ${CYAN}$LINE${NC}"
      echo -ne "\n  ${DIM}Tekan Enter...${NC}"; read -r; sshws_menu ;;
    7) _switch_mode ;;
    8)
      echo -e "\n  ${CYAN}[*]${NC} Menghentikan service..."
      systemctl stop ssh-ws 2>/dev/null
      local cur=$(sshws_active_bin)
      local bin_name=$(basename "$cur")
      echo -e "  ${CYAN}[*]${NC} Update ${WHITE}$bin_name${NC}..."
      wget -q --timeout=30 "$REPO/$bin_name" -O "$cur" 2>/dev/null \
        && chmod +x "$cur" \
        && echo -e "  ${GREEN}[✓] Binary diupdate${NC}" \
        || echo -e "  ${RED}[!] Update gagal${NC}"
      systemctl start ssh-ws 2>/dev/null
      sleep 2; sshws_menu ;;
    9) _uninstall_sshws ;;
    0) bash $SCRIPT_DIR/menu.sh ;;
    *) echo -e "  ${RED}[!] Tidak valid${NC}"; sleep 1; sshws_menu ;;
  esac
}

# ─── Ganti mode OpenSSH ↔ Dropbear ───────────────────────
_switch_mode() {
  sshws_header
  local current_mode=$(sshws_mode)
  local current_bin=$(sshws_active_bin)
  local new_bin new_remote new_port

  echo ""
  echo -e "  ${WHITE}GANTI MODE SSH BACKEND${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -e "  ${YELLOW}Mode saat ini${NC}: ${WHITE}$current_mode${NC}"
  echo ""

  if [[ "$current_mode" == "OpenSSH" ]]; then
    new_remote="ssh-ws.dropbear"
    new_bin="$SSHWS_BIN_DROPBEAR"
    new_port=442
    echo -e "  ${WHITE}Akan diganti ke${NC}: ${YELLOW}Dropbear${NC} (port 442)"
  else
    new_remote="ssh-ws.openssh"
    new_bin="$SSHWS_BIN_OPENSSH"
    new_port=22
    echo -e "  ${WHITE}Akan diganti ke${NC}: ${GREEN}OpenSSH${NC} (port 22)"
  fi

  echo ""
  echo -ne "  ${WHITE}Konfirmasi? [y/N]${NC}: "; read -r c
  [[ ! "$c" =~ ^[Yy]$ ]] && { echo -e "  ${YELLOW}Dibatalkan${NC}"; sleep 1; sshws_menu; return; }

  echo -e "  ${CYAN}[*]${NC} Menghentikan service..."
  systemctl stop ssh-ws 2>/dev/null

  # Download binary baru jika belum ada
  if [[ ! -f "$new_bin" ]]; then
    echo -e "  ${CYAN}[*]${NC} Mendownload ${WHITE}$new_remote${NC}..."
    wget -q --timeout=30 "$REPO/$new_remote" -O "$new_bin" 2>/dev/null
    if [[ ! -s "$new_bin" ]]; then
      echo -e "  ${RED}[!] Gagal download $new_remote dari chanelog/bin${NC}"
      systemctl start ssh-ws 2>/dev/null
      sleep 2; sshws_menu; return
    fi
    chmod +x "$new_bin"
  fi

  # Update symlink & config
  ln -sf "$new_bin" "$SSHWS_BIN"
  sed -i "s/^SSH_PORT=.*/SSH_PORT=$new_port/" "$SSHWS_CONFIG"
  _write_service
  systemctl daemon-reload
  systemctl start ssh-ws 2>/dev/null

  echo -e "  ${GREEN}[✓]${NC} Mode diganti ke $(sshws_mode), service direstart"
  sleep 2; sshws_menu
}

# ─── Info koneksi ────────────────────────────────────────
_show_conn_info() {
  clear
  local domain=$(get_domain)
  echo -e "${CYAN}$LINE${NC}"
  echo -e "${WHITE}         ◈  INFO KONEKSI SSH WEBSOCKET  ◈${NC}"
  echo -e "${CYAN}$LINE${NC}"
  echo ""
  echo -e "  ${PURPLE}── TLS  (HTTPS — Port 443) ──────────────────────────${NC}"
  echo -e "  ${YELLOW}Host      ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}Port      ${NC}: ${WHITE}443${NC}"
  echo -e "  ${YELLOW}Path      ${NC}: ${WHITE}/sshws${NC}"
  echo -e "  ${YELLOW}TLS       ${NC}: ${GREEN}ON${NC}"
  echo -e "  ${YELLOW}URL WS    ${NC}: ${GREEN}wss://$domain:443/sshws${NC}"
  echo ""
  echo -e "  ${PURPLE}── non-TLS  (HTTP — Port 80) ────────────────────────${NC}"
  echo -e "  ${YELLOW}Host      ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}Port      ${NC}: ${WHITE}80${NC}"
  echo -e "  ${YELLOW}Path      ${NC}: ${WHITE}/sshws-ntls${NC}"
  echo -e "  ${YELLOW}TLS       ${NC}: ${RED}OFF${NC}"
  echo -e "  ${YELLOW}URL WS    ${NC}: ${YELLOW}ws://$domain:80/sshws-ntls${NC}"
  echo ""
  echo -e "  ${PURPLE}── HTTP Custom / Injeksi Payload ────────────────────${NC}"
  echo -e "  ${YELLOW}Bug Host  ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}Payload   ${NC}: ${WHITE}GET wss://$domain/sshws HTTP/1.1[crlf]Host: $domain[crlf][crlf]${NC}"
  echo -e "  ${YELLOW}Mode HTTP ${NC}: ${WHITE}GET / HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo ""
  echo -e "  ${PURPLE}── HTTP Injector / KPN Tunnel / NPV Tunnel ──────────${NC}"
  echo -e "  ${YELLOW}Server    ${NC}: ${WHITE}$domain${NC}"
  echo -e "  ${YELLOW}Port SSH  ${NC}: ${WHITE}80 atau 443${NC}"
  echo -e "  ${YELLOW}Mode      ${NC}: ${WHITE}WebSocket${NC}"
  echo -e "  ${YELLOW}Path      ${NC}: ${WHITE}/sshws${NC} (TLS) atau ${WHITE}/sshws-ntls${NC} (non-TLS)"
  echo -e "${CYAN}$LINE${NC}"
  echo ""
  echo -ne "  ${DIM}Tekan Enter untuk kembali...${NC}"; read -r
  sshws_menu
}

# ─── Uninstall ───────────────────────────────────────────
_uninstall_sshws() {
  sshws_header
  echo ""
  echo -e "  ${RED}UNINSTALL SSHWS${NC}"
  echo -e "  ${CYAN}$LINE${NC}"
  echo -ne "  ${RED}Konfirmasi uninstall SSHWS? [y/N]${NC}: "; read -r c
  [[ ! "$c" =~ ^[Yy]$ ]] && { echo -e "  ${YELLOW}Dibatalkan${NC}"; sleep 1; sshws_menu; return; }

  systemctl stop ssh-ws 2>/dev/null
  systemctl disable ssh-ws 2>/dev/null
  rm -f "$SSHWS_BIN" "$SSHWS_BIN_OPENSSH" "$SSHWS_BIN_DROPBEAR"
  rm -f "$SSHWS_SERVICE"
  rm -rf /etc/ssh-ws
  rm -f /var/log/ssh-ws.log
  _remove_nginx_sshws
  systemctl daemon-reload 2>/dev/null

  echo -e "  ${GREEN}[✓] SSHWS berhasil diuninstall${NC}"
  sleep 2
  bash $SCRIPT_DIR/menu.sh
}

sshws_menu
