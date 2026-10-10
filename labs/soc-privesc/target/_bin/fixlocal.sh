#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# Gieo 2 lo hong leo quyen + tai khoan devuser (bi chiem) + FIM giam sat.
PW="$1"

# ============ 1) Tai khoan devuser (bi chiem, mat khau yeu, SSH duoc) ============
echo "$PW" | sudo -S useradd -m -s /bin/bash devuser 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "devuser:devpass123" | chpasswd'
# Bat password auth cho sshd (de attacker SSH bang mat khau)
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
echo "$PW" | sudo -S service ssh restart 2>/dev/null || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null || true

# ============ 2) LO HONG 1: SUID root tren /usr/bin/find ============
echo "$PW" | sudo -S chmod u+s /usr/bin/find

# ============ 3) LO HONG 2: sudo NOPASSWD awk cho devuser ============
echo "$PW" | sudo -S bash -c 'echo "devuser ALL=(ALL) NOPASSWD: /usr/bin/awk" > /etc/sudoers.d/devuser; chmod 440 /etc/sudoers.d/devuser'

# ============ 4) Wazuh FIM: giam sat /root, /tmp, /etc/sudoers.d realtime ============
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/root,/tmp,/etc/sudoers.d</directories>'
echo "$PW" | sudo -S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 5) Tai khoan analyst cho DEFENDER SSH sang hardening ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA - dien gia tri ban tim duoc (giu dinh dang KEY=value):
VECTOR1=
VECTOR2=
TAI_KHOAN_BI_CHIEM=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
