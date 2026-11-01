#!/bin/bash
# ============================================================================
# soc-secrets-leak (IR: lo bi mat qua .git/file backup -> chiem credential -> xoay khoa)
# Chay tren VM:  bash install-soc-secrets-leak.sh ; roi rebuild soc-secrets-leak
# LUU Y: script nay XOA VA TAO LAI toan bo $LABTAINER_DIR/labs/soc-secrets-leak tu dau
# (don luon moi file .bak/.pre-service.bak con sot lai tu cac lan chay thu truoc).
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-secrets-leak
echo ">> Tao thu muc lab tai $LAB"; rm -rf "$LAB"; mkdir -p "$LAB"

# ---------------------------------------------------------------------------
# attacker
# ---------------------------------------------------------------------------
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_SL_7qk2__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap tan cong ngam.
setsid python3 /home/ubuntu/attack.py >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
__EOF_SL_7qk2__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/attack.py" <<'__EOF_SL_7qk2__'
#!/usr/bin/env python3
# soc-secrets-leak - attacker (an): quet lo .git/backup, chiem credential, dang nhap, xuat du lieu.
# Chay lien tuc tu 172.20.0.5 de SIEM/log ghi nhan cho sinh vien dieu tra.
import urllib.request, urllib.parse, http.cookiejar, random, time, sys

B = "http://target"

UAS = [
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
    "curl/8.5.0",
    "python-requests/2.31.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/128.0",
]

def log(msg):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), msg)
    sys.stdout.flush()

def session():
    cj = http.cookiejar.CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def get(op, path):
    req = urllib.request.Request(B + path, headers={"User-Agent": random.choice(UAS)})
    try:
        with op.open(req, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:
        return None, str(e)

def post(op, path, data):
    d = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(B + path, d, headers={"User-Agent": random.choice(UAS)})
    try:
        with op.open(req, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:
        return None, str(e)

# ===== 0) Cho app san sang =====
op = session()
for _ in range(120):
    c, _b = get(op, "/")
    if c:
        break
    time.sleep(2)
log("MARKER attacker: app da san sang, bat dau chuoi tan cong")

# ===== 1) Nhieu: quet nhieu duong dan ngau nhien, hau het 404 =====
NOISE_PATHS = [
    "/admin-old", "/backup", "/uploads/shell.php", "/wp-login.php", "/phpmyadmin",
    "/.aws/credentials", "/server-status", "/.htaccess", "/vendor/", "/composer.json",
    "/console", "/debug", "/test.php", "/old/index.php", "/db.sql",
]

def noise_burst(n):
    for _ in range(n):
        p = random.choice(NOISE_PATHS) + str(random.randint(1, 999))
        get(op, p)
        time.sleep(random.uniform(0.3, 1.2))

log("MARKER attacker: bat dau quet nhieu (noise)")
noise_burst(65)

# ===== 2) Crawler thu hai: chi tham do .git/HEAD, KHONG tai gi them =====
# (de SV phan biet: mot IP chi do, mot IP thuc su lay du lieu)
for _ in range(3):
    get(op, "/.git/HEAD")
    time.sleep(random.uniform(1, 3))

# ===== 3) Moc LEAK: tai that cac artifact bi lo, retry den khi thanh cong =====
LEAK_PATHS = ["/.git/HEAD", "/.git/config", "/.git/logs/HEAD", "/config.php.bak-BAKNUM"]

def confirm_leak():
    ok = True
    for p in LEAK_PATHS:
        c, _b = get(op, p)
        if c != 200:
            ok = False
        time.sleep(random.uniform(0.5, 1.5))
    return ok

for attempt in range(30):
    if confirm_leak():
        log("MARKER attacker: TIME_LEAK - da tai duoc artifact bi lo")
        break
    time.sleep(5)
else:
    log("MARKER attacker: CANH BAO khong tai duoc artifact lo sau nhieu lan thu")

# Luu y: file .env.old (SMTP_PASS) KHONG bao gio bi dung toi - de danh cho scoping.

# ===== 4) Nghi 120 giay roi dang nhap bang credential lo (TIME_LOGIN) =====
time.sleep(120)

def try_login():
    c, _b = post(op, "/login.php", {"username": "admin", "password": "Adm-ADMNUM"})
    # urllib tu dong theo redirect 302 -> trang dashboard tra ve 200 khi dang nhap dung;
    # login.php tra 401 (khong redirect) khi sai, nen 200 la dau hieu dung cua thanh cong.
    return c == 200

for attempt in range(30):
    if try_login():
        log("MARKER attacker: TIME_LOGIN - dang nhap admin thanh cong")
        break
    time.sleep(5)
else:
    log("MARKER attacker: CANH BAO dang nhap that bai sau nhieu lan thu")

# ===== 5) Nghi 120 giay roi xuat du lieu (TIME_EXPORT) =====
time.sleep(120)

def try_export():
    c, _b = get(op, "/export.php")
    return c == 200

for attempt in range(30):
    if try_export():
        log("MARKER attacker: TIME_EXPORT - da xuat du lieu khach hang")
        break
    time.sleep(5)
else:
    log("MARKER attacker: CANH BAO xuat du lieu that bai sau nhieu lan thu")

# ===== 6) Vong lap vinh vien: dang nhap lai dinh ky + probe nhay cam/lanh tinh =====
# Sau khi SV xoay khoa, cac lan dang nhap lai nay phai that bai (LOGIN_FAIL trong auth.log).
log("MARKER attacker: chuyen sang vong lap dinh ky (kiem tra ton tai)")
while True:
    try_login()
    get(op, "/config.php.bak-BAKNUM")       # probe nhay cam
    get(op, "/favicon.ico")                  # probe lanh tinh (marker: luon 200 hoac 404 on dinh)
    noise_burst(5)
    time.sleep(random.uniform(60, 90))
__EOF_SL_7qk2__

# ---------------------------------------------------------------------------
# config
# ---------------------------------------------------------------------------
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_SL_7qk2__'
SOC Lab - Lo bi mat qua .git va file backup -> chiem credential -> xoay khoa.
Lich su Git va mot file backup con sot lai lam lo mat khau DB, mat khau admin va API
key cua mot web app noi bo. Ke tan cong tai duoc artifact lo, dang nhap trai phep va
xuat du lieu khach hang. Nhiem vu: dieu tra (phan biet lo voi bi lay thuc su), dung
lai timeline, cach ly, dong duong lo, XOAY KHOA toan bo bi mat da lo (khong chi xoa
file la xong), va tu viet mot luat Wazuh de phat hien lan sau.
__EOF_SL_7qk2__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_SL_7qk2__'
ADMNUM  : RAND_REPLACE : target:setup_app.sh;attacker:attack.py : ADMNUM  : 1000 : 9999
DBNUM   : RAND_REPLACE : target:setup_app.sh                    : DBNUM   : 1000 : 9999
OPSNUM  : RAND_REPLACE : target:setup_app.sh                    : OPSNUM  : 1000 : 9999
APINUM  : RAND_REPLACE : target:setup_app.sh                    : APINUM  : 1000 : 9999
SMTPNUM : RAND_REPLACE : target:setup_app.sh                    : SMTPNUM : 1000 : 9999
BAKNUM  : RAND_REPLACE : target:setup_app.sh;attacker:attack.py : BAKNUM  : 1000 : 9999
__EOF_SL_7qk2__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_SL_7qk2__'
# start.config - Lab soc-secrets-leak (lo bi mat qua .git/backup -> chiem credential -> xoay khoa)
# target chay Apache/PHP + MariaDB, co Wazuh agent. attacker (an) tai artifact lo, dang nhap, xuat du lieu.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-secrets-leak_student_master_seed
	GRADE_CONTAINER target

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May muc tieu: web app lo bi mat, noi hoc vien dieu tra + xu ly ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong: an, tu dong tai artifact lo + dang nhap + xuat du lieu ---
CONTAINER attacker
	USER ubuntu
	SOC_NET 172.20.0.5
	ADD-HOST target:172.20.0.10
	TERMINALS 0

# --- SIEM: Wazuh (dung chung anh nen soc-wazuh) ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	TERMINALS 1

# --- DEFENDER: tram analyst, Firefox xem dashboard + SSH dieu tra ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	X11 YES
	TERMINALS 1
__EOF_SL_7qk2__

# ---------------------------------------------------------------------------
# defender
# ---------------------------------------------------------------------------
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_SL_7qk2__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_SL_7qk2__

# ---------------------------------------------------------------------------
# dockerfiles
# ---------------------------------------------------------------------------
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-secrets-leak.attacker.student" <<'__EOF_SL_7qk2__'
#
# Labtainer Dockerfile - attacker (tai artifact lo, dang nhap, xuat du lieu, an)
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
# attack.py chi dung Python stdlib (urllib, http.cookiejar) - chi can python3
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
__EOF_SL_7qk2__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-secrets-leak.defender.student" <<'__EOF_SL_7qk2__'
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
# Firefox co san trong base firefox3; them ssh client de SSH sang target dieu tra/xu ly
RUN apt-get update || true; apt-get install -y --no-install-recommends openssh-client \
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
__EOF_SL_7qk2__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-secrets-leak.siem.student" <<'__EOF_SL_7qk2__'
#
# Labtainer Dockerfile - siem. Dung chung anh nen soc-wazuh (Wazuh cai san, tiet kiem dung luong).
# Entrypoint: (1) khoi phuc quyen cac user Wazuh bi reset ve root khi layer image chung,
# (2) don trang thai agent cu (rids/client.keys) de agent enroll lai sach,
# (3) GHI LAI DUNG .labname (anh nen mang san .labname cua lab goc dung de bake -> neu khong
#     ghi de o DAY (truoc exec init), zip artifact cua siem se bi dat sai ten lab khi nop bai
#     -> grader bao "Error occurred within the grader container" khi checkwork).
# lab-rules.service: systemd tu chay lab_rules.sh (cai decoder + rule nen) moi lan boot.
#
ARG registry
# Anh nen dung chung cua nhom (push qua docker commit vao registry local, KHONG qua co che
# $registry/labtainer.* cua Labtainer goc) - dung dung ten co dinh nhu apply-shared-siem.sh.
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
# Cho prestop doc alerts khong can mat khau (de cham diem detection_rule). Sudoers chi cho
# phep dung "cat" voi DUONG DAN DAY DU (khong cho tail/head/wildcard).
RUN echo 'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /var/ossec/logs/alerts/alerts.log, /usr/bin/cat /var/ossec/logs/alerts/alerts.log' > /etc/sudoers.d/labtainer-wazuh \
    && chmod 440 /etc/sudoers.d/labtainer-wazuh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# === Entrypoint: khoi phuc quyen Wazuh + don agent cu + GHI LAI .labname TRUOC khi init chay ===
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
  '# Anh nen soc-wazuh mang san .labname cua lab goc dung de bake -> GHI LAI dung ten lab nay' \
  '# o DAY (chay o MOI lan boot, truoc init), vi RUN tren Dockerfile chi chay 1 lan luc build' \
  '# va khong du de ghi de gia tri da bake trong anh nen chung.' \
  'mkdir -p /home/ubuntu/.local' \
  'echo soc-secrets-leak > /home/ubuntu/.local/.labname' \
  'chown ubuntu:ubuntu /home/ubuntu/.local/.labname' \
  'exec /sbin/init --log-target=journal 3>&1' \
  > /entrypoint.sh && chmod +x /entrypoint.sh
#
# --- lab-rules.service: moi lan siem boot, systemd tu chay lab_rules.sh (khong phu thuoc
#     fixlocal/sudo/thu muc /tmp - on dinh hon goi tu fixlocal) ---
RUN printf '%s\n' \
  '[Unit]' \
  'Description=SOC lab: decoder + rule nen cho Wazuh' \
  'After=wazuh-manager.service' \
  'Wants=wazuh-manager.service' \
  '[Service]' \
  'Type=oneshot' \
  'RemainAfterExit=yes' \
  'TimeoutStartSec=600' \
  'ExecStart=/bin/bash /home/ubuntu/lab_rules.sh' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > /etc/systemd/system/lab-rules.service \
  && systemctl enable lab-rules.service
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
CMD ["/entrypoint.sh"]
__EOF_SL_7qk2__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-secrets-leak.target.student" <<'__EOF_SL_7qk2__'
#
# Labtainer Dockerfile - target (Apache/PHP + MariaDB lo bi mat qua .git/backup, Wazuh agent)
#
ARG registry
# Base co openssh-server (sshd) + rsyslog -> analyst SSH tu defender vao duoc
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
# Cho prestop doc /root/.soc_truth + iptables -S khong can mat khau (de cham diem).
# CHI cho %sudo (tai khoan 'ubuntu' cua prestop) - KHONG cho analyst (analyst khong o nhom sudo).
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/grep, /bin/grep, /sbin/iptables, /usr/sbin/iptables' > /etc/sudoers.d/labtainer-sl \
    && chmod 440 /etc/sudoers.d/labtainer-sl
#
# Web stack: apache + php + MariaDB (nhu soc-patch-pwn) + git (lich su git lo bi mat) + iptables (containment)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php php-mysql mariadb-server git iptables curl \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 php7.0-mysql mariadb-server git iptables curl \
    ) ; rm -rf /var/lib/apt/lists/*
#
# --- Wazuh agent (bake, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg && rm -rf /var/lib/apt/lists/*
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent && rm -rf /var/lib/apt/lists/*
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
__EOF_SL_7qk2__

# ---------------------------------------------------------------------------
# docs
# ---------------------------------------------------------------------------
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_SL_RF__'
================================================================================
 SOC LAB: LO BI MAT QUA .GIT VA FILE BACKUP -> CHIEM CREDENTIAL -> XOAY KHOA
================================================================================

1. TONG QUAN (OVERVIEW)
--------------------------------------------------------------------------------
May chu 'target' chay mot web app noi bo (Apache + PHP + MariaDB). Trong qua trinh
phat trien, lap trinh vien da vo tinh de lo bi mat qua HAI con duong khac nhau: lich
su Git cua webroot (mot commit cu con chua file cau hinh nhay cam truoc khi bi xoa)
va mot file backup cau hinh con sot lai tren webroot. Mot ke tan cong da quet thay,
tai cac artifact nay, chiem duoc credential, dang nhap trai phep vao trang quan tri,
va xuat du lieu khach hang. He thong giam sat Wazuh co ghi nhan toan bo qua trinh
nay trong log - nhung CHUA co luat nao bao dong.

Ban la nhan vien SOC: dieu tra de hieu dung CHUYEN GI DA XAY RA, CACH LY ke tan cong,
DONG lai duong lo, XOAY KHOA toan bo bi mat da lo (khong chi xoa file la xong), va
TU VIET mot luat phat hien de lan sau he thong tu bao dong.

LUU Y QUAN TRONG: cac gia tri bi mat (mat khau DB, mat khau admin, API key, ten file
backup) deu duoc CA NHAN HOA rieng cho may cua ban. Ban PHAI tu doc ra tren he thong
CUA MINH - khong the chep dap an cua ban khac.

2. MUC TIEU HOC TAP (OBJECTIVES)
--------------------------------------------------------------------------------
  - Doc log web/app de khoanh vung: phan biet quet (noise/404) voi lay du lieu thuc
    su (200 vao dung artifact nhay cam).
  - Phan biet "bi lo" (co the truy cap duoc) voi "bi lay thuc su" (co bang chung da
    bi tai) - hai khai niem khac nhau trong dieu tra su co.
  - Hieu vi sao bi mat nam trong LICH SU GIT van con nguy hiem du cay lam viec hien
    tai da "sach".
  - Dung lai TIMELINE cua chuoi tan cong tu nhieu nguon log khac nhau.
  - Thuc hanh vong doi IR: CONTAINMENT -> ERADICATION -> XOAY KHOA (rotation) -> kiem
    chung dich vu khong bi sap (SLA).
  - Tu viet mot luat phat hien Wazuh (custom rule) va kiem thu bang wazuh-logtest.

3. KIEN THUC NEN (BACKGROUND)
--------------------------------------------------------------------------------
* Bi mat trong lich su Git: xoa file khoi cay lam viec hien tai (vd `git rm`) KHONG
  xoa no khoi lich su commit cu. Ai co the doc lai lich su (`git log`, `git show
  <commit>:<file>`) van lay duoc gia tri that da tung ton tai trong file do. Day la
  ly do vi sao MITRE xep rieng T1213.003 (Data from Information Repositories: Code
  Repositories) ben canh T1552.001 (Unsecured Credentials: Credentials in Files).
* "Lo" khac "bi lay": mot file co the truy cap duoc tu ben ngoai (HTTP tra 200) nhung
  khong co nghia la ke tan cong DA THUC SU tai no. Dieu tra vien phai doi chieu VOI
  LOG truy cap de biet chinh xac ke tan cong da cham toi file nao, bo qua file nao.
* Xoay khoa (secret rotation): khi mot bi mat da bi lo ra ngoai (ke tan cong da co
  gia tri THAT cua no), chi dong duong truy cap (xoa file, vo hieu URL) la KHONG DU -
  gia tri cu van dung duoc o noi khac (dang nhap DB, dang nhap app, goi API) cho den
  khi bi mat do duoc DOI (rotate). Mot he thong co nhieu bi mat lien ket (vd mat khau
  DB dung o ca server DB va file cau hinh app) phai doi DONG BO, neu khong dich vu se
  sap (mismatch).
* Wazuh custom rule: them luat vao /var/ossec/etc/rules/local_rules.xml tren SIEM (id
  phai >= 100000, vi id duoi 100000 danh cho rule mac dinh/rule nen cua lab). Luat co
  the KE THUA (<if_sid>) tu mot rule mac dinh da khop truoc, thay vi tu dung doc lap -
  trong Wazuh, mot rule doc lap thuong THUA uu tien truoc rule mac dinh da khop cung
  dong log. Kiem thu truoc khi dung luat bang `wazuh-logtest`; nap lai bang
  `systemctl restart wazuh-manager`.
* Vong doi IR (NIST): Detection -> CONTAINMENT (chan nguon tan cong) -> ERADICATION
  (dong duong lo + xoa artifact) -> Recovery (xoay khoa, xac nhan dich vu song) ->
  Lessons. Thu tu nay quan trong: cach ly truoc de "cam mau" roi moi don dep.
* Cac ky thuat MITRE ATT&CK lien quan (nen tra lai ma truoc khi dua vao bao cao):
  T1595.003 (quet/do thu danh sach duong dan), T1213.003 (du lieu tu kho ma nguon),
  T1552.001 (credential trong file), T1078 (dung tai khoan hop le da chiem duoc),
  T1005 (lay du lieu tu he thong noi bo).

4. MOI TRUONG & SO DO (TOPOLOGY)
--------------------------------------------------------------------------------
  attacker (172.20.0.5, AN)  -- ke tan cong: quet, tai artifact lo, dang nhap, xuat du lieu
  target   (172.20.0.10)     -- may chay web app + MariaDB; co Wazuh agent; GRADE_CONTAINER
  siem     (172.20.0.20)     -- Wazuh (dashboard https://172.20.0.20); noi ban VIET LUAT
  defender (172.20.0.30)     -- tram cua ban: Firefox + SSH de dieu tra/ung pho
  Dieu tra & ung pho tren target:  ssh analyst@target   (mat khau: analyst)
  *** Lan dau cho siem cai Wazuh (~8-10'):  tail -f /var/log/wazuh-install.log
      Ke tan cong ra tay thanh 3 moc cach nhau ~2 phut (lay artifact lo -> dang nhap ->
      xuat du lieu), co retry de moi lan checkwork deu phan anh dung trang thai. Hay cho
      khoang 5-8 phut tu luc start lab de ca chuoi su kien kip xay ra truoc khi dieu tra. ***

5. NHIEM VU (TASKS)
--------------------------------------------------------------------------------
--- Task 1: Khoanh vung - tim ai da lam gi ---
  Muc tieu: xac dinh DIA CHI IP thuc su da tai duoc artifact bi lo, phan biet voi
  cac luot quet/do thu khac.
  Boi canh/Quan sat: webroot bi quet rat nhieu (phan lon la 404 - "do thu", khong lay
  duoc gi). Chi mot so IT request thanh cong (HTTP 200) thuc su cham toi duong dan
  nhay cam. Co ca mot "crawler" khac chi goi thu MOT duong dan roi dung, khong tai gi
  them - day KHONG phai ke lay du lieu thuc su.
  Yeu cau: xac dinh dung mot dia chi IP la ke THUC SU da tai du cac artifact nhay cam
  (khong phai crawler do tham).
  Goi y cong cu: dashboard Wazuh (Threat Hunting / Security events) de loc theo
  IP/status; hoac loc truc tiep log web tren target theo ma trang thai HTTP.
  Tu kiem chung: ban giai thich duoc VI SAO loai duoc cac IP/luot quet khac, chi giu
  lai dung mot IP.

--- Task 2: Scoping - phan biet "lay thuc su" voi "lo nhung chua bi dung" ---
  Muc tieu: voi TUNG artifact bi lo tren webroot, xac dinh no thuoc nhom nao:
  CONFIRMED_LEAKED (da bi ke tan cong lay thuc su) hay EXPOSED_UNTOUCHED (co the truy
  cap duoc tu ben ngoai nhung khong co bang chung bi lay).
  Boi canh/Quan sat: webroot de lo nhieu hon mot artifact. Doi chieu NOI DUNG tung
  file (bi mat gi ben trong) VOI log truy cap (IP ke tan cong co thuc su cham toi do
  khong). Dung quen kiem tra CA lich su Git, khong chi cac file tinh tren webroot -
  bi mat co the nam trong mot COMMIT CU da bi xoa khoi cay lam viec hien tai.
  Yeu cau: phan loai dung, day du cac artifact bi lo vao hai nhom noi tren (kem ten
  loai bi mat trong tung artifact, vd: lich su Git, file backup cau hinh, file mol
  khac).
  Goi y cong cu: doc truc tiep noi dung tung file qua HTTP; voi Git, dung lenh xem
  lich su commit va noi dung file o mot commit cu.
  Tu kiem chung: ghi ro ket luan khoanh vung (CONFIRMED_LEAKED vs EXPOSED_UNTOUCHED)
  truoc khi qua Task 3 - ban se can lai dung nay o Task 7.

--- Task 3: Dung lai TIMELINE ---
  Muc tieu: xac dinh 3 moc thoi gian (HH:MM) theo DUNG THU TU: luc artifact bi lo lan
  dau bi tai thanh cong, luc ke tan cong dang nhap thanh cong vao trang quan tri, luc
  du lieu khach hang bi xuat ra.
  Boi canh/Quan sat: ba su kien nay xay ra cach nhau vai phut, moi su kien nam o MOT
  nguon log khac nhau (log truy cap web cho su kien dau, log ung dung cho hai su kien
  sau). Chi tinh dong log cua DUNG dia chi IP ke tan cong da xac dinh o Task 1 - bo
  qua cac dong cua IP khac/crawler khac.
  Yeu cau: ba moc gio dung (sai lech khong qua 1 phut) va dung thu tu.
  Goi y cong cu: loc log theo IP, tim dong dau tien khop dieu kien tuong ung voi moi
  su kien; doi chieu voi dashboard Wazuh (Threat Hunting, loc theo thoi gian) de xac
  nhan lai.
  Tu kiem chung: ba moc gio ban ghi phai THEO DUNG THU TU tang dan.

--- Task 4: Cau hoi khai niem (bat buoc tu luan, khong co lenh dap an) ---
  Cau hoi: Vi sao CHI xoa cac file/artifact bi lo khoi webroot la CHUA DU de vo hieu
  hoa thiet hai da xay ra?
  Goi y suy luan: nhin lai dieu ban vua ket luan o Task 2 ve noi bi mat nam trong lich
  su Git - xoa file co xoa duoc "lich su" khong? Ke tan cong da lay duoc GIA TRI THAT
  cua bi mat do roi - xoa duong truy cap co lam gia tri do het hieu luc khong?
  Yeu cau: viet cau tra loi vao bao cao cua ban (khong co lenh cu the cho task nay) -
  phai neu ro CO CHE (lich su git / gia tri da bi lo ra ngoai), khong chi noi "vi
  khong an toan".

--- Task 5: Containment, Eradication, va Xoay khoa (khong de lech dong bo) ---
  Muc tieu A (Containment): chan ke tan cong truy cap tiep tuc, truoc khi don dep.
  Goi y cong cu: tuong lua tren target (iptables), luat chan theo DUNG dia chi IP ke
  tan cong da xac dinh o Task 1 - khong chan bua anh huong dich vu khac.

  Muc tieu B (Eradication): dong het cac duong lo da xac dinh o Task 2 (ca duong lo
  CONFIRMED_LEAKED va EXPOSED_UNTOUCHED - loai sach, khong chi loai phan da bi lay).
  Goi y cong cu: xoa thu muc/file tuong ung tren webroot. Kiem chung lai bang cach tu
  goi HTTP vao dung cac duong dan do - phai KHONG con tra ve 200, nhung trang chu cua
  app van phai con song (200).

  Muc tieu C (Xoay khoa - QUAN TRONG NHAT, de sai nhat): DOI toan bo cac bi mat da bi
  lo (khong chi mat khau quan tri app, con ca mat khau ket noi CSDL va API key). Vi
  mot so bi mat lien ket voi NHIEU noi (vd mat khau CSDL nam o ca may chu CSDL va o
  file cau hinh app), ban PHAI doi DONG BO ca hai noi - lech nhau se lam dich vu bao
  loi (sap SLA).
  Goi y cong cu: tai khoan `analyst` duoc cap san mot so cong cu/quyen han che vua du
  de thuc hien viec xoay khoa nay ma khong can biet mat khau goc cua he thong (xem
  `sudo -l` tren target de biet ban co nhung cong cu nao) - hay doc ky tung cong cu
  duoc cap va dung DUNG cach (vd mot cong cu co the can chi dinh ro ten tai khoan cho
  du da chay qua sudo).
  Tu kiem chung sau khi doi: goi thu trang chu va trang dang nhap bang GIA TRI CU -
  phai bi TU CHOI; goi lai trang chu - phai VAN 200 (dich vu khong sap).

--- Task 6: Tu viet luat phat hien (TREN TERMINAL SIEM) ---
  Muc tieu: viet mot luat Wazuh (id tu chon, phai >= 100000) de he thong TU DONG canh
  bao moi khi co request toi duong dan file backup cau hinh bi lo - nhung KHONG duoc
  canh bao nham voi cac request binh thuong khac (lab co san mot request "lanh tinh"
  lap lai de ban tu kiem tra false-positive).
  Boi canh/Quan sat: dong log truy cap toi duong dan nay co the tra ve ma trang thai
  KHAC NHAU (200 hoac 404) tuy thoi diem - luat cua ban phai no voi ca hai truong
  hop. Thu voi mot rule doc lap (khong <if_sid>) truoc - quan sat ket qua wazuh-
  logtest xem rule nao thuc su no, vi sao.
  Yeu cau: rule cua ban PHAI no (Alert to be generated) tren request toi duong dan
  file backup, va KHONG no tren request toi duong dan lanh tinh (favicon.ico).
  Goi y cong cu: sua /var/ossec/etc/rules/local_rules.xml tren SIEM; dung <url> hoac
  <match> de loc duong dan; neu rule doc lap khong no, thu KE THUA (<if_sid>) tu rule
  mac dinh da khop truoc do (xem id rule mac dinh da no trong wazuh-logtest truoc khi
  them <if_sid> cua ban); kiem thu truoc-sau bang `wazuh-logtest`, nap lai bang
  `systemctl restart wazuh-manager`.
  Tu kiem chung: chay wazuh-logtest voi CA HAI dong log mau (duong dan nhay cam va
  favicon.ico) - chi dong dau no rule cua ban.

--- Task 7: Kiem chung & bao cao (TREN TERMINAL TARGET) ---
  Muc tieu: ghi lai toan bo ket luan dieu tra vao /home/analyst/findings.txt de he
  thong cham diem doi chieu.
  Yeu cau: file phai co du cac truong (moi dong mot truong, dang TEN=GIA_TRI):
    ATTACKER_IP          -- IP da xac dinh o Task 1.
    CONFIRMED_LEAKED      -- danh sach (phan tach bang dau phay) cac loai artifact
                             DA BI LAY THUC SU, ket luan tu Task 2.
    EXPOSED_UNTOUCHED     -- danh sach cac loai artifact LO NHUNG CHUA BI LAY, ket
                             luan tu Task 2.
    TIME_LEAK             -- gio (HH:MM) tu Task 3.
    TIME_LOGIN            -- gio (HH:MM) tu Task 3.
    TIME_EXPORT           -- gio (HH:MM) tu Task 3.
  Goi y cong cu: tao file bang trinh soan thao hoac chuyen huong (redirect/heredoc)
  tu terminal - CHU Y mot so moi truong shell loi voi `sudo bash -c 'cat <<EOF ...'`,
  neu gap loi "handleRedirect" hay doi sang dung `tee`.
  Tu kiem chung: doc lai file, doi chieu voi ket luan Task 2 va Task 3 - dam bao
  khong con cho trong (placeholder) chua dien.

6. NOP BAI (SUBMISSION)
--------------------------------------------------------------------------------
  checkwork soc-secrets-leak  -> tu kiem tra ; stoplab -> nop bai.
  Cac muc cham (chi cham VIEC BAN LAM, khong co muc nao "tu Y" khi lab vua khoi dong):
    - reported_iocs          : findings.txt dung IP, dung tap CONFIRMED_LEAKED va
                                EXPOSED_UNTOUCHED (phai khop CHINH XAC tung tap, khong
                                thieu khong du).
    - timeline_reconstructed : 3 moc TIME_* khop GIO THAT trong log (+-1 phut) va
                                dung thu tu.
    - contained               : da chan DUNG IP ke tan cong (khong chan bua).
    - exposure_closed         : moi artifact bi lo (ke ca phan EXPOSED_UNTOUCHED) deu
                                khong con truy cap duoc; trang chu app van song.
    - secrets_rotated         : CA BA bi mat cu (mat khau DB, mat khau admin, API
                                key) deu bi he thong tu choi sau khi xoay khoa. Day la
                                co che bat loi "chi xoa file ma quen xoay khoa".
    - sla_ok                  : dich vu cong khai cua app van hoat dong binh thuong
                                sau khi xoay khoa (khong sap vi lech dong bo).
    - detection_rule           : luat Wazuh tu viet NO dung tren request nhay cam va
                                KHONG no tren request lanh tinh.
    - incident_resolved        : dat duoc TAT CA cac muc tren.
  Luu y: cac gia tri bi mat/thoi gian la CA NHAN HOA rieng cho may cua ban - khong
  dung gia tri cua ban khac du cung mot lop.
__EOF_SL_RF__

# ---------------------------------------------------------------------------
# instr_config
# ---------------------------------------------------------------------------
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_SL_7qk2__'
# goals.config - IR: Lo bi mat qua .git/backup -> chiem credential -> xoay khoa
# Chi cham VIEC SINH VIEN LAM. Khong co muc tu dong Y khi lab vua khoi dong.

# Dieu tra & bao cao dung IOC ca nhan hoa (IP that + dung 2 tap bi mat: lay that / lo nhung chua lay)
reported_iocs          = boolean : ( _rep_ip and _rep_leaked and _rep_exposed )
# Dung lai dung 3 moc timeline, khop GIO THAT trong log va dung thu tu
timeline_reconstructed = boolean : _timeline

# Phat hien: SV tu viet rule rieng (id 100000-198999) bat dung request toi file nhay cam,
# va KHONG bat nham request lanh tinh (favicon.ico)
detection_rule          = boolean : ( _siem_marker and _detect and_not _falsepos )

# Containment: da chan IP ke tan cong
contained                = boolean : _contained
# Eradication: cac artifact lo khong con truy cap duoc, trang public van song
exposure_closed          = boolean : _exposure
# Xoay khoa: ca 3 bi mat cu (mat khau admin, mat khau DB, API key) deu bi tu choi
secrets_rotated          = boolean : _rotated
# Giu dich vu song: trang public + tai khoan ops van dang nhap/xem duoc sau khi xoay khoa
sla_ok                   = boolean : _sla

# MUC TIEU TONG: dieu tra dung + dung lai timeline + phat hien dung + containment +
# dong het duong lo + xoay het khoa + dich vu van song
incident_resolved = boolean : ( _marker and _contained and _exposure and _rotated and _sla and _detect and_not _falsepos )
__EOF_SL_7qk2__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_SL_7qk2__'
_marker       = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
_exposure     = target:prestop.stdout : FILE_REGEX : EXPOSURE_CLOSED
_rotated      = target:prestop.stdout : FILE_REGEX : ROTATED_OK
_sla          = target:prestop.stdout : FILE_REGEX : SLA_OK
_contained    = target:prestop.stdout : FILE_REGEX : CONTAINED
_rep_ip       = target:prestop.stdout : FILE_REGEX : REP_IP_OK
_rep_leaked   = target:prestop.stdout : FILE_REGEX : REP_LEAKED_OK
_rep_exposed  = target:prestop.stdout : FILE_REGEX : REP_EXPOSED_OK
_time_leak    = target:prestop.stdout : FILE_REGEX : TIME_LEAK_OK
_time_login   = target:prestop.stdout : FILE_REGEX : TIME_LOGIN_OK
_time_export  = target:prestop.stdout : FILE_REGEX : TIME_EXPORT_OK
_timeline     = target:prestop.stdout : FILE_REGEX : TIMELINE_OK
_siem_marker  = siem:prestop.stdout   : FILE_REGEX : PRESTOP_MARKER
_detect       = siem:prestop.stdout   : FILE_REGEX : DETECTION_OK
_falsepos     = siem:prestop.stdout   : FILE_REGEX : FALSE_POSITIVE

# --- Goi y checkwork (chi neu HUONG xu ly, KHONG dua lenh/dap an) ---
#CHECK_TRUE: Con artifact lo truy cap duoc (.git, file backup, hoac .env.old). Hay chan truy cap va go chung.
cw_exposure = target:prestop.stdout : FILE_REGEX : EXPOSURE_CLOSED
#CHECK_TRUE: Chua xoay het 3 bi mat (mat khau admin, mat khau DB, API key). Mat khau cu van con dung duoc.
cw_rotated  = target:prestop.stdout : FILE_REGEX : ROTATED_OK
#CHECK_TRUE: Dich vu dang khong song binh thuong (trang public hoac tai khoan ops). Kiem tra dong bo giua DB va file cau hinh.
cw_sla      = target:prestop.stdout : FILE_REGEX : SLA_OK
#CHECK_TRUE: Chua chan IP ke tan cong. Hay chan bang tuong lua tren target.
cw_contain  = target:prestop.stdout : FILE_REGEX : CONTAINED
#CHECK_TRUE: Bao cao IOC (IP / tap bi mat lay that / tap bi mat lo nhung chua lay) chua dung hoac chua du.
cw_report   = target:prestop.stdout : FILE_REGEX : REP_EXPOSED_OK
#CHECK_TRUE: Timeline 3 moc chua khop gio that hoac chua dung thu tu. Doi chieu lai voi log tren target.
cw_timeline = target:prestop.stdout : FILE_REGEX : TIMELINE_OK
#CHECK_TRUE: Chua co rule tu viet phat hien dung request toi file nhay cam, hoac rule dang bat nham request lanh tinh.
cw_detect   = siem:prestop.stdout   : FILE_REGEX : DETECTION_OK
__EOF_SL_7qk2__

# ---------------------------------------------------------------------------
# siem
# ---------------------------------------------------------------------------
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_SL_7qk2__'
#!/bin/bash
# soc-wazuh da cai san Wazuh. Quyen cac user Wazuh + .labname duoc khoi phuc o /entrypoint.sh
# (PID 1, TRUOC systemd). lab_rules.sh duoc chay boi lab-rules.service (systemd), khong goi o day.
# Khong chown gi o day (chown /var/lib luc dang chay se hong node.lock cua OpenSearch).
exit 0
__EOF_SL_7qk2__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/prestop" <<'__EOF_SL_7qk2__'
#!/bin/bash
# Chup trang thai siem luc checkwork/stoplab -> prestop.stdout (cham diem detection_rule).
# QUAN TRONG: chi in CO/OK, KHONG in noi dung rule hay alert that -> tranh sinh vien chep dap an.
trap "echo Timed out; exit" SIGTERM

ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null

echo "PRESTOP_MARKER"

AL=/var/ossec/logs/alerts/alerts.log
# Doc qua sudo (file chi root/nhom wazuh doc duoc). Sudoers chi cho phep dung "cat" (khong cho tail/head).
RAW=$(sudo -n cat "$AL" 2>/dev/null)

# Wazuh ghi moi alert thanh mot khoi nhieu dong, cac khoi cach nhau boi 1 dong trong.
# Voi moi khoi: tim dong "Rule: <id> (level N)", chi nhan id trong khoang 100000-198999
# (quy uoc: 199000-199999 danh cho rule NEN cua lab, id SV tu viet phai nam ngoai khoang do).
rule_hit_on() {
    # $1 = chuoi con can tim trong khoi (vi du duong dan nhay cam hoac marker lanh tinh)
    local pattern="$1"
    echo "$RAW" | awk -v RS="" -v pat="$pattern" '
        $0 ~ pat && $0 ~ /Rule: [0-9]+ \(level/ {
            n = split($0, lines, "\n")
            for (i = 1; i <= n; i++) {
                if (lines[i] ~ /^Rule: [0-9]+/) {
                    split(lines[i], parts, " ")
                    id = parts[2] + 0
                    if (id >= 100000 && id <= 198999) { print "HIT"; exit }
                }
            }
        }
    '
}

# config.php.bak-<so> la duong dan file backup bi lo (phan "config.php.bak" khong doi giua cac SV).
# favicon.ico la probe LANH TINH co dinh ma attacker tu goi dinh ky de kiem tra rule qua rong.
DETECT=$(rule_hit_on "config[.]php[.]bak")
FALSEPOS=$(rule_hit_on "favicon[.]ico")

[ "$DETECT" = "HIT" ] && echo "DETECTION_OK"
[ "$FALSEPOS" = "HIT" ] && echo "FALSE_POSITIVE"

exit 0
__EOF_SL_7qk2__
mkdir -p "$LAB/siem"
cat > "$LAB/siem/lab_rules.sh" <<'__EOF_SL_7qk2__'
#!/bin/bash
# soc-secrets-leak - siem: cai decoder + rule NEN cho log cua web app (rule id 199xxx).
# Chay bang ROOT, o nen (goi tu lab-rules.service luc boot). Log: /var/log/lab_rules.log
# QUY UOC: id 199000-199999 danh cho lab. Rule cua sinh vien phai dung id 100000-198999.
LOG=/var/log/lab_rules.log
echo "[lab_rules] bat dau $(date)" > "$LOG"

# 1) Cho Wazuh da san sang (thu muc rules/decoders co san), toi da ~5 phut
for i in $(seq 1 60); do
  [ -f /var/ossec/etc/rules/local_rules.xml ] && [ -f /var/ossec/etc/decoders/local_decoder.xml ] && break
  sleep 5
done
if [ ! -f /var/ossec/etc/rules/local_rules.xml ]; then
  echo "[lab_rules] LOI: khong thay /var/ossec/etc/rules/local_rules.xml" >> "$LOG"; exit 1
fi
# cho analysisd chay (khong bat buoc, toi da ~2 phut)
for i in $(seq 1 24); do
  /var/ossec/bin/wazuh-control status 2>/dev/null | grep -q "wazuh-analysisd is running" && break
  sleep 5
done

# 2) Decoder: dong log dang syslog "Oct 30 12:34:56 target corpportal: ACTION user=<ten> ip=<ip> [rows=N]"
#    Ten chuong trinh 'corpportal' phai KHONG trung decoder co san (da gap: 'webapp' bi decoder Barracuda chiem;
#    dong bat dau bang ngay YYYY-MM-DD thi bi 'windows-date-format' chiem).
cat > /var/ossec/etc/decoders/199_webapp_decoder.xml <<'XML'
<decoder name="corpportal">
  <program_name>^corpportal$</program_name>
</decoder>

<decoder name="corpportal-auth">
  <parent>corpportal</parent>
  <regex>^(\w+) user=(\S+) ip=(\S+)</regex>
  <order>action,srcuser,srcip</order>
</decoder>
XML

# 3) Rule nen (id 199001-199003)
cat > /var/ossec/etc/rules/199_webapp_rules.xml <<'XML'
<group name="local,webapp,">
  <rule id="199001" level="3">
    <decoded_as>corpportal</decoded_as>
    <match>LOGIN_OK</match>
    <description>Webapp: dang nhap thanh cong</description>
  </rule>

  <rule id="199002" level="5">
    <decoded_as>corpportal</decoded_as>
    <match>LOGIN_FAIL</match>
    <description>Webapp: dang nhap that bai</description>
  </rule>

  <rule id="199003" level="7">
    <decoded_as>corpportal</decoded_as>
    <match>EXPORT</match>
    <description>Webapp: xuat du lieu khach hang</description>
  </rule>
</group>
XML

# 4) Quyen file giong file local mac dinh (manager phai doc duoc)
for f in /var/ossec/etc/rules/199_webapp_rules.xml:/var/ossec/etc/rules/local_rules.xml \
         /var/ossec/etc/decoders/199_webapp_decoder.xml:/var/ossec/etc/decoders/local_decoder.xml; do
  new="${f%%:*}"; ref="${f##*:}"
  chown --reference="$ref" "$new" 2>/dev/null || chown wazuh:wazuh "$new" 2>/dev/null || true
  chmod --reference="$ref" "$new" 2>/dev/null || chmod 660 "$new"
done

# 4b) Tat SCA (Security Configuration Assessment) tren manager: sinh hang tram alert 19xxx lam nhieu dashboard
sed -i '/<sca>/,/<\/sca>/ s#<enabled>yes</enabled>#<enabled>no</enabled>#' /var/ossec/etc/ossec.conf 2>>"$LOG"

# 5) Nap lai
systemctl restart wazuh-manager >> "$LOG" 2>&1 || service wazuh-manager restart >> "$LOG" 2>&1 || true
echo "[lab_rules] xong $(date)" >> "$LOG"
__EOF_SL_7qk2__

# ---------------------------------------------------------------------------
# target
# ---------------------------------------------------------------------------
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_SL_7qk2__'
#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# setup_app.sh dung MariaDB (cho san sang den 60*3s) nen chay NEN, log ra /tmp/setup_app.log.
PW="$1"
echo "$PW" | sudo -S bash -c 'nohup bash /home/ubuntu/setup_app.sh > /tmp/setup_app.log 2>&1 &'
exit 0
__EOF_SL_7qk2__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/prestop" <<'__EOF_SL_7qk2__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (cham diem incident_resolved).
# QUAN TRONG: chi in CO (presence flag) / OK, KHONG in gia tri that (mat khau, IP, gio that)
# -> tranh sinh vien doc prestop.stdout de chep dap an.
trap "echo Timed out; exit" SIGTERM

# Chi giu DUY NHAT ban chup moi nhat (tranh grader doc nham ban cu truoc khi co su co).
ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null

echo "PRESTOP_MARKER"

# ============== Doc ground-truth (chi root, KHONG in ra) ==============
GT=/root/.soc_truth
ATTACKER_IP=$(sudo -n grep '^ATTACKER_IP=' "$GT" 2>/dev/null | cut -d= -f2)
OLD_ADMIN_PASS=$(sudo -n grep '^OLD_ADMIN_PASS=' "$GT" 2>/dev/null | cut -d= -f2)
OLD_DB_PASS=$(sudo -n grep '^OLD_DB_PASS=' "$GT" 2>/dev/null | cut -d= -f2)
OLD_API_KEY=$(sudo -n grep '^OLD_API_KEY=' "$GT" 2>/dev/null | cut -d= -f2)
OPS_PASS=$(sudo -n grep '^OPS_PASS=' "$GT" 2>/dev/null | cut -d= -f2)
GT_LEAKED=$(sudo -n grep '^LEAKED=' "$GT" 2>/dev/null | cut -d= -f2)
GT_EXPOSED=$(sudo -n grep '^EXPOSED_UNTOUCHED=' "$GT" 2>/dev/null | cut -d= -f2)
BAKFILE=$(sudo -n grep '^BAKFILE=' "$GT" 2>/dev/null | cut -d= -f2)

# ============== 1) EXPOSURE_CLOSED: artifact lo khong con truy cap duoc, trang public van song ==============
CODE_IDX=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://localhost/")
CODE_GIT=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://localhost/.git/HEAD")
CODE_BAK=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://localhost/$BAKFILE")
CODE_ENVOLD=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://localhost/.env.old")
if [ "$CODE_IDX" = "200" ] && [ "$CODE_GIT" != "200" ] && [ "$CODE_BAK" != "200" ] && [ "$CODE_ENVOLD" != "200" ]; then
    echo "EXPOSURE_CLOSED"
fi

# ============== 2) ROTATED_OK: ca 3 bi mat cu deu bi tu choi ==============
ADMIN_REJECTED=0; DB_REJECTED=0; API_REJECTED=0

RESP=$(curl -s -m 3 -o /dev/null -w "%{http_code}" -d "username=admin&password=${OLD_ADMIN_PASS}" "http://localhost/login.php")
# login.php KHONG redirect tu dong qua curl (khong co -L): dang nhap dung tra ve 302, sai tra ve 401.
[ "$RESP" = "401" ] && ADMIN_REJECTED=1

mysql -u appuser -p"$OLD_DB_PASS" -e 'SELECT 1' >/dev/null 2>&1 || DB_REJECTED=1

RESP=$(curl -s -m 3 -o /dev/null -w "%{http_code}" -H "X-API-Key: $OLD_API_KEY" "http://localhost/api/info.php")
[ "$RESP" != "200" ] && API_REJECTED=1

if [ "$ADMIN_REJECTED" = "1" ] && [ "$DB_REJECTED" = "1" ] && [ "$API_REJECTED" = "1" ]; then
    echo "ROTATED_OK"
fi

# ============== 3) SLA_OK: trang public song, tai khoan ops (checker biet) dang nhap va xem dashboard duoc ==============
SLA_INDEX=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://localhost/")
COOKIEJAR=$(mktemp)
curl -s -m 3 -o /dev/null -c "$COOKIEJAR" -d "username=ops&password=${OPS_PASS}" "http://localhost/login.php"
SLA_DASH=$(curl -s -m 3 -o /dev/null -w "%{http_code}" -b "$COOKIEJAR" "http://localhost/dashboard.php")
rm -f "$COOKIEJAR"
if [ "$SLA_INDEX" = "200" ] && [ "$SLA_DASH" = "200" ]; then
    echo "SLA_OK"
fi

# ============== 4) CONTAINED: da chan IP ke tan cong bang iptables chua? ==============
if [ -n "$ATTACKER_IP" ]; then
    IP_ESC=$(echo "$ATTACKER_IP" | sed 's/\./\\./g')
    sudo -n iptables -S 2>/dev/null | grep -qE "${IP_ESC}(/32)?.*-j (DROP|REJECT)" && echo "CONTAINED"
fi

# ============== 5) BAO CAO IOC CUA ANALYST (so khop ground-truth, chi in OK) ==============
F=/home/analyst/findings.txt
set_eq() {
    # So sanh hai danh sach phan tay cach nhau bang dau phay, khong phan biet thu tu, khong phan biet hoa/thuong
    local a b
    a=$(echo "$1" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | tr 'a-z' 'A-Z' | sort | tr '\n' ',')
    b=$(echo "$2" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | tr 'a-z' 'A-Z' | sort | tr '\n' ',')
    [ -n "$a" ] && [ "$a" = "$b" ]
}
REP_IP=$(grep '^ATTACKER_IP=' "$F" 2>/dev/null | cut -d= -f2 | tr -d ' ')
REP_LEAKED=$(grep '^CONFIRMED_LEAKED=' "$F" 2>/dev/null | cut -d= -f2-)
REP_EXPOSED=$(grep '^EXPOSED_UNTOUCHED=' "$F" 2>/dev/null | cut -d= -f2-)

[ -n "$ATTACKER_IP" ] && [ "$REP_IP" = "$ATTACKER_IP" ] && echo "REP_IP_OK"
set_eq "$REP_LEAKED" "$GT_LEAKED" && echo "REP_LEAKED_OK"
set_eq "$REP_EXPOSED" "$GT_EXPOSED" && echo "REP_EXPOSED_OK"

# ============== 6) TIMELINE (so khop GIO THUC TE trong access.log / webapp auth.log, dung sai +-1 phut) ==============
# Gio that: lay HH:MM cua lan dau tien attacker (dung IP that) lay thanh cong artifact lo / dang nhap / export.
AL=/var/log/apache2/access.log
WL=/var/log/webapp/auth.log

gt_leak_time() {
    [ -n "$ATTACKER_IP" ] || return 1
    grep -F "$ATTACKER_IP" "$AL" 2>/dev/null \
        | grep -E 'GET /\.git/HEAD HTTP.* 200 ' \
        | head -1 \
        | grep -oE ':[0-9]{2}:[0-9]{2}:[0-9]{2} ' \
        | head -1 | cut -c2-6
}
gt_webapp_time() {
    # $1 = LOGIN_OK hoac EXPORT ; chi tinh dong co ip = attacker that
    [ -n "$ATTACKER_IP" ] || return 1
    grep -F "ip=$ATTACKER_IP" "$WL" 2>/dev/null \
        | grep "$1" \
        | head -1 \
        | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' \
        | head -1 | cut -c1-5
}
GT_LEAK=$(gt_leak_time)
GT_LOGIN=$(gt_webapp_time "LOGIN_OK")
GT_EXPORT=$(gt_webapp_time "EXPORT")

T_LEAK=$(grep '^TIME_LEAK=' "$F" 2>/dev/null | cut -d= -f2- | grep -oE '[0-9]{2}:[0-9]{2}')
T_LOGIN=$(grep '^TIME_LOGIN=' "$F" 2>/dev/null | cut -d= -f2- | grep -oE '[0-9]{2}:[0-9]{2}')
T_EXPORT=$(grep '^TIME_EXPORT=' "$F" 2>/dev/null | cut -d= -f2- | grep -oE '[0-9]{2}:[0-9]{2}')

to_min() {
    local hh=${1%%:*} mm=${1##*:}
    case "$hh$mm" in ""|*[!0-9]*) return 1;; esac
    echo $((10#$hh * 60 + 10#$mm))
}
close() {
    local s g d
    s=$(to_min "$1") || return 1
    g=$(to_min "$2") || return 1
    d=$(( s > g ? s - g : g - s ))
    [ "$d" -le 1 ]
}

close "$T_LEAK" "$GT_LEAK" && echo "TIME_LEAK_OK"
close "$T_LOGIN" "$GT_LOGIN" && echo "TIME_LOGIN_OK"
close "$T_EXPORT" "$GT_EXPORT" && echo "TIME_EXPORT_OK"

if close "$T_LEAK" "$GT_LEAK" && close "$T_LOGIN" "$GT_LOGIN" && close "$T_EXPORT" "$GT_EXPORT"; then
    lm=$(to_min "$T_LEAK"); om=$(to_min "$T_LOGIN"); em=$(to_min "$T_EXPORT")
    [ "$lm" -le "$om" ] && [ "$om" -le "$em" ] && echo "TIMELINE_OK"
fi

exit 0
__EOF_SL_7qk2__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_SL_7qk2__'
apache2
mariadbd
mysqld
wazuh-agent
sudo
iptables
iptables-save
sshd
__EOF_SL_7qk2__
mkdir -p "$LAB/target"
cat > "$LAB/target/setup_app.sh" <<'__EOF_SL_7qk2__'
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
__EOF_SL_7qk2__

echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/siem/*.sh \
         "$LAB"/defender/_bin/*.sh "$LAB"/target/setup_app.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-secrets-leak"
