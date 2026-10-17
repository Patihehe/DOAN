#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
PW="$1"

# 1. Tao user analyst cho sinh vien SSH sang xu ly su co (mat khau: analyst)
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null

# 2. Tao trang Web co lo hong Path Traversal & Thu muc nhay cam secret_SECID
echo "$PW" | sudo -S mkdir -p /var/www/html/secret_SECID
echo "$PW" | sudo -S bash -c 'cat > /var/www/html/index.html <<EOF
<html><body><h1>Company Portal</h1><p>Welcome to internal file viewer.</p></body></html>
EOF'

echo "$PW" | sudo -S bash -c 'cat > /var/www/html/secret_SECID/credentials.txt <<EOF
CONFIDENTIAL_FLAG=PTIT_SOC_SECRET_SECID
DB_ADMIN_USER=root
DB_ADMIN_PASS=SuperSecretRoot2026!
EOF'

# Endpoint view.php co lo hong Path Traversal (doc truc tiep tham so ?file=)
echo "$PW" | sudo -S bash -c 'cat > /var/www/html/view.php <<'"'"'EOF'"'"'
<?php
if (isset($_GET["file"])) {
    $file = $_GET["file"];
    @readfile($file);
} else {
    echo "Usage: /view.php?file=index.html";
}
?>
EOF'

# Mo quyen 755 ban dau cho secret_SECID de attacker doc duoc (200 OK) -> Sinh vien phai chmod/chown lai!
echo "$PW" | sudo -S chown -R www-data:www-data /var/www/html/secret_SECID
echo "$PW" | sudo -S chmod -R 755 /var/www/html/secret_SECID

# 3. Cau hinh Wazuh Agent doc them log Apache2 va Snort IDS
echo "$PW" | sudo -S bash -c 'cat >> /var/ossec/etc/ossec.conf <<EOF
<ossec_config>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>
  <localfile>
    <log_format>snort-full</log_format>
    <location>/var/log/snort/alert</location>
  </localfile>
</ossec_config>
EOF' 2>/dev/null || true

# 4. Khoi dong Apache2, Snort va Wazuh Agent
echo "$PW" | sudo -S systemctl enable apache2 2>/dev/null || true
echo "$PW" | sudo -S systemctl restart apache2 2>/dev/null || echo "$PW" | sudo -S service apache2 restart 2>/dev/null || true
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true
echo "$PW" | sudo -S systemctl start snort 2>/dev/null || echo "$PW" | sudo -S service snort start 2>/dev/null || true

exit 0
