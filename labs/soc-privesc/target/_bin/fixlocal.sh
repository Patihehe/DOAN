#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# Thiet lap: foothold emp<EMPNUM> (ca nhan hoa) + 2 duong leo quyen + FIM + ground-truth.
PW="$1"
VICTIM=empEMPNUM; VPW=Password123

# ============ 1) Foothold: tai khoan bi chiem (ca nhan hoa, mat khau yeu) ============
echo "$PW" | sudo -S useradd -m -s /bin/bash "$VICTIM" 2>/dev/null
echo "$PW" | sudo -S bash -c "echo '$VICTIM:$VPW' | chpasswd"
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
# GIU PermitRootLogin mac dinh (prohibit-password) - thuc te. Ke tan cong quay lai bang SSH KEY
# (prohibit-password van cho root dang nhap bang key), con tin hieu dinh ky do cronjob tao ra.
echo "$PW" | sudo -S service ssh restart 2>/dev/null || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null || true
# Bao dam rsyslog chay -> auth.log ghi day du (Accepted/sudo/new user) cho timeline & SIEM
echo "$PW" | sudo -S service rsyslog start 2>/dev/null || echo "$PW" | sudo -S systemctl start rsyslog 2>/dev/null || true

# ============ 2) LO HONG 1: SUID root tren /usr/bin/find ============
echo "$PW" | sudo -S chmod u+s /usr/bin/find

# ============ 3) LO HONG 2: sudo NOPASSWD awk cho tai khoan bi chiem ============
echo "$PW" | sudo -S bash -c "echo '$VICTIM ALL=(ALL) NOPASSWD: /usr/bin/awk' > /etc/sudoers.d/$VICTIM; chmod 440 /etc/sudoers.d/$VICTIM"

# ============ 4) Ground-truth cho grader (chi root doc) - ten ca nhan hoa ============
echo "$PW" | sudo -S bash -c "printf 'ACCT=%s\nBACKDOOR=%s\n' '$VICTIM' 'svc-EMPNUM' > /root/.soc_truth; chmod 600 /root/.soc_truth"

# ============ 5) Wazuh FIM: giam sat /etc/passwd, /etc/sudoers.d, /root, /tmp realtime ============
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/etc/passwd,/etc/sudoers.d,/etc/cron.d,/root,/tmp,/usr/local/bin</directories>'
echo "$PW" | sudo -S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 6) Tai khoan analyst cho DEFENDER SSH sang ung pho ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA SU CO - dien gia tri ban TU TIM DUOC (giu dinh dang KEY=value):
# -- Danh tinh (dung ten/IP THAT tren he thong cua ban) --
COMPROMISED=
IP_KE_TAN_CONG=
# -- Chuoi tan cong (neu RO CO CHE, khong chi 1 tu) --
# VECTOR1 vd: "SUID /usr/bin/find"   (phai neu 'find' VA dau hieu SUID)
# VECTOR2 vd: "sudo NOPASSWD awk"    (phai neu 'sudo' VA 'awk')
VECTOR1=
VECTOR2=
BACKDOOR=
# -- Timeline (dang HH:MM) - PHAI KHOP GIO THAT trong auth.log/SIEM (cham dung sai +-1 phut) --
# 3 moc xay ra o 3 thoi diem KHAC NHAU (cach nhau ~2'): dang nhap -> leo quyen -> cai backdoor.
TIME_ACCESS=
TIME_ESCALATION=
TIME_PERSIST=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
