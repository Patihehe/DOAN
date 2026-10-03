#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# Dung: web app dinh SQLi (Apache+PHP+SQLite), ModSecurity cai san nhung TAT,
#       agent Wazuh day access.log, tai khoan analyst cho defender SSH sang.
PW="$1"

# ============ 1) Trien khai web app dinh SQLi ============
cat > /tmp/index.php <<'PHP'
<?php
echo "<h2>Shop Demo</h2>";
echo "<ul>";
echo "<li><a href='product.php?id=1'>Xem san pham id=1</a></li>";
echo "<li><a href='login.php?user=guest&pass=guest'>Dang nhap</a></li>";
echo "</ul>";
?>
PHP

# product.php - LO HONG: noi chuoi tham so 'id' truc tiep vao cau SQL
cat > /tmp/product.php <<'PHP'
<?php
$db = new SQLite3('/var/www/db/shop.db');
$id = isset($_GET['id']) ? $_GET['id'] : '1';
$sql = "SELECT name, price FROM products WHERE id = $id";
$res = @$db->query($sql);
echo "<h3>San pham</h3>";
if ($res) {
  while ($row = $res->fetchArray(SQLITE3_ASSOC)) {
    echo htmlspecialchars($row['name'])." - ".htmlspecialchars($row['price'])."<br>";
  }
} else {
  echo "Query error";
}
?>
PHP

# login.php - LO HONG: noi chuoi user/pass -> ' OR '1'='1
cat > /tmp/login.php <<'PHP'
<?php
$db = new SQLite3('/var/www/db/shop.db');
$u = isset($_GET['user']) ? $_GET['user'] : '';
$p = isset($_GET['pass']) ? $_GET['pass'] : '';
$sql = "SELECT * FROM users WHERE user='$u' AND pass='$p'";
$res = @$db->query($sql);
$ok = $res && $res->fetchArray();
echo $ok ? "Login OK" : "Login FAILED";
?>
PHP

echo "$PW" | sudo -S mkdir -p /var/www/html
echo "$PW" | sudo -S cp /tmp/index.php /tmp/product.php /tmp/login.php /var/www/html/
echo "$PW" | sudo -S rm -f /var/www/html/index.html 2>/dev/null

# ============ 2) Tao CSDL SQLite (co "secret" ca nhan hoa) ============
rm -f /tmp/shop.db
sqlite3 /tmp/shop.db <<'SQL'
CREATE TABLE products(id INTEGER, name TEXT, price TEXT);
INSERT INTO products VALUES(1,'Keyboard','20');
INSERT INTO products VALUES(2,'Mouse','10');
INSERT INTO products VALUES(3,'Monitor','150');
CREATE TABLE users(user TEXT, pass TEXT);
INSERT INTO users VALUES('admin','S3cr3tAdmin');
CREATE TABLE secret_store(secret TEXT);
INSERT INTO secret_store VALUES('FLAG-SECRETVAL');
SQL
echo "$PW" | sudo -S mkdir -p /var/www/db
echo "$PW" | sudo -S cp /tmp/shop.db /var/www/db/shop.db
echo "$PW" | sudo -S chown -R www-data:www-data /var/www/db
echo "$PW" | sudo -S chmod 775 /var/www/db
echo "$PW" | sudo -S chmod 664 /var/www/db/shop.db

# ============ 3) ModSecurity: BAT module nhung TAT engine (SV tu bat + viet rule) ============
for m in security2 php7.0 php7.2 php7.4 php8.1 php; do
  echo "$PW" | sudo -S a2enmod "$m" 2>/dev/null
done
# Dat config mac dinh roi chuyen SecRuleEngine -> Off (trang thai ban dau: CHUA bao ve)
echo "$PW" | sudo -S bash -c 'cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf 2>/dev/null'
echo "$PW" | sudo -S sed -i 's/^\s*SecRuleEngine .*/SecRuleEngine Off/' /etc/modsecurity/modsecurity.conf 2>/dev/null
# KHONG tao custom rule -> de sinh vien tu viet trong /etc/modsecurity/custom.conf

# ============ 4) Khoi dong Apache ============
echo "$PW" | sudo -S systemctl enable apache2 2>/dev/null
echo "$PW" | sudo -S systemctl restart apache2 2>/dev/null \
  || echo "$PW" | sudo -S service apache2 restart 2>/dev/null || true

# ============ 5) Wazuh agent giam sat access.log ============
LF='<localfile><log_format>apache</log_format><location>/var/log/apache2/access.log</location></localfile>'
echo "$PW" | sudo -S sed -i "s#</ossec_config>#${LF}</ossec_config>#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null \
  || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 6) Tai khoan analyst cho DEFENDER SSH sang xu ly ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA - dien gia tri ban tim duoc (giu dung dinh dang KEY=value):
PARAM=
ATTACKER_IP=
SECRET=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
