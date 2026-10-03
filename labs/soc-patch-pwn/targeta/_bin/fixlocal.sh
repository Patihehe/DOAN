#!/bin/bash
# Chay LAN DAU tren targeta (he A), quyen user 'ubuntu'. $1 = mat khau sudo.
# Web ping.php dinh COMMAND INJECTION + ModSecurity cai san (TAT) + Wazuh agent + analyst.
PW="$1"

# ============ 1) Web app dinh command injection ============
cat > /tmp/ping.php <<'PHP'
<?php
// Cong cu kiem tra mang (CO LO HONG: noi chuoi vao lenh shell)
$host = isset($_GET['host']) ? $_GET['host'] : '127.0.0.1';
echo "<h3>Ping</h3><pre>";
system("ping -c1 " . $host);   // <== LO HONG: command injection
echo "</pre>";
?>
PHP
cat > /tmp/index.php <<'PHP'
<?php echo "<h2>NetTools</h2><a href='ping.php?host=127.0.0.1'>Ping 127.0.0.1</a>"; ?>
PHP
echo "$PW" | sudo -S mkdir -p /var/www/html
echo "$PW" | sudo -S cp /tmp/ping.php /tmp/index.php /var/www/html/
echo "$PW" | sudo -S rm -f /var/www/html/index.html 2>/dev/null

# ============ 2) ModSecurity: bat module, TAT engine (SV tu bat + viet rule) ============
for m in security2 php7.0 php7.2 php7.4 php8.1 php; do echo "$PW" | sudo -S a2enmod "$m" 2>/dev/null; done
echo "$PW" | sudo -S bash -c 'cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf 2>/dev/null'
echo "$PW" | sudo -S sed -i 's/^\s*SecRuleEngine .*/SecRuleEngine Off/' /etc/modsecurity/modsecurity.conf 2>/dev/null

# ============ 3) Khoi dong Apache ============
echo "$PW" | sudo -S systemctl enable apache2 2>/dev/null
echo "$PW" | sudo -S systemctl restart apache2 2>/dev/null \
  || echo "$PW" | sudo -S service apache2 restart 2>/dev/null || true

# ============ 4) Wazuh agent giam sat access.log ============
LF='<localfile><log_format>apache</log_format><location>/var/log/apache2/access.log</location></localfile>'
echo "$PW" | sudo -S sed -i "s#</ossec_config>#${LF}</ossec_config>#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null \
  || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 5) analyst cho DEFENDER SSH sang va he A ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO - dien gia tri ban tim duoc (giu dinh dang KEY=value):
PAYLOAD=
FLAG=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
