#!/bin/bash
# targeta (he A - NoteBox, MariaDB), quyen 'ubuntu'. $1 = mat khau sudo.
# App THAT: dang ky/dang nhap (MD5) + tao/xem/tim note. Lo hong:
#   - UNION SQLi o /search.php (+ verbose SQL error)   -> dump users, crack MD5 -> admin
#   - Stored XSS o /admin.php (in body note khong escape) -> cuop cookie admin
# He A KHONG chua flag that (sentinel cho checker). Flag/XSSflag that o he B.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }
mkdir -p /tmp/nb

cat > /tmp/nb/config.php <<'PHP'
<?php
session_start();
mysqli_report(MYSQLI_REPORT_OFF);
function db(){ $m=@new mysqli('localhost','nbuser','nbpass','notebox'); if($m->connect_errno){ http_response_code(503); echo 'Dich vu tam thoi khong san sang (DB).'; exit; } return $m; }
function uid(){ return isset($_SESSION['uid'])?intval($_SESSION['uid']):0; }
function uname(){ return isset($_SESSION['username'])?$_SESSION['username']:''; }
function urole(){ return isset($_SESSION['role'])?$_SESSION['role']:'user'; }
function require_login(){ if(!uid()){ header('Location: index.php'); exit; } }
function hdr($t){ echo "<!doctype html><html><head><meta charset=utf-8><title>".$t." - NoteBox</title><style>body{font-family:system-ui,Arial,sans-serif;max-width:760px;margin:24px auto;padding:0 16px;color:#222}h1,h2{color:#2a4d7a}a{color:#1a7f5a;text-decoration:none}input,textarea{width:100%;padding:8px;margin:4px 0;box-sizing:border-box}button{background:#2a4d7a;color:#fff;padding:8px 16px;border:0;border-radius:4px;cursor:pointer}.card{border:1px solid #e0e0e0;border-radius:8px;padding:14px;margin:10px 0}.nav{background:#2a4d7a;color:#fff;padding:10px 14px;border-radius:8px;margin-bottom:14px}.nav a{color:#fff;margin-right:14px}</style></head><body>"; }
function ftr(){ echo "</body></html>"; }
function nav(){ echo "<div class=nav><b>NoteBox</b> &nbsp; <a href=dashboard.php>Ghi chu</a> <a href=admin.php>Admin</a> <a href=logout.php>Dang xuat</a></div>"; }
PHP

cat > /tmp/nb/index.php <<'PHP'
<?php require __DIR__.'/config.php';
if(uid()){ header('Location: dashboard.php'); exit; }
hdr('Dang nhap'); ?>
<h1>NoteBox</h1><p>Dich vu luu tru ghi chu ca nhan.</p>
<div class=card><h2>Dang nhap</h2>
<form method=post action=login.php>
<input name=username placeholder="Ten dang nhap">
<input name=password type=password placeholder="Mat khau">
<button>Dang nhap</button></form>
<p>Chua co tai khoan? <a href=register.php>Dang ky</a></p></div>
<?php ftr();
PHP

cat > /tmp/nb/register.php <<'PHP'
<?php require __DIR__.'/config.php'; $db=db(); $msg='';
if((isset($_SERVER['REQUEST_METHOD'])?$_SERVER['REQUEST_METHOD']:'')==='POST'){
  $u=trim(isset($_POST['username'])?$_POST['username']:''); $p=isset($_POST['password'])?$_POST['password']:'';
  if($u!=='' && $p!==''){
    $st=$db->prepare('INSERT INTO users(username,password,role) VALUES(?,?,?)');
    $h=crypt($p,'$1$'.substr(bin2hex(random_bytes(4)),0,8)); $role='user'; $st->bind_param('sss',$u,$h,$role); $st->execute();
    $_SESSION['uid']=$db->insert_id; $_SESSION['username']=$u; $_SESSION['role']='user';
    header('Location: dashboard.php'); exit;
  }
  $msg='Nhap day du ten dang nhap va mat khau.';
}
hdr('Dang ky'); ?>
<h2>Dang ky tai khoan</h2>
<?php if($msg){ echo "<p style=\"color:#c00\">".htmlspecialchars($msg)."</p>"; } ?>
<div class=card><form method=post action=register.php>
<input name=username placeholder="Ten dang nhap">
<input name=password type=password placeholder="Mat khau">
<button>Tao tai khoan</button></form>
<p><a href=index.php>Quay lai dang nhap</a></p></div>
<?php ftr();
PHP

cat > /tmp/nb/login.php <<'PHP'
<?php require __DIR__.'/config.php'; $db=db();
if((isset($_SERVER['REQUEST_METHOD'])?$_SERVER['REQUEST_METHOD']:'')==='POST'){
  $u=isset($_POST['username'])?$_POST['username']:''; $p=isset($_POST['password'])?$_POST['password']:'';
  // Dang nhap prepared (khong SQLi o day) - nhung mat khau bam MD5 (yeu)
  $st=$db->prepare('SELECT id,username,password,role FROM users WHERE username=?');
  $st->bind_param('s',$u); $st->execute();
  $r=$st->get_result()->fetch_assoc();
  if($r && is_string($r['password']) && $r['password']===crypt($p,$r['password'])){
    $_SESSION['uid']=$r['id']; $_SESSION['username']=$r['username']; $_SESSION['role']=$r['role'];
    if($r['role']==='admin'){
      // Admin co mot "session token" trong cookie doc duoc boi JS (chinh la XSS flag)
      $x=@trim(@file_get_contents('/var/lib/notebox/xssflag.txt'));
      setcookie('ssession',$x,0,'/');
    }
    header('Location: dashboard.php'); exit;
  }
  hdr('Dang nhap'); echo "<!-- LOGIN_FAIL -->";
  echo "<div class=card><p style=\"color:#c00\">Sai ten dang nhap hoac mat khau.</p><p><a href=index.php>Thu lai</a></p></div>"; ftr(); exit;
}
header('Location: index.php');
PHP

cat > /tmp/nb/dashboard.php <<'PHP'
<?php require __DIR__.'/config.php'; require_login(); $db=db(); $me=uid();
if((isset($_SERVER['REQUEST_METHOD'])?$_SERVER['REQUEST_METHOD']:'')==='POST' && isset($_POST['title'])){
  $t=trim($_POST['title']); $b=isset($_POST['body'])?$_POST['body']:'';
  if($t!==''){ $st=$db->prepare('INSERT INTO notes(owner_id,title,body) VALUES(?,?,?)');
    $st->bind_param('iss',$me,$t,$b); $st->execute(); }
  header('Location: dashboard.php'); exit;
}
hdr('Ghi chu'); nav(); echo "<!-- AUTH_OK uid=".$me." -->";
echo "<h2>Ghi chu cua ".htmlspecialchars(uname())."</h2>";
echo "<form method=get action=search.php><input name=q placeholder=\"Tim ghi chu cua ban\"><button>Tim</button></form>";
$st=$db->prepare('SELECT id,title FROM notes WHERE owner_id=?'); $st->bind_param('i',$me); $st->execute(); $r=$st->get_result();
echo "<ul>"; while($n=$r->fetch_assoc()){ echo "<li><a href=\"note.php?id=".$n['id']."\">".htmlspecialchars($n['title'])."</a></li>"; } echo "</ul>"; ?>
<div class=card><h3>Tao ghi chu moi</h3>
<form method=post action=dashboard.php>
<input name=title placeholder="Tieu de">
<textarea name=body rows=4 placeholder="Noi dung"></textarea>
<button>Luu ghi chu</button></form></div>
<?php ftr();
PHP

cat > /tmp/nb/note.php <<'PHP'
<?php require __DIR__.'/config.php'; require_login(); $db=db(); $me=uid();
$id=intval(isset($_GET['id'])?$_GET['id']:0);
$st=$db->prepare('SELECT owner_id,title,body FROM notes WHERE id=?'); $st->bind_param('i',$id); $st->execute();
$n=$st->get_result()->fetch_assoc();
hdr('Ghi chu'); nav();
if(!$n){ echo "<p>Khong tim thay ghi chu.</p>"; ftr(); exit; }
if($n['owner_id']!=$me){ http_response_code(403); echo "<p>403 - Day khong phai ghi chu cua ban.</p>"; ftr(); exit; }
// LO HONG Stored XSS: in body note KHONG escape (giong admin.php - app quen escape o MOI noi hien body)
echo "<h2>".htmlspecialchars($n['title'])."</h2><div class=card><pre>".$n['body']."</pre></div>";
echo "<p><a href=dashboard.php>Quay lai</a></p>"; ftr();
PHP

cat > /tmp/nb/search.php <<'PHP'
<?php require __DIR__.'/config.php'; require_login(); $db=db(); $me=uid();
$q=isset($_GET['q'])?$_GET['q']:'';
hdr('Tim kiem'); nav();
echo "<h2>Ket qua tim: ".htmlspecialchars($q)."</h2>";
// LO HONG SQLi (UNION): ghep chuoi; + verbose error (lo thong tin)
$sql="SELECT id,title FROM notes WHERE owner_id=".$me." AND title LIKE '%".$q."%'";
$res=$db->query($sql);
if(!$res){ echo "<p>Loi SQL: ".htmlspecialchars($db->error)."</p>"; }
else { echo "<ul>"; while($row=$res->fetch_assoc()){ echo "<li>".htmlspecialchars($row['title'])."</li>"; } echo "</ul>"; }
echo "<p><a href=dashboard.php>Quay lai</a></p>"; ftr();
PHP

cat > /tmp/nb/admin.php <<'PHP'
<?php require __DIR__.'/config.php'; require_login(); $db=db();
// Kiem quyen DUNG CACH (role tu session server)
if(urole()!=='admin'){ http_response_code(403); hdr('Admin'); nav(); echo "<p>403 - Chi danh cho quan tri vien.</p>"; ftr(); exit; }
hdr('Admin'); nav(); echo "<!-- ADMIN_PANEL -->";
$flag=@trim(@file_get_contents('/var/lib/notebox/flag.txt'));
echo "<div class=card><b>Bi mat he thong (System secret):</b> ".htmlspecialchars($flag)."</div>";
echo "<h2>Tat ca ghi chu nguoi dung</h2><ul>";
$res=$db->query("SELECT u.username AS un, n.title AS t, n.body AS b FROM notes n JOIN users u ON u.id=n.owner_id");
if($res){ while($row=$res->fetch_assoc()){
  // LO HONG Stored XSS: in body note KHONG escape (admin xem -> JS chay)
  echo "<li><b>".htmlspecialchars($row['un'])."</b> / ".htmlspecialchars($row['t']).": ".$row['b']."</li>";
} }
echo "</ul>"; ftr();
PHP

cat > /tmp/nb/logout.php <<'PHP'
<?php require __DIR__.'/config.php'; $_SESSION=array(); setcookie('ssession','',time()-3600,'/'); session_destroy(); header('Location: index.php');
PHP

S mkdir -p /var/www/html
S cp /tmp/nb/config.php /tmp/nb/index.php /tmp/nb/register.php /tmp/nb/login.php /tmp/nb/dashboard.php /tmp/nb/note.php /tmp/nb/search.php /tmp/nb/admin.php /tmp/nb/logout.php /var/www/html/
S rm -f /var/www/html/index.html 2>/dev/null

# Bi mat he A = SENTINEL (khong phai flag that)
S mkdir -p /var/lib/notebox
S bash -c 'echo "ADMIN_SECRET_A_SENTINEL" > /var/lib/notebox/flag.txt; echo "XSS_SENTINEL_A" > /var/lib/notebox/xssflag.txt; chmod 644 /var/lib/notebox/*.txt; chown -R www-data:www-data /var/lib/notebox'

# MariaDB: seed idempotent; CHO root ket noi duoc roi moi seed MOT LAN (chiu timing service len cham)
cat > /tmp/seed.sql <<'SQL'
CREATE DATABASE IF NOT EXISTS notebox;
GRANT ALL PRIVILEGES ON notebox.* TO 'nbuser'@'localhost' IDENTIFIED BY 'nbpass';
GRANT ALL PRIVILEGES ON notebox.* TO 'nbuser'@'127.0.0.1' IDENTIFIED BY 'nbpass';
FLUSH PRIVILEGES;
USE notebox;
DROP TABLE IF EXISTS notes; DROP TABLE IF EXISTS users;
CREATE TABLE users(id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(64), password VARCHAR(64), role VARCHAR(16));
CREATE TABLE notes(id INT AUTO_INCREMENT PRIMARY KEY, owner_id INT, title VARCHAR(128), body TEXT);
INSERT INTO users(username,password,role) VALUES('admin','$1$aUDLM4c3$Mb/CvTYkXvIi3YpuhRrgp/','admin');
INSERT INTO users(username,password,role) VALUES('checker','$1$e6ZA7djS$GcaVd5EVaLVjfS.56g2YX0','user');
INSERT INTO users(username,password,role) VALUES('checkeradmin','$1$1jCy5VQ$zRC/9ZnF4sR/.9p8QRyLk.','admin');
INSERT INTO notes(owner_id,title,body) VALUES(2,'my-note','CHECKER_NOTE_OK <xsstest>XSSPROBE</xsstest>');
SQL
S systemctl enable mariadb 2>/dev/null || true
S systemctl start mariadb 2>/dev/null || S service mariadb start 2>/dev/null || S service mysql start 2>/dev/null || true
for i in $(seq 1 60); do S mysql -e 'SELECT 1' >/dev/null 2>&1 && break; sleep 3; done
S bash -c 'mysql < /tmp/seed.sql'

# Apache + rsyslog
S systemctl enable apache2 2>/dev/null || true
S systemctl restart apache2 2>/dev/null || S service apache2 restart 2>/dev/null || true
S service rsyslog start 2>/dev/null || S systemctl start rsyslog 2>/dev/null || true

# Wazuh agent giam sat access.log
LF='<localfile><log_format>apache</log_format><location>/var/log/apache2/access.log</location></localfile>'
S sed -i "s#</ossec_config>#${LF}</ossec_config>#" /var/ossec/etc/ossec.conf 2>/dev/null
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# analyst de va (so huu webroot -> sua code PHP khong can sudo)
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S chown -R analyst:analyst /var/www/html
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA (Blue) - dien gia tri ban TU TIM DUOC qua SIEM/log (KEY=value):
# ATTACKER_IP : IP ke tan cong
# VULN1       : lo hong 1 (vd: UNION SQL injection tren /search.php)
# VULN2       : lo hong 2 (vd: Stored XSS - /admin.php in noi dung note khong escape)
ATTACKER_IP=
VULN1=
VULN2=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt

exit 0
