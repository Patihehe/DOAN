#!/bin/bash
# soc-secrets-leak - target: dung web app + MariaDB + .git lo bi mat.
# Chay bang ROOT. Co the chay lai nhieu lan (xoa DB/.git cu truoc khi dung lai).
set -u
WEB=/var/www/html
APP=/var/www/app
LOGD=/var/log/webapp

# ---------- 1. Khoi dong MariaDB va cho san sang ----------
systemctl enable mariadb >/dev/null 2>&1 || true
systemctl start mariadb >/dev/null 2>&1 || service mariadb start >/dev/null 2>&1 || service mysql start >/dev/null 2>&1 || true
for i in $(seq 1 60); do mysql -e 'SELECT 1' >/dev/null 2>&1 && break; sleep 3; done

# ---------- 2. Hash bcrypt cho mat khau admin va ops ----------
H_ADMIN=$(php -r 'echo password_hash("Adm-ADMNUM", PASSWORD_DEFAULT);')
H_OPS=$(php -r 'echo password_hash("Ops-OPSNUM", PASSWORD_DEFAULT);')

# ---------- 3. Tao DB, user, bang, du lieu ----------
mysql <<SQL || echo "LOI: nap SQL that bai (xem thong bao o tren)" >&2
DROP DATABASE IF EXISTS portal;
CREATE DATABASE portal CHARACTER SET utf8mb4;
GRANT USAGE ON *.* TO 'appuser'@'localhost' IDENTIFIED BY 'Db-DBNUM';
GRANT ALL PRIVILEGES ON portal.* TO 'appuser'@'localhost';
USE portal;
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL
);
INSERT INTO users (username, password_hash, role) VALUES
  ('admin', '$H_ADMIN', 'admin'),
  ('ops',   '$H_OPS',   'ops');
CREATE TABLE customers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL,
  card_last4 CHAR(4) NOT NULL
);
INSERT INTO customers (name, email, card_last4) VALUES
  ('Nguyen Van An',   'an.nguyen@example.com',   '4417'),
  ('Tran Thi Binh',   'binh.tran@example.com',   '1029'),
  ('Le Van Cuong',    'cuong.le@example.com',    '7731'),
  ('Pham Thi Dung',   'dung.pham@example.com',   '3382'),
  ('Hoang Van Em',    'em.hoang@example.com',    '5560'),
  ('Vu Thi Phuong',   'phuong.vu@example.com',   '9014'),
  ('Dang Van Giang',  'giang.dang@example.com',  '2248'),
  ('Bui Thi Hoa',     'hoa.bui@example.com',     '6673'),
  ('Do Van Khanh',    'khanh.do@example.com',    '8105'),
  ('Ngo Thi Lan',     'lan.ngo@example.com',     '3947'),
  ('Duong Van Minh',  'minh.duong@example.com',  '1856'),
  ('Ly Thi Nga',      'nga.ly@example.com',      '7092');
SQL

# ---------- 4. Thu muc, log, config that (NGOAI webroot) ----------
mkdir -p "$WEB" "$APP" "$LOGD" "$WEB/api"
touch "$LOGD/auth.log"
chown -R www-data:www-data "$LOGD"
chmod 755 "$LOGD"
chmod 644 "$LOGD/auth.log"

cat > "$APP/config.php" <<'EOF'
<?php
// Config that cua app (nam ngoai webroot)
date_default_timezone_set('Asia/Ho_Chi_Minh');
mysqli_report(MYSQLI_REPORT_OFF);
define('API_KEY', 'Api-APINUM');
function db() {
    $m = @new mysqli('localhost', 'appuser', 'Db-DBNUM', 'portal');
    if ($m->connect_errno) {
        http_response_code(503);
        echo 'Dich vu tam thoi khong san sang (DB).';
        exit;
    }
    return $m;
}
function client_ip() { return $_SERVER['REMOTE_ADDR'] ?? '-'; }
function clean($s) { return preg_replace('/[^A-Za-z0-9_.@-]/', '_', (string)$s); }
function log_auth($line) {
    @file_put_contents('/var/log/webapp/auth.log',
        date('M d H:i:s') . ' target corpportal: ' . $line . "\n", FILE_APPEND | LOCK_EX);
}
EOF
chown root:www-data "$APP/config.php"
chmod 640 "$APP/config.php"

# ---------- 5. Cac trang web ----------
cat > "$WEB/index.php" <<'EOF'
<?php
require '/var/www/app/config.php';
$m = db();
$n = $m->query('SELECT COUNT(*) FROM customers')->fetch_row()[0];
?>
<!doctype html>
<html><head><meta charset="utf-8"><title>Cong thong tin khach hang</title></head>
<body>
<h1>Cong thong tin khach hang</h1>
<p>Tong so khach hang dang quan ly: <?php echo (int)$n; ?></p>
<p><a href="/login.php">Dang nhap noi bo</a></p>
</body></html>
EOF

cat > "$WEB/login.php" <<'EOF'
<?php
require '/var/www/app/config.php';
session_start();
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = (string)($_POST['username'] ?? '');
    $p = (string)($_POST['password'] ?? '');
    $m = db();
    $st = $m->prepare('SELECT password_hash, role FROM users WHERE username = ?');
    $st->bind_param('s', $u);
    $st->execute();
    $st->bind_result($h, $role);
    if ($st->fetch() && password_verify($p, $h)) {
        $_SESSION['user'] = $u;
        $_SESSION['role'] = $role;
        log_auth('LOGIN_OK user=' . clean($u) . ' ip=' . client_ip());
        header('Location: /dashboard.php');
        exit;
    }
    log_auth('LOGIN_FAIL user=' . clean($u) . ' ip=' . client_ip());
    http_response_code(401);
    $err = 'Sai tai khoan hoac mat khau.';
}
?>
<!doctype html>
<html><head><meta charset="utf-8"><title>Dang nhap</title></head>
<body>
<h1>Dang nhap noi bo</h1>
<?php if ($err) echo '<p style="color:red">' . htmlspecialchars($err) . '</p>'; ?>
<form method="post" action="/login.php">
  <input name="username" placeholder="tai khoan"><br>
  <input name="password" type="password" placeholder="mat khau"><br>
  <button type="submit">Dang nhap</button>
</form>
</body></html>
EOF

cat > "$WEB/dashboard.php" <<'EOF'
<?php
require '/var/www/app/config.php';
session_start();
if (empty($_SESSION['user'])) { header('Location: /login.php'); exit; }
$m = db();
$n = $m->query('SELECT COUNT(*) FROM customers')->fetch_row()[0];
?>
<!doctype html>
<html><head><meta charset="utf-8"><title>Dashboard</title></head>
<body>
<h1>Dashboard</h1>
<p>Xin chao <?php echo htmlspecialchars($_SESSION['user']); ?> (<?php echo htmlspecialchars($_SESSION['role']); ?>)</p>
<p>Tong so khach hang: <?php echo (int)$n; ?></p>
<?php if ($_SESSION['role'] === 'admin') echo '<p><a href="/export.php">Xuat du lieu khach hang</a></p>'; ?>
</body></html>
EOF

cat > "$WEB/export.php" <<'EOF'
<?php
require '/var/www/app/config.php';
session_start();
if (empty($_SESSION['user']) || ($_SESSION['role'] ?? '') !== 'admin') {
    http_response_code(403);
    echo 'Khong co quyen.';
    exit;
}
$m = db();
$res = $m->query('SELECT id, name, email, card_last4 FROM customers ORDER BY id');
header('Content-Type: text/csv');
echo "id,name,email,card_last4\n";
$rows = 0;
while ($r = $res->fetch_assoc()) {
    echo $r['id'] . ',' . $r['name'] . ',' . $r['email'] . ',' . $r['card_last4'] . "\n";
    $rows++;
}
log_auth('EXPORT user=' . clean($_SESSION['user']) . ' ip=' . client_ip() . ' rows=' . $rows);
EOF

cat > "$WEB/api/info.php" <<'EOF'
<?php
require '/var/www/app/config.php';
header('Content-Type: application/json');
$k = (string)($_SERVER['HTTP_X_API_KEY'] ?? '');
if (!hash_equals(API_KEY, $k)) {
    http_response_code(401);
    echo '{"error":"unauthorized"}';
    exit;
}
$m = db();
$n = $m->query('SELECT COUNT(*) FROM customers')->fetch_row()[0];
echo json_encode(array('customers' => (int)$n));
EOF

rm -f "$WEB/index.html"
chmod -R a+rX "$WEB"

# ---------- 6. Lich su git co chua bi mat ----------
cd "$WEB" || exit 1
rm -rf .git .env
git init -q
printf 'ADMIN_USER=admin\nADMIN_PASS=Adm-ADMNUM\nAPI_KEY=Api-APINUM\n' > .env
git add -A
git -c user.name=dev -c user.email=dev@corp.local commit -q -m "initial import"
git rm -q .env
git -c user.name=dev -c user.email=dev@corp.local commit -q -m "remove env"
chmod -R a+rX .git

# ---------- 7. Hai file lo con lai (KHONG dua vao git) ----------
cat > "$WEB/config.php.bak-BAKNUM" <<'EOF'
<?php
// config cu, truoc khi tach API - nho xoa
$DB_HOST = 'localhost';
$DB_USER = 'appuser';
$DB_PASS = 'Db-DBNUM';
$DB_NAME = 'portal';
EOF
printf 'SMTP_HOST=mail.corp.local\nSMTP_USER=noreply\nSMTP_PASS=Smtp-SMTPNUM\n' > "$WEB/.env.old"
chmod 644 "$WEB/config.php.bak-BAKNUM" "$WEB/.env.old"

# ---------- 8. Khoi dong lai Apache ----------
systemctl enable apache2 >/dev/null 2>&1 || true
systemctl restart apache2 >/dev/null 2>&1 || service apache2 restart >/dev/null 2>&1 || true

# ---------- 9. Ground-truth cho prestop (chi root doc, KHONG bao gio in ra man hinh) ----------
cat > /root/.soc_truth <<EOF
ATTACKER_IP=172.20.0.5
OLD_ADMIN_PASS=Adm-ADMNUM
OLD_DB_PASS=Db-DBNUM
OLD_API_KEY=Api-APINUM
OPS_PASS=Ops-OPSNUM
LEAKED=GIT_HISTORY,BACKUP_FILE
EXPOSED_UNTOUCHED=SMTP_FILE
BAKFILE=config.php.bak-BAKNUM
EOF
chmod 600 /root/.soc_truth
chown root:root /root/.soc_truth

# ---------- 10. Tai khoan analyst (SV dung de dieu tra & xu ly) ----------
id -u analyst >/dev/null 2>&1 || useradd -ms /bin/bash analyst
echo "analyst:analyst" | chpasswd
usermod -aG adm,www-data analyst

# Webroot + config: nhom www-data duoc GHI (xoa artifact lo, sua config.php).
# 2770/2775 (setgid) de file/thu muc moi tao cung ke thua nhom www-data.
chgrp www-data /var/www/html /var/www/app
chmod 2775 /var/www/html
chmod 2770 /var/www/app
chmod 660 /var/www/app/config.php

# .git duoc tao TRUOC khi co chgrp/chmod tren (section 6), nen cac file/thu muc
# ben trong van la mode 755 cua root - 2775 o /var/www/html KHONG lan truyen
# nguoc vao do. Phai chgrp+chmod g+w RIENG cho .git de analyst (nhom www-data)
# xoa duoc ma khong can cap sudo rm toan quyen root (tranh mo rong be mat sudo).
chgrp -R www-data /var/www/html/.git 2>/dev/null
chmod -R g+w /var/www/html/.git 2>/dev/null

# sshd: cho analyst SSH tu defender vao (giong cac lab SOC khac trong bo).
if ! command -v sshd >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server \
        && rm -rf /var/lib/apt/lists/*
fi
systemctl enable ssh >/dev/null 2>&1 || systemctl enable sshd >/dev/null 2>&1 || true
systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true

# Tai khoan MariaDB 'secops': CHI duoc UPDATE password_hash cua admin (khong doc duoc hash,
# khong sua duoc cot khac, khong dung duoc bang khac). Dung de analyst doi mat khau admin
# trong app ma khong can biet mat khau that cua appuser.
# Dang nhap qua unix_socket (khop theo TEN TAI KHOAN HE DIEU HANH, khong dat mat khau) -
# vi day la cong cu duoc CAP SAN cho analyst dung, khong phai bi mat can dieu tra,
# nen khong the ca nhan hoa bang so ngau nhien (analyst se khong co cach nao biet so do).
id -u secops >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin secops
# "DROP USER IF EXISTS" la cu phap MariaDB 10.1.3+ - may muc tieu co the la ban cu hon,
# nen tach rieng DROP (bo qua loi "user khong ton tai") thay vi dung IF EXISTS trong 1 khoi.
mysql -e "DROP USER 'secops'@'localhost'" 2>/dev/null || true
mysql <<SQL
CREATE USER 'secops'@'localhost' IDENTIFIED VIA unix_socket;
GRANT SELECT (username) ON portal.users TO 'secops'@'localhost';
GRANT UPDATE (password_hash) ON portal.users TO 'secops'@'localhost';
FLUSH PRIVILEGES;
SQL

# Script co dinh, KHONG tham so, chay bang root qua sudo: doi mat khau MySQL that cua
# appuser. Dung sudo cho hanh dong nay (thay vi cap quyen SQL) vi cach doi mat khau
# nguoi khac trong MariaDB khac nhau giua cac phien ban; chay bang root luon dung.
cat > /usr/local/bin/rotate-db-password.sh <<'ROTEOF'
#!/bin/bash
# Chay bang root (qua sudo). Doi mat khau MySQL that cua tai khoan 'appuser'.
# KHONG nhan tham so dong lenh (tranh injection qua sudoers wildcard) - hoi truc tiep.
set -euo pipefail
read -r -s -p "Nhap mat khau MySQL MOI cho appuser: " NEWPW
echo
if [ -z "$NEWPW" ]; then
    echo "Mat khau rong, huy." >&2
    exit 1
fi
# Thoat dau nhay don theo dung cu phap SQL (nhan doi ' thanh ''), KHONG phai kieu thoat cua bash
ESCAPED=$(printf '%s' "$NEWPW" | sed "s/'/''/g")
mysql -e "SET PASSWORD FOR 'appuser'@'localhost' = PASSWORD('${ESCAPED}')"
echo "Da doi mat khau MySQL cua appuser."
echo "NHO: cap nhat lai gia tri nay trong /var/www/app/config.php (bien \$DB_PASS trong ham db())."
ROTEOF
chown root:root /usr/local/bin/rotate-db-password.sh
chmod 700 /usr/local/bin/rotate-db-password.sh

# Sudoers rieng cho analyst: CHI iptables (chan dung 1 IP) + dung script rotate o tren.
# KHONG dua analyst vao nhom %sudo (nhom do co the duoc cap sudo cat/grep khong gioi han
# cho 'ubuntu' de phuc vu prestop - neu analyst vao chung nhom se doc duoc /root/.soc_truth).
cat > /etc/sudoers.d/90-secrets-leak-analyst <<'SUDOEOF'
analyst ALL=(root) NOPASSWD: /usr/sbin/iptables -A INPUT -s * -j DROP, /usr/sbin/iptables -S
analyst ALL=(root) NOPASSWD: /sbin/iptables -A INPUT -s * -j DROP, /sbin/iptables -S
analyst ALL=(root) NOPASSWD: /usr/local/bin/rotate-db-password.sh
analyst ALL=(secops) NOPASSWD: /usr/bin/mysql
SUDOEOF
chmod 440 /etc/sudoers.d/90-secrets-leak-analyst

echo "setup_app.sh xong"
