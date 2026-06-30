#!/usr/bin/env python3
"""
============================================================
  WS-SSH PROXY - WebSocket to SSH Tunnel
  Kode 100% transparan, tidak ada validasi/lisensi tersembunyi,
  tidak menghubungi server manapun selain SSH backend lokal.
============================================================

Cara kerja:
  1. Listen di port internal (mis. 20001 untuk TLS, 20002 untuk nTLS)
  2. Terima koneksi HTTP, cek apakah ini WebSocket upgrade request
  3. Kirim balik "HTTP/1.1 101 Switching Protocols" (handshake WS)
  4. Setelah handshake, semua data yang masuk dianggap sebagai
     SSH traffic mentah (bukan di-frame WS, ini mode "raw passthrough"
     yang umum dipakai HTTP Custom / Injector / NPV Tunnel)
  5. Buka koneksi TCP ke SSH backend (127.0.0.1:22 atau :442 dst)
  6. Forward data dua arah (proxy bidirectional) sampai salah satu
     sisi putus

Dependency: hanya Python standard library (asyncio, socket).
Tidak ada package eksternal yang diinstall = tidak ada
supply-chain risk dari pihak ketiga.
"""

import asyncio
import argparse
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("ws-ssh-proxy")

# Response handshake WebSocket minimal.
# Kita tidak melakukan validasi Sec-WebSocket-Key secara ketat
# karena tujuan kita cuma membuat klien (HTTP Custom/Injector/dst)
# percaya bahwa upgrade berhasil, lalu traffic SSH dikirim mentah
# di atas koneksi TCP yang sama. Ini sesuai cara kerja
# "SSH over WebSocket" yang dipakai tools sejenis (SSHWS, dsb).
WS_HANDSHAKE_RESPONSE = (
    b"HTTP/1.1 101 Switching Protocols\r\n"
    b"Upgrade: websocket\r\n"
    b"Connection: Upgrade\r\n"
    b"\r\n"
)

# Beberapa client HTTP Custom mengirim payload custom di awal
# (mis. "GET / HTTP/1.1") sebelum benar-benar upgrade. Kita balas
# dulu dengan response generic 200 supaya proses "split"/"payload"
# di app HTTP Custom berhasil, baru kirim handshake WS yang sebenarnya
# saat ada request kedua dengan header Upgrade.
HTTP_OK_RESPONSE = (
    b"HTTP/1.1 200 Connection Established\r\n\r\n"
)


async def read_http_headers(reader: asyncio.StreamReader, timeout: float = 10.0) -> bytes:
    """Baca header HTTP request sampai ketemu \\r\\n\\r\\n (atau timeout)."""
    buf = b""
    try:
        while b"\r\n\r\n" not in buf:
            chunk = await asyncio.wait_for(reader.read(1), timeout=timeout)
            if not chunk:
                break
            buf += chunk
            if len(buf) > 8192:  # safety limit, hindari header raksasa
                break
    except asyncio.TimeoutError:
        pass
    return buf


async def pipe(src: asyncio.StreamReader, dst: asyncio.StreamWriter, label: str):
    """Salin data dari src ke dst sampai koneksi putus."""
    try:
        while True:
            data = await src.read(8192)
            if not data:
                break
            dst.write(data)
            await dst.drain()
    except (ConnectionResetError, BrokenPipeError, OSError):
        pass
    finally:
        try:
            dst.close()
        except Exception:
            pass


async def handle_client(
    client_reader: asyncio.StreamReader,
    client_writer: asyncio.StreamWriter,
    ssh_host: str,
    ssh_port: int,
):
    peer = client_writer.get_extra_info("peername")
    log.info(f"Koneksi masuk dari {peer}")

    # Baca request HTTP pertama dari client (payload HTTP Custom / handshake WS)
    headers = await read_http_headers(client_reader)

    if not headers:
        log.info(f"{peer}: tidak ada data, koneksi ditutup")
        client_writer.close()
        return

    headers_text = headers.decode("utf-8", errors="ignore")
    is_ws_upgrade = "upgrade: websocket" in headers_text.lower() or "upgrade:websocket" in headers_text.lower()

    if is_ws_upgrade:
        # Langsung kirim handshake WebSocket
        client_writer.write(WS_HANDSHAKE_RESPONSE)
    else:
        # Anggap ini payload "split"/custom dari app HTTP Custom,
        # balas 200 supaya app lanjut mengirim request berikutnya
        client_writer.write(HTTP_OK_RESPONSE)

        # Beberapa client mengirim 1 request HTTP dummy lalu langsung
        # lanjut request kedua berisi upgrade websocket. Kita tunggu
        # sebentar untuk request kedua ini.
        try:
            second = await asyncio.wait_for(read_http_headers(client_reader, timeout=5.0), timeout=5.0)
            second_text = second.decode("utf-8", errors="ignore")
            if "upgrade: websocket" in second_text.lower():
                client_writer.write(WS_HANDSHAKE_RESPONSE)
        except asyncio.TimeoutError:
            # Tidak ada request kedua, lanjut saja sebagai raw passthrough
            pass

    await client_writer.drain()

    # Sambungkan ke SSH backend
    try:
        ssh_reader, ssh_writer = await asyncio.open_connection(ssh_host, ssh_port)
    except OSError as e:
        log.error(f"{peer}: gagal connect ke SSH backend {ssh_host}:{ssh_port} -> {e}")
        client_writer.close()
        return

    log.info(f"{peer}: terhubung ke SSH backend {ssh_host}:{ssh_port}, mulai forward traffic")

    # Forward dua arah secara paralel
    await asyncio.gather(
        pipe(client_reader, ssh_writer, "client->ssh"),
        pipe(ssh_reader, client_writer, "ssh->client"),
        return_exceptions=True,
    )

    log.info(f"{peer}: koneksi ditutup")


async def run_server(listen_host: str, listen_port: int, ssh_host: str, ssh_port: int, label: str):
    server = await asyncio.start_server(
        lambda r, w: handle_client(r, w, ssh_host, ssh_port),
        host=listen_host,
        port=listen_port,
    )
    log.info(f"[{label}] Listening di {listen_host}:{listen_port} -> forward ke SSH {ssh_host}:{ssh_port}")
    async with server:
        await server.serve_forever()


async def main():
    parser = argparse.ArgumentParser(description="WS-to-SSH proxy sederhana dan transparan")
    parser.add_argument("--listen-host", default="127.0.0.1", help="Host untuk listen (default: 127.0.0.1, di-proxy nginx)")
    parser.add_argument("--port-tls", type=int, default=20001, help="Port internal untuk jalur TLS (di-proxy nginx 443)")
    parser.add_argument("--port-ntls", type=int, default=20002, help="Port internal untuk jalur non-TLS (di-proxy nginx 80)")
    parser.add_argument("--ssh-host", default="127.0.0.1", help="Host SSH backend")
    parser.add_argument("--ssh-port", type=int, default=22, help="Port SSH backend (22=OpenSSH, 442=Dropbear, dst)")
    parser.add_argument("--single-port", type=int, default=None, help="Jika diisi, hanya jalankan 1 listener di port ini (abaikan --port-tls/--port-ntls)")
    args = parser.parse_args()

    tasks = []
    if args.single_port:
        tasks.append(run_server(args.listen_host, args.single_port, args.ssh_host, args.ssh_port, "SINGLE"))
    else:
        tasks.append(run_server(args.listen_host, args.port_tls, args.ssh_host, args.ssh_port, "TLS"))
        tasks.append(run_server(args.listen_host, args.port_ntls, args.ssh_host, args.ssh_port, "NTLS"))

    await asyncio.gather(*tasks)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log.info("Dihentikan oleh user")
        sys.exit(0)
