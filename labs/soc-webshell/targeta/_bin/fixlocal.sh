#!/bin/bash
# targeta (he A - PhotoBox upload), quyen 'ubuntu'. $1 = mat khau sudo.
# App THAT: upload "anh dai dien". LO HONG: blocklist ngay tho (chi chan duoi 'php',
# quen .phtml/.phar/.pht) + uploads/ thuc thi PHP -> upload .phtml = webshell = RCE.
# He A KHONG chua flag that (chi sentinel). Flag that o he B.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }
mkdir -p /tmp/pb

cat > /tmp/pb/index.php <<'PHP'
<?php
$dir=__DIR__.'/uploads';
function h($t){ echo "<!doctype html><html><head><meta charset=utf-8><title>".$t." - PhotoBox</title><style>body{font-family:system-ui,Arial,sans-serif;max-width:720px;margin:24px auto;padding:0 16px;color:#222}h1,h2{color:#2a4d7a}a{color:#1a7f5a;text-decoration:none}button{background:#2a4d7a;color:#fff;padding:8px 16px;border:0;border-radius:4px;cursor:pointer}.card{border:1px solid #e0e0e0;border-radius:8px;padding:14px;margin:10px 0}</style></head><body>"; }
h('Trang chu');
echo "<h1>PhotoBox</h1><p>Dich vu tai len va chia se anh dai dien.</p>";
echo "<div class=card><h2>Tai anh len</h2><form method=post action=upload.php enctype=\"multipart/form-data\"><input type=file name=avatar><br><br><button>Tai len</button></form></div>";
echo "<div class=card><h2>Anh da tai</h2><ul>";
foreach(glob($dir.'/*') as $f){ $b=basename($f); echo "<li><a href=\"uploads/".rawurlencode($b)."\">".htmlspecialchars($b)."</a></li>"; }
echo "</ul></div></body></html>";
PHP

cat > /tmp/pb/upload.php <<'PHP'
<?php
$dir=__DIR__.'/uploads';
if(!is_dir($dir)){ @mkdir($dir,0775,true); }
if((isset($_SERVER['REQUEST_METHOD'])?$_SERVER['REQUEST_METHOD']:'')==='POST'
   && isset($_FILES['avatar']) && $_FILES['avatar']['error']===0){
  $name=basename($_FILES['avatar']['name']);
  // ===== LO HONG: blocklist NGAY THO - chi chan dung duoi 'php' =====
  // (quen .phtml/.phar/.pht; cung khong kiem MIME/noi dung anh)
  $parts=explode('.',$name);
  $ext=strtolower(end($parts));
  if($ext==='php'){
    http_response_code(403);
    echo "TU CHOI: khong cho tai file .php (BLOCK_PHP)";
    exit;
  }
  $dest=$dir.'/'.$name;
  if(@move_uploaded_file($_FILES['avatar']['tmp_name'],$dest)){
    echo "DA TAI LEN: <a href=\"uploads/".htmlspecialchars($name)."\">uploads/".htmlspecialchars($name)."</a> (UPLOAD_OK)";
  } else { http_response_code(500); echo "LOI khi luu file."; }
  exit;
}
header('Location: index.php');
PHP

# --- Trien khai webroot ---
S mkdir -p /var/www/html/uploads
S cp /tmp/pb/index.php /tmp/pb/upload.php /var/www/html/
S rm -f /var/www/html/index.html 2>/dev/null

# Sentinel he A (khong phai flag that)
S mkdir -p /var/lib/photobox
S bash -c 'echo "A_SENTINEL_NOT_A_FLAG" > /var/lib/photobox/secret.txt; chmod 644 /var/lib/photobox/secret.txt'

# Apache: cho .htaccess co hieu luc (de SV co the va bang .htaccess) - AllowOverride All
S bash -c 'cat > /etc/apache2/conf-available/photobox.conf <<CONF
<Directory /var/www/html>
    AllowOverride All
    Options -Indexes +FollowSymLinks
</Directory>
CONF'
S a2enconf photobox 2>/dev/null || true

# analyst so huu CODE PHP (sua upload.php khong can sudo); uploads: analyst so huu THU MUC,
# www-data (group) ghi duoc -> apache upload duoc, analyst xoa duoc webshell.
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S chown -R analyst:analyst /var/www/html
S chown analyst:www-data /var/www/html/uploads
S chmod 775 /var/www/html/uploads

# Cho prestop (chay quyen ubuntu) don file test cua chinh no
S bash -c 'echo "ubuntu ALL=(ALL) NOPASSWD: /bin/rm, /usr/bin/rm" > /etc/sudoers.d/labtainer-webshell; chmod 440 /etc/sudoers.d/labtainer-webshell'

# Apache + rsyslog
S systemctl enable apache2 2>/dev/null || true
S systemctl restart apache2 2>/dev/null || S service apache2 restart 2>/dev/null || true
S service rsyslog start 2>/dev/null || S systemctl start rsyslog 2>/dev/null || true

# Wazuh agent: FIM realtime uploads/ + doc access.log apache
S bash -c "sed -i 's#</ossec_config>#<syscheck><directories realtime=\"yes\" check_all=\"yes\" report_changes=\"yes\">/var/www/html/uploads</directories></syscheck><localfile><log_format>apache</log_format><location>/var/log/apache2/access.log</location></localfile></ossec_config>#' /var/ossec/etc/ossec.conf" 2>/dev/null
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# Bao cao dieu tra (Blue)
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA (Blue) - dien gia tri ban TU TIM DUOC qua SIEM/log (KEY=value):
# ATTACKER_IP : IP ke tan cong
# VULN        : lo hong (vd: Unrestricted file upload -> web shell RCE qua .phtml)
# WEBSHELL    : ten (hoac duoi) file webshell tim thay trong uploads/
ATTACKER_IP=
VULN=
WEBSHELL=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt

exit 0
