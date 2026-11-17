#!/bin/bash
# Chay LAN DAU tren target, quyen 'ubuntu'. $1 = mat khau sudo.
# Dung moi truong "Cong thanh toan xpayd": seed LOG SU CO dinh dang rieng + luong nhieu nen lanh tinh,
# wazuh-agent day /var/log/xpay/transactions.log ve siem. Token ACID (vi VIP cfo_<so>) va TXID (ma rut
# tien TX#<so>) ca nhan hoa qua RAND_REPLACE. Grading doc lai tu log de doi chieu findings.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }

# ===== 1) analyst cho DEFENDER SSH sang dieu tra =====
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S usermod -aG sudo analyst 2>/dev/null

# ===== 2) Thu muc cau hinh xpay + danh sach tai khoan bi khoa (SV them cfo_<so> vao day o Pha 3) =====
S mkdir -p /etc/xpay
S bash -c 'cat > /etc/xpay/locked_accounts <<EOF
# Danh sach tai khoan bi khoa (moi dong 1 username). Them cfo_<so> vao day de khoa vi VIP bi chiem.
EOF'
S chmod 644 /etc/xpay/locked_accounts

# ===== 3) Log giao dich xpayd (Wazuh giam sat) - world-writable de luong nhieu nen ghi them =====
S mkdir -p /var/log/xpay

# --- Seed LOG SU CO (dinh dang rieng: TX#..|SRC=..|USER=..|ACT=..|RES=..|AMT=..|NOTE=..) ---
# Token cfo_ACID (vi VIP) + TX#TXID (ma rut tien) da duoc RAND_REPLACE thay bang so ngau nhien.
cat > /tmp/xpay_seed.log <<'LOG'
Nov 15 08:12:03 target xpayd[2104]: TX#1001|SRC=172.20.0.30|USER=nv_hoa|ACT=LOGIN|RES=OK|AMT=0|NOTE=web_portal
Nov 15 08:12:40 target xpayd[2104]: TX#1002|SRC=172.20.0.30|USER=nv_hoa|ACT=TRANSFER|RES=OK|AMT=150000|NOTE=lunch_bill
Nov 15 08:45:11 target xpayd[2104]: TX#1003|SRC=172.20.0.31|USER=nv_minh|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=typo_pin
Nov 15 08:45:19 target xpayd[2104]: TX#1004|SRC=172.20.0.31|USER=nv_minh|ACT=LOGIN|RES=OK|AMT=0|NOTE=web_portal
Nov 15 09:03:52 target xpayd[2104]: TX#1005|SRC=172.20.0.33|USER=acct_bot|ACT=TRANSFER|RES=OK|AMT=500000|NOTE=vendor_payout
Nov 15 09:30:07 target xpayd[2104]: TX#1006|SRC=172.20.0.30|USER=nv_hoa|ACT=TRANSFER|RES=OK|AMT=250000|NOTE=office_supply
Nov 15 14:30:10 target xpayd[2190]: TX#2041|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:11 target xpayd[2191]: TX#2042|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:13 target xpayd[2192]: TX#2043|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:14 target xpayd[2193]: TX#2044|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:16 target xpayd[2194]: TX#2045|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:17 target xpayd[2195]: TX#2046|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:18 target xpayd[2198]: TX#2047|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=OK|AMT=0|NOTE=session_granted
Nov 15 14:30:22 target xpayd[2205]: TX#TXID|SRC=172.20.0.5|USER=cfo_ACID|ACT=WITHDRAW|RES=OK|AMT=85000000|NOTE=ext_wallet_drain
LOG
S cp /tmp/xpay_seed.log /var/log/xpay/transactions.log
S chmod 666 /var/log/xpay/transactions.log
rm -f /tmp/xpay_seed.log

# ===== 4) LUONG NHIEU NEN LANH TINH - giao dich hop le lien tuc (LOGIN/TRANSFER so nho, KHONG WITHDRAW) =====
#   Dung de do bao gia: AMT luon 6 chu so (<10 trieu), khong co burst FAIL -> rule dung se KHONG dinh.
S bash -c 'cat > /usr/local/bin/xpay-noise.sh <<EOF
#!/bin/bash
LOG="/var/log/xpay/transactions.log"
U=(nv_hoa nv_minh acct_bot nv_lan nv_tuan)
SRCS=(172.20.0.30 172.20.0.31 172.20.0.32 172.20.0.33)
ACTS=(LOGIN TRANSFER)
while true; do
  u=\${U[\$RANDOM % \${#U[@]}]}
  s=\${SRCS[\$RANDOM % \${#SRCS[@]}]}
  a=\${ACTS[\$RANDOM % \${#ACTS[@]}]}
  if [ "\$a" = "LOGIN" ]; then amt=0; else amt=\$(( (RANDOM % 9 + 1) * 100000 )); fi
  tx=\$(( RANDOM % 8000 + 1000 ))
  echo "\$(date "+%b %d %H:%M:%S") target xpayd[2104]: TX#\${tx}|SRC=\${s}|USER=\${u}|ACT=\${a}|RES=OK|AMT=\${amt}|NOTE=auto" >> "\$LOG"
  sleep \$(( 12 + RANDOM % 10 ))
done
EOF'
S chmod +x /usr/local/bin/xpay-noise.sh
S bash -c 'cat > /etc/cron.d/xpay-noise <<EOF
* * * * * ubuntu pgrep -f xpay-noise.sh >/dev/null || nohup /bin/bash /usr/local/bin/xpay-noise.sh >/dev/null 2>&1 &
EOF'
S chmod 644 /etc/cron.d/xpay-noise

# ===== 5) Phieu dieu tra ~/findings.txt (5 cau - SV tu doc log de dien) =====
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA SU CO XPAY - dien gia tri TU TIM (KEY=value):
# LOG_PROGRAM  : ten chuong trinh (program_name) sinh ra dong log la
# ATTACKER_IP  : IP (SRC) brute-force va rut tien trai phep
# VICTIM_USER  : tai khoan vi VIP bi chiem doat (dang cfo_<so>)
# FRAUD_TX_ID  : ma giao dich cua lenh rut tien trai phep (dang TX#<so>)
# FRAUD_AMOUNT : so tien bi rut trai phep (chi so, VND)
LOG_PROGRAM=
ATTACKER_IP=
VICTIM_USER=
FRAUD_TX_ID=
FRAUD_AMOUNT=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt
rm -f /tmp/findings.txt

# ===== 6) Wazuh agent: giam sat /var/log/xpay/transactions.log (day ve manager de hien dashboard) =====
S bash -c 'grep -q "xpay/transactions.log" /var/ossec/etc/ossec.conf 2>/dev/null || cat >> /var/ossec/etc/ossec.conf <<EOF
<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/xpay/transactions.log</location>
  </localfile>
</ossec_config>
EOF'
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# ===== 7) Khoi dong cron + luong nhieu nen =====
S systemctl restart cron 2>/dev/null || S service cron restart 2>/dev/null || true
setsid /bin/bash /usr/local/bin/xpay-noise.sh >/dev/null 2>&1 < /dev/null &

exit 0
