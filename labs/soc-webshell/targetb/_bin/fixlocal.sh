#!/bin/bash
# targetb (he B - PhotoBox "production"), quyen 'ubuntu'. $1 = mat khau sudo.
# Giong he A (cung ma nguon, cung lo hong) nhung CHUA VA + co FLAG that + /submit.php.
# Chi HTTP (khong SSH). SV upload webshell .phtml -> RCE -> doc flag -> nop /submit.php.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }
mkdir -p /tmp/pb

cat > /tmp/pb/index.php <<'PHP'
<?php
$dir=__DIR__.'/uploads';
function h($t){ echo "<!doctype html><html><head><meta charset=utf-8><title>".$t." - PhotoBox</title><style>body{font-family:system-ui,Arial,sans-serif;max-width:720px;margin:24px auto;padding:0 16px;color:#222}h1,h2{color:#2a4d7a}a{color:#1a7f5a;text-decoration:none}button{background:#2a4d7a;color:#fff;padding:8px 16px;border:0;border-radius:4px;cursor:pointer}.card{border:1px solid #e0e0e0;border-radius:8px;padding:14px;margin:10px 0}</style></head><body>"; }
h('Trang chu');
echo "<h1>PhotoBox (production)</h1><p>Dich vu tai len va chia se anh dai dien.</p>";
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
  $parts=explode('.',$name); $ext=strtolower(end($parts));
  if($ext==='php'){ http_response_code(403); echo "TU CHOI: khong cho tai file .php (BLOCK_PHP)"; exit; }
  $dest=$dir.'/'.$name;
  if(@move_uploaded_file($_FILES['avatar']['tmp_name'],$dest)){
    echo "DA TAI LEN: <a href=\"uploads/".htmlspecialchars($name)."\">uploads/".htmlspecialchars($name)."</a> (UPLOAD_OK)";
  } else { http_response_code(500); echo "LOI khi luu file."; }
  exit;
}
header('Location: index.php');
PHP

cat > /tmp/pb/submit.php <<'PHP'
<?php
// "Gameserver": SV nop FLAG (doc duoc qua webshell RCE) -> B tu so voi bi mat cua chinh no.
$flag=@trim(@file_get_contents('/var/lib/photobox/flag.txt'));
$f=trim(isset($_REQUEST['flag'])?$_REQUEST['flag']:'');
echo "<!doctype html><meta charset=utf-8><body style='font-family:system-ui,Arial;max-width:640px;margin:24px auto'>";
if($f!=='' && $f===$flag){ @file_put_contents('/tmp/.flagok','1'); @chmod('/tmp/.flagok',0644); echo "<p>FLAG: <b>DUNG</b>.</p>"; }
elseif($f!==''){ echo "<p>FLAG: sai.</p>"; }
else { echo "<p>Gui ?flag=FLAG-xxxxxx</p>"; }
echo "<p><a href=index.php>Trang chu</a></p></body>";
PHP

# --- Trien khai webroot ---
S mkdir -p /var/www/html/uploads
S cp /tmp/pb/index.php /tmp/pb/upload.php /tmp/pb/submit.php /var/www/html/
S rm -f /var/www/html/index.html 2>/dev/null
# uploads www-data ghi duoc (apache luu file upload)
S chown -R www-data:www-data /var/www/html/uploads
S chmod 755 /var/www/html/uploads

# FLAG that (ca nhan hoa), luu NGOAI webroot -> phai RCE moi doc duoc (khong GET truc tiep)
S mkdir -p /var/lib/photobox
S bash -c 'echo "FLAG-FLAGVAL" > /var/lib/photobox/flag.txt; chmod 644 /var/lib/photobox/flag.txt; chown www-data:www-data /var/lib/photobox/flag.txt'

# Apache
S systemctl enable apache2 2>/dev/null || true
S systemctl restart apache2 2>/dev/null || S service apache2 restart 2>/dev/null || true

exit 0
