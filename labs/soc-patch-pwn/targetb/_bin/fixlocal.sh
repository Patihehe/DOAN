#!/bin/bash
# Chay LAN DAU tren targetb (he B), quyen user 'ubuntu'. $1 = mat khau sudo.
# He B co lo hong command injection Y HET A, nhung KHONG duoc va -> SV khai thac lay flag.
PW="$1"

# Web app dinh command injection (giong A)
cat > /tmp/ping.php <<'PHP'
<?php
$host = isset($_GET['host']) ? $_GET['host'] : '127.0.0.1';
echo "<h3>Ping</h3><pre>";
system("ping -c1 " . $host);   // LO HONG: command injection
echo "</pre>";
?>
PHP
cat > /tmp/index.php <<'PHP'
<?php echo "<h2>NetTools (prod)</h2><a href='ping.php?host=127.0.0.1'>Ping</a>"; ?>
PHP
echo "$PW" | sudo -S mkdir -p /var/www/html
echo "$PW" | sudo -S cp /tmp/ping.php /tmp/index.php /var/www/html/
echo "$PW" | sudo -S rm -f /var/www/html/index.html 2>/dev/null

# Flag (ca nhan hoa) - www-data doc duoc -> SV phai RCE moi lay ra
echo 'FLAG-FLAGVAL' > /tmp/flag.txt
echo "$PW" | sudo -S cp /tmp/flag.txt /var/www/flag.txt
echo "$PW" | sudo -S chmod 644 /var/www/flag.txt
echo "$PW" | sudo -S rm -f /tmp/flag.txt

# Khoi dong Apache
echo "$PW" | sudo -S systemctl enable apache2 2>/dev/null
echo "$PW" | sudo -S systemctl restart apache2 2>/dev/null \
  || echo "$PW" | sudo -S service apache2 restart 2>/dev/null || true

exit 0
