# Menu Fancy untuk vpn-script (Chanelog VPN)

## Fitur
- **Layout 2-kolom**: Menu di kiri, sistem info di kanan
- **ASCII art header** yang cantik
- **Tampilan seperti screenshot** yang Anda minta
- **Terintegrasi dengan existing script** - tidak perlu install ulang

## File yang perlu di-update

### 1. **menu.sh** (ganti file yang lama)
```bash
wget -O /etc/vpn-script/menu.sh \
  https://raw.githubusercontent.com/masamuda1993/xray/main/menu.sh
chmod +x /etc/vpn-script/menu.sh
```

### 2. **menu/ohp.sh** (file baru untuk OHP Redirector)
```bash
mkdir -p /etc/vpn-script/menu
wget -O /etc/vpn-script/menu/ohp.sh \
  https://raw.githubusercontent.com/masamuda1993/xray/main/menu/ohp.sh
chmod +x /etc/vpn-script/menu/ohp.sh
```

## Cara Pakai

Setelah download kedua file, jalankan:
```bash
vpn
```

### Menu Struktur:
- **[01-06]** : Tunnel protocols (placeholder, belum full)
- **[07]**    : Settings → akses semua fitur lengkap:
  - VMess WebSocket
  - VLess WebSocket
  - SSH WebSocket (SSHWS)
  - OHP Redirector (baru!)
  - Nginx Management
  - Dropbear SSH Management
  - System Information
  - Change Domain
  - Uninstall
- **[08-12]** : Placeholder untuk fitur future
- **[0]**     : Exit

## Instalasi OHP Redirector

Dari menu utama:
1. Tekan **7** (Settings)
2. Tekan **4** (OHP Redirector)
3. Tekan **1** (Install OHP Redirector)

OHP akan install:
- **ohpserver** binary dari `chanelog/bin`
- **Squid proxy** lokal (127.0.0.1:3128)
- **SSH OHP service** (port 8181) → redirect ke SSH 22/442
- **Dropbear OHP service** (port 8282) → redirect ke Dropbear

## Untuk App HTTP Custom / HTTP Injector

Gunakan **OHP (HTTP CONNECT)** mode dengan:
- **Proxy Host**: `indo1.tytyd.eu.cc`
- **Proxy Port**: `8181` (untuk SSH via CONNECT)
- atau `8282` (untuk Dropbear via CONNECT)
- **SSL/TLS**: Enable
- **Tunnel Host**: `indo1.tytyd.eu.cc`
- **Tunnel Port**: `22` atau `442`

Atau gunakan **WebSocket mode** (SSHWS) dengan:
- **Host**: `indo1.tytyd.eu.cc`
- **Port**: `443` (TLS) atau `80` (non-TLS)
- **Path**: `/sshws` (TLS) atau `/sshws-ntls` (non-TLS)

## Notes

- File `menu.sh` menggantikan file lama sepenuhnya
- File `menu/ohp.sh` adalah file baru, tidak mengganggu yang existing
- Semua folder/file `.sh` harus di-upload ke struktur repo yang sama:
  ```
  repo/menu.sh
  repo/menu/vmess.sh
  repo/menu/vless.sh
  repo/menu/sshws.sh
  repo/menu/nginx.sh
  repo/menu/dropbear.sh
  repo/menu/sysinfo.sh
  repo/menu/changedomain.sh
  repo/menu/uninstall.sh
  repo/menu/ohp.sh        <-- file baru
  repo/lib.sh
  repo/ws-ssh-proxy.py
  repo/install.sh
  ```

## Troubleshoot

Kalau OHP service tidak start:
```bash
systemctl status ssh-ohp
journalctl -u ssh-ohp -n 50
```

Kalau Squid gagal:
```bash
systemctl status squid
systemctl restart squid
```

Cek port listening:
```bash
ss -tlnp | grep -E '8181|8282|3128'
```

## Update Install Script (opsional)

Jika mau OHP otomatis ke-install di fresh installation, edit `install.sh`:

Di function `install_script_files()`, ubah baris:
```bash
for f in vmess vless sshws nginx dropbear sysinfo changedomain uninstall; do
```

Jadi:
```bash
for f in vmess vless sshws nginx dropbear sysinfo changedomain uninstall ohp; do
```

Kemudian di `main_menu()` di `menu.sh`, ubah prompt dari:
```
echo -ne "  ${WHITE}Pilih menu [0-8]${NC}: "
```

Jadi:
```
echo -ne "  ${WHITE}Pilih menu [0-9]${NC}: "
```

Dan tambah case:
```bash
    9) bash $SCRIPT_DIR/menu/ohp.sh ;;
```

(ubah nomor menu [8] Uninstall menjadi [9] kalau perlu)

---

**Author**: Claude  
**Compatible**: Ubuntu 20.04+ / Debian 10+  
**Base**: Chanelog VPN Script  
**Binary Source**: chanelog/bin
