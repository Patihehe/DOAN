#!/bin/bash
# Ransomware C2 Listener tren attacker (172.20.0.5:8080) nhan beacon ma hoa tu target.
mkdir -p /tmp/c2
cd /tmp/c2
python3 -m http.server 8080 >/var/log/c2_ransom.log 2>&1 &

while true; do
  sleep 30
done
