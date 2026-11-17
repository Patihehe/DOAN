#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-decoder (Viet Custom Decoder cho log la - xpayd) tren VM Labtainers.
# Chay tren VM:  bash install-soc-decoder.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-decoder
# (siem = anh chung soc-wazuh (Wazuh cai san) -> rebuild NHANH. Can co localhost:5000/soc-wazuh.)
# (File nay duoc SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-decoder
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_DEC_7q4m__'
#!/bin/bash
# attacker (172.20.0.5): nguon brute-force + rut tien trai phep. Su co DA XAY RA va duoc ghi san
# trong log tren target (seed luc fixlocal cua target). Container nay chi giu dinh danh host/IP, khong chay gi them.
exit 0
__EOF_DEC_7q4m__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_DEC_7q4m__'
SOC Lab - Viet Custom Decoder cho log ung dung la (Detection Engineering): Dieu tra -> Bat -> Tinh chinh -> Ung pho.
Dich vu Cong thanh toan noi bo "xpayd" tren target ghi log DINH DANG RIENG vao /var/log/xpay/transactions.log.
Wazuh KHONG co decoder hieu dinh dang nay -> pipeline Log->Decoder->Rule->Alert DUT ngay o buoc Decoder ->
mot vu rut trom vi VIP (cfo_<ACID>, 85.000.000 VND) KHONG sinh canh bao nao (diem mu cua SOC).
Nhiem vu 3 pha: (1) DIEU TRA log tho - dien 5 cau ~/findings.txt; (2) BAT - tu viet DECODER (local_decoder.xml)
boc tach 6 truong + cay RULE phat hien brute-force (tan suat + same_source_ip) va rut tien gia tri lon,
KHONG bao gia tren giao dich hop le; (3) UNG PHO - chan IP ke tan cong + khoa tai khoan VIP, giu SLA.
__EOF_DEC_7q4m__
cat > "$LAB/config/parameter.config" <<'__EOF_DEC_7q4m__'
# parameter.config - ca nhan hoa (chong chep bai)
# ACID: so dinh danh vi VIP bi chiem (tai khoan cfo_<ACID>) - HIEN trong log, SV doc duoc.
# TXID: ma giao dich cua lenh rut tien trai phep (TX#<TXID>) - HIEN trong log.
# Ca hai token nam trong target fixlocal (seed log su co). Grading doc lai tu log de doi chieu findings.
ACID : RAND_REPLACE : target:.local/bin/fixlocal.sh : ACID : 1000 : 9999
TXID : RAND_REPLACE : target:.local/bin/fixlocal.sh : TXID : 10000 : 99999
__EOF_DEC_7q4m__
cat > "$LAB/config/start.config" <<'__EOF_DEC_7q4m__'
# start.config - Lab soc-decoder (Viet Custom Decoder cho log ung dung la: Cong thanh toan xpayd)
# 4 container: attacker (nguon brute-force/rut tien - lich su), target (chay xpayd + wazuh-agent),
#              siem (Wazuh - noi viet decoder/rule), defender (analyst: Firefox + SSH)

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-decoder_student_master_seed
	GRADE_CONTAINER target

# Mang ao SOC cho tat ca cac may
NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May chu ung dung (chay xpayd, ghi /var/log/xpay/transactions.log, wazuh-agent day ve siem) ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong (nguon brute-force + rut tien trai phep - su co da xay ra, nam trong log) ---
CONTAINER attacker
	USER ubuntu
	SOC_NET 172.20.0.5
	ADD-HOST target:172.20.0.10
	TERMINALS 0

# --- SIEM: Wazuh All-in-One (viet decoder + rule) ---
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
__EOF_DEC_7q4m__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_DEC_7q4m__'
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
__EOF_DEC_7q4m__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-decoder.attacker.student" <<'__EOF_DEC_7q4m__'
#
# Labtainer Dockerfile - attacker (nguon brute-force + rut tien trai phep; su co da xay ra - nam trong log target)
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
__EOF_DEC_7q4m__
cat > "$LAB/dockerfiles/Dockerfile.soc-decoder.defender.student" <<'__EOF_DEC_7q4m__'
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
__EOF_DEC_7q4m__
cat > "$LAB/dockerfiles/Dockerfile.soc-decoder.siem.student" <<'__EOF_DEC_7q4m__'
#
# siem - dung image nen soc-wazuh (Wazuh cai san). Entrypoint khoi phuc quyen Wazuh truoc init.
# (Da BAKE san anh chung vao nguon - KHONG can chay apply-shared-siem.sh. Giong Chang 0 + webshell + threathunt + dns-exfil.)
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
# Cho prestop chay wazuh-logtest (bom mau cham decoder/rule) + doc alerts khong can mat khau
RUN echo 'ubuntu ALL=(ALL) NOPASSWD: /var/ossec/bin/wazuh-logtest, /bin/cat /var/ossec/etc/rules/local_rules.xml, /usr/bin/cat /var/ossec/etc/rules/local_rules.xml, /bin/cat /var/ossec/logs/alerts/alerts.log, /usr/bin/cat /var/ossec/logs/alerts/alerts.log, /var/ossec/bin/agent_control' > /etc/sudoers.d/labtainer-wazuh \
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
RUN mkdir -p /home/$user_name/.local && echo "soc-decoder" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__EOF_DEC_7q4m__
cat > "$LAB/dockerfiles/Dockerfile.soc-decoder.target.student" <<'__EOF_DEC_7q4m__'
#
# Labtainer Dockerfile - target (May chu ung dung chay Cong thanh toan xpayd)
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

# Cho phep sudoers chay lenh quan tri + kiem tra cho prestop
RUN echo '%sudo ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/labtainer-decoder \
    && chmod 440 /etc/sudoers.d/labtainer-decoder

# Tien ich co ban + cron (cho luong nhieu nen lanh tinh)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron coreutils procps iptables || true

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
__EOF_DEC_7q4m__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_DEC_7q4m__'
================================================================================
 SOC LAB: VIET CUSTOM DECODER CHO LOG LA (xpayd) - DIEU TRA -> BAT -> TINH CHINH -> UNG PHO
================================================================================

1. TONG QUAN / SU CO
--------------------------------------------------------------------------------
Dich vu "Cong thanh toan noi bo" xpayd chay tren target (172.20.0.10), ghi nhat ky giao dich vao
/var/log/xpay/transactions.log va DA duoc cau hinh day ve siem (172.20.0.20) qua wazuh-agent.

Sang nay Ke toan phat hien vi VIP cua Giam doc Tai chinh (cfo_<so>) bi RUT TROM 85.000.000 VND.
DIEM MU: du agent van day log deu dan, Wazuh Dashboard KHONG co canh bao nao.
NGUYEN NHAN KY THUAT: xpayd ghi log theo DINH DANG RIENG (do lap trinh vien tu dat). Wazuh KHONG co
decoder nao hieu dong log nay -> pipeline Log -> DECODER -> Rule -> Alert DUT ngay o buoc DECODER.

*** Lan dau doi siem khoi dong Wazuh (~1-2' - anh chung da cai san). ***

2. MUC TIEU HOC TAP
--------------------------------------------------------------------------------
  - Hieu pipeline Wazuh: PreDecoder -> Decoder -> Rule. Biet khi nao can tu viet DECODER.
  - Tu viet CUSTOM DECODER (parent + child) boc tach log dinh dang rieng thanh cac TRUONG.
  - Viet CAY RULE phan cap dung truong da decode: tan suat (brute-force) + nguong gia tri (fraud).
  - Tinh chinh de KHONG bao gia (same_source_ip, nguong so tien) tren giao dich hop le.

3. KIEN THUC NEN (QUAN TRONG - Wazuh dung OS_Regex, KHONG phai PCRE)
--------------------------------------------------------------------------------
* Dinh dang 1 dong log xpayd (sau syslog header "... target xpayd[pid]:"):
    TX#<id>|SRC=<ip>|USER=<user>|ACT=<LOGIN|TRANSFER|WITHDRAW>|RES=<OK|FAIL>|AMT=<so>|NOTE=<ghi chu>
* Decoder: <program_name> o PARENT khop ten chuong trinh; CHILD dung <regex> + <order> de BOC truong.
  Dung TEN TRUONG CHUAN cua Wazuh: srcip va dstuser -> moi kich hoat duoc <same_source_ip /> o rule.
* *** Bay TEN TRUONG TINH (static) ***: cac ten action, status, srcip, dstip, id, url, protocol...
  la TRUONG TINH danh rieng cua Wazuh. Rule KHONG duoc khop truong tinh bang <field name="...">
  (bao loi "Field 'action' is static"). <field name=...> CHI dung cho truong DONG. Vi vay dat ten
  2 truong trang thai la act, res (khong trung tu khoa) -> thanh truong dong -> khop bang <field> binh thuong.
* *** Bay OS_Regex (y het loi pcre2 ban hay gap) ***
   - <regex> va <field> dung OS_Regex, KHONG co {n,} va KHONG backtrack nhu PCRE.
   - KHONG dung (\S+) de boc truong: \S khop ca dau '|' -> "nuot" lan sang truong sau -> boc sai.
     DUNG \w (chu-so-gach_, KHONG khop '|') hoac \d -> tu dung o dung dau phan tach.
   - KHONG dung ^\d{8,}$ cho "so tien >= 8 chu so": thay bang LAP \d 8 lan: ^\d\d\d\d\d\d\d\d
     (150000/500000 = 6 chu so -> khong dinh; 85000000 = 8 chu so -> dinh; nguong = 10 trieu).

4. MOI TRUONG & DANG NHAP
--------------------------------------------------------------------------------
  target (172.20.0.10) -- chay xpayd, log /var/log/xpay/transactions.log, wazuh-agent
  attacker (172.20.0.5) -- nguon brute-force + rut tien (su co da xay ra, nam trong log)
  siem    (172.20.0.20) -- Wazuh: noi VIET DECODER + RULE
  defender(172.20.0.30) -- tram cua ban: Firefox + SSH
  Dang nhap dashboard: https://172.20.0.20   admin / Q*uJjovx2guqFRqntC568k?lf3evm.jl
  Dang nhap target:    ssh analyst@172.20.0.10   (mat khau: analyst)

5. NHIEM VU
--------------------------------------------------------------------------------
--- PHA 1: DIEU TRA LOG THO -> dien ~/findings.txt (5 cau, tren target) ---
  Mo ~/findings.txt (co san tren target) va dien 5 truong:
     LOG_PROGRAM  = ten chuong trinh (program_name) sinh dong log la
     ATTACKER_IP  = IP (SRC) brute-force + rut tien trai phep
     VICTIM_USER  = tai khoan vi VIP bi chiem (dang cfo_<so>)
     FRAUD_TX_ID  = ma giao dich lenh rut tien trai phep (dang TX#<so>)
     FRAUD_AMOUNT = so tien bi rut trai phep (chi so)
  GOI Y:
   Cap 1: xem log tho; nhan ra 3 luong (giao dich hop le; chuoi LOGIN FAIL don dap; 1 lenh WITHDRAW lon).
   Cap 2 (ssh analyst@172.20.0.10):
     - grep 'ACT=WITHDRAW' /var/log/xpay/transactions.log        # dong rut tien trai phep (SRC, USER, TX#, AMT)
     - grep 'RES=FAIL'     /var/log/xpay/transactions.log | tail # chuoi brute-force
     - Chay thu tren SIEM:  sudo /var/ossec/bin/wazuh-logtest  roi dan 1 dong log xpayd ->
         Phase 1 ra program_name: 'xpayd' NHUNG Phase 2 bao "No decoder matched" -> DUNG diem mu.
   Cap 3: LOG_PROGRAM=xpayd ; ATTACKER_IP=172.20.0.5 ; VICTIM_USER=cfo_<so o log> ;
          FRAUD_TX_ID=TX#<so o dong WITHDRAW> ; FRAUD_AMOUNT=85000000.

--- PHA 2: BAT - viet DECODER + RULE (tren SIEM), test bang wazuh-logtest ---
 (A) DECODER: sua /var/ossec/etc/decoders/local_decoder.xml, boc 6 truong theo thu tu
     tx_id, srcip, dstuser, act, res, amount:
        <decoder name="xpayd">
          <program_name>^xpayd$</program_name>
        </decoder>
        <decoder name="xpayd-fields">
          <parent>xpayd</parent>
          <regex>^TX#(\w+)\|SRC=(\d+.\d+.\d+.\d+)\|USER=(\w+)\|ACT=(\w+)\|RES=(\w+)\|AMT=(\d+)</regex>
          <order>tx_id, srcip, dstuser, act, res, amount</order>
        </decoder>
     (act = action, res = result/status - dat ten KHONG trung tu khoa tinh de rule khop bang <field>.)
     Kiem chung: sudo /var/ossec/bin/wazuh-logtest -> dan dong WITHDRAW -> Phase 2 phai hien
       name: 'xpayd' ; srcip: '172.20.0.5' ; dstuser: 'cfo_...' ; act: 'WITHDRAW' ;
       res: 'OK' ; amount: '85000000'.  (Neu van "No decoder matched" -> xem lai \w / dau \| .)

 (B) RULE: sua /var/ossec/etc/rules/local_rules.xml, viet cay rule dung truong vua decode:
        <group name="local,xpay_security,">
          <rule id="100500" level="3">
            <decoded_as>xpayd</decoded_as>
            <description>XPAY transaction event</description>
          </rule>
          <rule id="100501" level="5">
            <if_sid>100500</if_sid>
            <field name="act">^LOGIN$</field>
            <field name="res">^FAIL$</field>
            <description>XPAY: Failed login for $(dstuser) from $(srcip)</description>
            <mitre><id>T1110</id></mitre>
          </rule>
          <rule id="100502" level="10" frequency="5" timeframe="60">
            <if_matched_sid>100501</if_matched_sid>
            <same_source_ip />
            <description>XPAY: Brute-force from $(srcip) targeting $(dstuser)</description>
            <mitre><id>T1110</id></mitre>
            <group>xpay_bruteforce,</group>
          </rule>
          <rule id="100503" level="12">
            <if_sid>100500</if_sid>
            <field name="act">^WITHDRAW$|^TRANSFER$</field>
            <field name="res">^OK$</field>
            <field name="amount">^\d\d\d\d\d\d\d\d</field>
            <description>XPAY CRITICAL: High-value $(amount) by $(dstuser) from $(srcip)</description>
            <mitre><id>T1078</id></mitre>
            <group>xpay_fraud,</group>
          </rule>
        </group>
     Nap: sudo systemctl restart wazuh-manager.

 *** CHAM DIEM PHA 2 THE NAO (de ban nham dung muc tieu) ***
   checkwork BOM MAU vao wazuh-logtest (doc thang file cua ban, KHONG can agent/restart) + doc file rule:
     - decoder_ok          : dong WITHDRAW bi boc dung 5 truong srcip/dstuser/act/res/amount.
     - high_value_detected : dong WITHDRAW (AMT=85000000) no canh bao level >= 12.
     - no_false_positive   : giao dich hop le (150000, 6 chu so) + bien 9.999.999 (7 chu so) + 1 FAIL le te
                             -> KHONG cai nao len level >= 10 (=> nguong tien PHAI la 8 chu so, dung ^\d\d\d\d\d\d\d\d).
     - bruteforce_detected : (a) 1 dong LOGIN FAIL no rule co ban cua ban (level >= 5, chung to rule khop
                             dung field act=LOGIN + res=FAIL) VA (b) file rule co du cau truc tuong quan:
                             frequency + same_source_ip + if_matched_sid.
   *** LUU Y QUAN TRONG: wazuh-logtest KHONG mo phong duoc rule TAN SUAT co <same_source_ip/> -> ban bom
       6 dong FAIL vao logtest se CHI thay level 5 (rule con 100502 KHONG no trong logtest). DAY LA BINH THUONG,
       KHONG phai loi rule. Rule tan suat chi no that tren MANAGER (xem alerts.log khi co su kien live). Vi vay
       grader cham brute-force bang CAU TRUC rule (phan b) + rule co ban no (phan a), khong doi logtest no 100502. ***

--- PHA 3: UNG PHO NHE (tren target) ---
  1. Chan IP ke tan cong:   sudo iptables -A INPUT -s 172.20.0.5 -j DROP
     (TUYET DOI khong chan 172.20.0.20 = SIEM -> se dut giam sat, truot SLA.)
  2. Khoa tai khoan VIP bi chiem: them cfo_<so> vao danh sach khoa:
       echo "cfo_<so>" | sudo tee -a /etc/xpay/locked_accounts
  (Luong giao dich nhieu nen la DICH VU HE THONG hop le - KHONG dong toi.)

6. NOP BAI
--------------------------------------------------------------------------------
  checkwork -> tu kiem tra ; stoplab -> nop bai. Cac muc cham:
    - reported            : 5 cau findings.txt dung.
    - decoder_ok          : decoder boc dung 6 truong.
    - bruteforce_detected : rule tan suat (frequency + same_source_ip) no tren brute-force.
    - high_value_detected : rule nguong so tien no tren lenh rut tien lon.
    - no_false_positive   : giao dich hop le / FAIL le te KHONG bi bao nham muc cao.
    - responded           : da chan IP ke tan cong (172.20.0.5).
    - account_secured     : da khoa cfo_<so> trong /etc/xpay/locked_accounts.
    - sla_ok              : ket noi toi SIEM (172.20.0.20) van song.
__EOF_DEC_7q4m__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_DEC_7q4m__'
# goals.config - soc-decoder (Viet Custom Decoder + Rule; Dieu tra + Ung pho nhe)
# Chi cham VIEC SINH VIEN LAM. Pha 2 cham bang wazuh-logtest bom mau (khong phu thuoc agent/restart).

# ===== PHA 1 - DIEU TRA: 5 cau trong ~/findings.txt (target prestop doi chieu su that) =====
reported = boolean : ( _rep_prog and _rep_attacker and _rep_victim and _rep_txid and _rep_amount )

# ===== PHA 2 - BAT + TINH CHINH (siem: wazuh-logtest bom mau) =====
# Decoder boc dung 6 truong (tx_id, srcip, dstuser, act, res, amount)
decoder_ok          = boolean : _decoder
# Rule tan suat NO tren 6 lan LOGIN FAIL cung srcip (level >= 10)
bruteforce_detected = boolean : _bruteforce
# Rule NO tren giao dich WITHDRAW gia tri lon >= 10 trieu (level >= 12)
high_value_detected = boolean : _highvalue
# KHONG bao gia: giao dich hop le + FAIL le te KHONG sinh canh bao muc cao (level < 10)
no_false_positive   = boolean : _no_fp

# ===== PHA 3 - UNG PHO NHE =====
# Chan IP ke tan cong (.5)
responded       = boolean : ( _marker and _blocked )
# Khoa tai khoan VIP bi chiem (cfo_<ACID> vao /etc/xpay/locked_accounts)
account_secured = boolean : ( _marker and _acct_locked )
# Giu ket noi giam sat toi SIEM (.20) - khong chan bua
sla_ok          = boolean : ( _marker and _sla )

# Dat bai = reported + decoder_ok + bruteforce_detected + high_value_detected + no_false_positive
#           + responded + account_secured + sla_ok.
__EOF_DEC_7q4m__
cat > "$LAB/instr_config/results.config" <<'__EOF_DEC_7q4m__'
# results.config - soc-decoder. Chi cham VIEC SINH VIEN LAM; prestop in co/OK, khong lo dap an.

# --- target: ung pho + marker ---
_marker      = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
_blocked     = target:prestop.stdout : FILE_REGEX : ATTACKER_BLOCKED
_acct_locked = target:prestop.stdout : FILE_REGEX : ACCOUNT_LOCKED
_sla         = target:prestop.stdout : FILE_REGEX : SLA_OK

# --- target: dieu tra 5 cau findings.txt (prestop doi chieu voi su that trong log) ---
_rep_prog     = target:prestop.stdout : FILE_REGEX : REP_PROG_OK
_rep_attacker = target:prestop.stdout : FILE_REGEX : REP_ATTACKER_OK
_rep_victim   = target:prestop.stdout : FILE_REGEX : REP_VICTIM_OK
_rep_txid     = target:prestop.stdout : FILE_REGEX : REP_TXID_OK
_rep_amount   = target:prestop.stdout : FILE_REGEX : REP_AMOUNT_OK

# --- siem: decoder + rule cua SV (cham bang wazuh-logtest bom mau) ---
_decoder    = siem:prestop.stdout : FILE_REGEX : DECODER_OK
_bruteforce = siem:prestop.stdout : FILE_REGEX : BRUTEFORCE_DETECTED
_highvalue  = siem:prestop.stdout : FILE_REGEX : HIGH_VALUE_DETECTED
_no_fp      = siem:prestop.stdout : FILE_REGEX : NO_FP_OK

# --- Goi y checkwork ---
#CHECK_TRUE: Chua viet/nap DECODER dung - sua /var/ossec/etc/decoders/local_decoder.xml, boc 6 truong (tx_id, srcip, dstuser, act, res, amount), test wazuh-logtest.
cw_dec = siem:prestop.stdout : FILE_REGEX : DECODER_OK
#CHECK_TRUE: Rule brute-force chua no - rule tan suat (frequency + same_source_ip) tren LOGIN FAIL cung srcip, level >= 10.
cw_bf = siem:prestop.stdout : FILE_REGEX : BRUTEFORCE_DETECTED
#CHECK_TRUE: Rule rut tien gia tri lon chua no - rule tren ACT=WITHDRAW/TRANSFER + RES=OK + amount >= 8 chu so, level >= 12.
cw_hv = siem:prestop.stdout : FILE_REGEX : HIGH_VALUE_DETECTED
#CHECK_TRUE: Rule dang BAO GIA tren giao dich hop le - siet lai (same_source_ip, nguong amount 8 chu so) de giao dich hop le KHONG nen level >= 10.
cw_fp = siem:prestop.stdout : FILE_REGEX : NO_FP_OK
#CHECK_TRUE: Chua dien dung 5 cau trong ~/findings.txt (LOG_PROGRAM, ATTACKER_IP, VICTIM_USER, FRAUD_TX_ID, FRAUD_AMOUNT).
cw_rep = target:prestop.stdout : FILE_REGEX : REP_VICTIM_OK
#CHECK_TRUE: Chua chan IP ke tan cong - sudo iptables -A INPUT -s 172.20.0.5 -j DROP (dung chan .20 = SIEM).
cw_block = target:prestop.stdout : FILE_REGEX : ATTACKER_BLOCKED
#CHECK_TRUE: Chua khoa tai khoan VIP bi chiem - them cfo_<ACID> vao /etc/xpay/locked_accounts.
cw_acct = target:prestop.stdout : FILE_REGEX : ACCOUNT_LOCKED
#CHECK_TRUE: Ket noi toi SIEM (172.20.0.20) phai CON - dung chan bua lam dut giam sat.
cw_sla = target:prestop.stdout : FILE_REGEX : SLA_OK
__EOF_DEC_7q4m__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_DEC_7q4m__'
#!/bin/bash
# soc-wazuh da cai san Wazuh. Quyen cac user Wazuh duoc khoi phuc o /entrypoint.sh (PID 1, TRUOC systemd),
# nen o day KHONG chown gi (chown /var/lib luc dang chay se hong node.lock cua OpenSearch).
# systemd tu khoi dong indexer/manager/filebeat/dashboard luc boot. (Da bake anh chung -> khong goi wazuh-setup.)
exit 0
__EOF_DEC_7q4m__
cat > "$LAB/siem/_bin/prestop" <<'__EOF_DEC_7q4m__'
#!/bin/bash
# Cham PHA 2 (decoder + rule). 2 dac diem cua wazuh-logtest 4.14.9 da kiem chung:
#  - logtest IN RA STDERR -> phai gom 2>&1 va ghi FILE (khong bat qua pipe -> tranh segfault).
#  - logtest KHONG mo phong duoc rule tan suat + <same_source_ip/> -> brute-force cham bang:
#      (a) rule FAIL co ban no (logtest, level>=5) + (b) file rule co cau truc tuong quan.
#   DECODER_OK          : withdraw decode dung 5 truong (srcip, dstuser, act, res, amount)
#   HIGH_VALUE_DETECTED : withdraw no level >= 12
#   BRUTEFORCE_DETECTED : rule FAIL co ban no (>=5) VA file rule co frequency + same_source_ip + if_matched_sid
#   NO_FP_OK            : giao dich hop le (6-7 chu so) + FAIL le te KHONG no level >= 10
trap "echo Timed out; exit" SIGTERM
echo "PRESTOP_MARKER_SIEM"

LT="/var/ossec/bin/wazuh-logtest"
RULES="/var/ossec/etc/rules/local_rules.xml"

# logtest in ra STDERR -> gom 2>&1; ghi FILE (khong pipe) -> tranh segfault; retry cho ket noi analysisd.
run(){
  local tmp n=0; tmp=$(mktemp)
  while [ "$n" -lt 4 ]; do
    printf '%s\n' "$@" | sudo -n "$LT" >"$tmp" 2>&1
    grep -q "Phase 1" "$tmp" && { cat "$tmp"; rm -f "$tmp"; return 0; }
    n=$((n+1)); sleep 2
  done
  cat "$tmp"; rm -f "$tmp"
}
maxlvl(){ grep -oE "level: '[0-9]+'" | grep -oE '[0-9]+' | sort -n | tail -1; }

# Warm-up: cho analysisd san sang (tranh loi/segfault ngay sau restart manager).
for _ in 1 2 3 4 5 6 7 8; do printf 'warmup\n' | sudo -n "$LT" >/dev/null 2>&1 && break; sleep 2; done

HDR="Nov 15 14:30:22 target xpayd[2205]:"
WITHDRAW="$HDR TX#88392|SRC=172.20.0.5|USER=cfo_4821|ACT=WITHDRAW|RES=OK|AMT=85000000|NOTE=ext_wallet_drain"

# === DECODER + HIGH-VALUE: bom 1 dong rut tien lon ===
WOUT=$(run "$WITHDRAW")
if printf '%s' "$WOUT" | grep -qE "srcip: '172\.20\.0\.5'" \
   && printf '%s' "$WOUT" | grep -qE "dstuser: '[^']*cfo" \
   && printf '%s' "$WOUT" | grep -qE "act: 'WITHDRAW'" \
   && printf '%s' "$WOUT" | grep -qE "res: 'OK'" \
   && printf '%s' "$WOUT" | grep -qE "amount: '85000000'"; then
  echo "DECODER_OK"
fi
L=$(printf '%s' "$WOUT" | maxlvl); [ -n "$L" ] && [ "$L" -ge 12 ] && echo "HIGH_VALUE_DETECTED"
sleep 1

# === NO FALSE POSITIVE: giao dich hop le 6 chu so + bien 7 chu so (9.999.999) + 1 FAIL le te -> KHONG level >= 10 ===
FP=()
FP+=("Nov 15 10:00:00 target xpayd[2104]: TX#1002|SRC=172.20.0.30|USER=nv_hoa|ACT=TRANSFER|RES=OK|AMT=150000|NOTE=lunch_bill")
FP+=("Nov 15 10:00:05 target xpayd[2104]: TX#1004|SRC=172.20.0.33|USER=acct_bot|ACT=TRANSFER|RES=OK|AMT=9999999|NOTE=payroll")
FP+=("Nov 15 10:00:09 target xpayd[2104]: TX#1005|SRC=172.20.0.31|USER=nv_minh|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=typo")
FOUT=$(run "${FP[@]}")
if printf '%s' "$FOUT" | grep -q "Phase 1"; then
  L=$(printf '%s' "$FOUT" | maxlvl)
  { [ -z "$L" ] || [ "$L" -lt 10 ]; } && echo "NO_FP_OK"
fi
sleep 1

# === BRUTE-FORCE: (a) rule FAIL co ban no (logtest, dung field act/res) + (b) file rule co cau truc tuong quan ===
# (logtest khong mo phong duoc frequency + same_source_ip, nen xac nhan cau truc rule truc tiep tu file.)
FAIL1="Nov 15 14:30:11 target xpayd[2191]: TX#2042|SRC=172.20.0.5|USER=cfo_4821|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin"
BOUT=$(run "$FAIL1"); BL=$(printf '%s' "$BOUT" | maxlvl)
RF=$(sudo -n cat "$RULES" 2>/dev/null)
if [ -n "$BL" ] && [ "$BL" -ge 5 ] \
   && printf '%s' "$RF" | grep -q 'frequency=' \
   && printf '%s' "$RF" | grep -qi 'same_source_ip' \
   && printf '%s' "$RF" | grep -q 'if_matched_sid'; then
  echo "BRUTEFORCE_DETECTED"
fi

exit 0
__EOF_DEC_7q4m__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_DEC_7q4m__'
#!/bin/bash
# Chay LAN DAU tren target, quyen 'ubuntu'. $1 = mat khau sudo.
# Dung moi truong "Cong thanh toan xpayd": seed LOG SU CO dinh dang rieng + luong nhieu nen lanh tinh,
# wazuh-agent day /var/log/xpay/transactions.log ve siem. Token ACID (vi VIP cfo_<so>) va TXID (ma rut
# tien TX#<so>) ca nhan hoa qua RAND_REPLACE. Grading doc lai tu log de doi chieu findings.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }

# ===== 1) analyst cho DEFENDER SSH sang dieu tra =====
S useradd -m -s /bin/bash analyst 2>/dev/null
S bash -c 'echo "analyst:analyst" | chpasswd'
S usermod -aG sudo analyst 2>/dev/null

# ===== 2) Thu muc cau hinh xpay + danh sach tai khoan bi khoa (SV them cfo_<so> vao day o Pha 3) =====
S mkdir -p /etc/xpay
S bash -c 'cat > /etc/xpay/locked_accounts <<EOF
# Danh sach tai khoan bi khoa (moi dong 1 username). Them cfo_<so> vao day de khoa vi VIP bi chiem.
EOF'
S chmod 644 /etc/xpay/locked_accounts

# ===== 3) Log giao dich xpayd (Wazuh giam sat) - world-writable de luong nhieu nen ghi them =====
S mkdir -p /var/log/xpay

# --- Seed LOG SU CO (dinh dang rieng: TX#..|SRC=..|USER=..|ACT=..|RES=..|AMT=..|NOTE=..) ---
# Token cfo_ACID (vi VIP) + TX#TXID (ma rut tien) da duoc RAND_REPLACE thay bang so ngau nhien.
cat > /tmp/xpay_seed.log <<'LOG'
Nov 15 08:12:03 target xpayd[2104]: TX#1001|SRC=172.20.0.30|USER=nv_hoa|ACT=LOGIN|RES=OK|AMT=0|NOTE=web_portal
Nov 15 08:12:40 target xpayd[2104]: TX#1002|SRC=172.20.0.30|USER=nv_hoa|ACT=TRANSFER|RES=OK|AMT=150000|NOTE=lunch_bill
Nov 15 08:45:11 target xpayd[2104]: TX#1003|SRC=172.20.0.31|USER=nv_minh|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=typo_pin
Nov 15 08:45:19 target xpayd[2104]: TX#1004|SRC=172.20.0.31|USER=nv_minh|ACT=LOGIN|RES=OK|AMT=0|NOTE=web_portal
Nov 15 09:03:52 target xpayd[2104]: TX#1005|SRC=172.20.0.33|USER=acct_bot|ACT=TRANSFER|RES=OK|AMT=500000|NOTE=vendor_payout
Nov 15 09:30:07 target xpayd[2104]: TX#1006|SRC=172.20.0.30|USER=nv_hoa|ACT=TRANSFER|RES=OK|AMT=250000|NOTE=office_supply
Nov 15 14:30:10 target xpayd[2190]: TX#2041|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:11 target xpayd[2191]: TX#2042|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:13 target xpayd[2192]: TX#2043|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:14 target xpayd[2193]: TX#2044|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:16 target xpayd[2194]: TX#2045|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:17 target xpayd[2195]: TX#2046|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=FAIL|AMT=0|NOTE=bad_pin
Nov 15 14:30:18 target xpayd[2198]: TX#2047|SRC=172.20.0.5|USER=cfo_ACID|ACT=LOGIN|RES=OK|AMT=0|NOTE=session_granted
Nov 15 14:30:22 target xpayd[2205]: TX#TXID|SRC=172.20.0.5|USER=cfo_ACID|ACT=WITHDRAW|RES=OK|AMT=85000000|NOTE=ext_wallet_drain
LOG
S cp /tmp/xpay_seed.log /var/log/xpay/transactions.log
S chmod 666 /var/log/xpay/transactions.log
rm -f /tmp/xpay_seed.log

# ===== 4) LUONG NHIEU NEN LANH TINH - giao dich hop le lien tuc (LOGIN/TRANSFER so nho, KHONG WITHDRAW) =====
#   Dung de do bao gia: AMT luon 6 chu so (<10 trieu), khong co burst FAIL -> rule dung se KHONG dinh.
S bash -c 'cat > /usr/local/bin/xpay-noise.sh <<EOF
#!/bin/bash
LOG="/var/log/xpay/transactions.log"
U=(nv_hoa nv_minh acct_bot nv_lan nv_tuan)
SRCS=(172.20.0.30 172.20.0.31 172.20.0.32 172.20.0.33)
ACTS=(LOGIN TRANSFER)
while true; do
  u=\${U[\$RANDOM % \${#U[@]}]}
  s=\${SRCS[\$RANDOM % \${#SRCS[@]}]}
  a=\${ACTS[\$RANDOM % \${#ACTS[@]}]}
  if [ "\$a" = "LOGIN" ]; then amt=0; else amt=\$(( (RANDOM % 9 + 1) * 100000 )); fi
  tx=\$(( RANDOM % 8000 + 1000 ))
  echo "\$(date "+%b %d %H:%M:%S") target xpayd[2104]: TX#\${tx}|SRC=\${s}|USER=\${u}|ACT=\${a}|RES=OK|AMT=\${amt}|NOTE=auto" >> "\$LOG"
  sleep \$(( 12 + RANDOM % 10 ))
done
EOF'
S chmod +x /usr/local/bin/xpay-noise.sh
S bash -c 'cat > /etc/cron.d/xpay-noise <<EOF
* * * * * ubuntu pgrep -f xpay-noise.sh >/dev/null || nohup /bin/bash /usr/local/bin/xpay-noise.sh >/dev/null 2>&1 &
EOF'
S chmod 644 /etc/cron.d/xpay-noise

# ===== 5) Phieu dieu tra ~/findings.txt (5 cau - SV tu doc log de dien) =====
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA SU CO XPAY - dien gia tri TU TIM (KEY=value):
# LOG_PROGRAM  : ten chuong trinh (program_name) sinh ra dong log la
# ATTACKER_IP  : IP (SRC) brute-force va rut tien trai phep
# VICTIM_USER  : tai khoan vi VIP bi chiem doat (dang cfo_<so>)
# FRAUD_TX_ID  : ma giao dich cua lenh rut tien trai phep (dang TX#<so>)
# FRAUD_AMOUNT : so tien bi rut trai phep (chi so, VND)
LOG_PROGRAM=
ATTACKER_IP=
VICTIM_USER=
FRAUD_TX_ID=
FRAUD_AMOUNT=
FND
S cp /tmp/findings.txt /home/analyst/findings.txt
S chown analyst:analyst /home/analyst/findings.txt
S chmod 644 /home/analyst/findings.txt
rm -f /tmp/findings.txt

# ===== 6) Wazuh agent: giam sat /var/log/xpay/transactions.log (day ve manager de hien dashboard) =====
S bash -c 'grep -q "xpay/transactions.log" /var/ossec/etc/ossec.conf 2>/dev/null || cat >> /var/ossec/etc/ossec.conf <<EOF
<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/xpay/transactions.log</location>
  </localfile>
</ossec_config>
EOF'
S systemctl restart wazuh-agent 2>/dev/null || S service wazuh-agent restart 2>/dev/null || true

# ===== 7) Khoi dong cron + luong nhieu nen =====
S systemctl restart cron 2>/dev/null || S service cron restart 2>/dev/null || true
setsid /bin/bash /usr/local/bin/xpay-noise.sh >/dev/null 2>&1 < /dev/null &

exit 0
__EOF_DEC_7q4m__
cat > "$LAB/target/_bin/prestop" <<'__EOF_DEC_7q4m__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (cham diem).
# Chi in co/OK, KHONG lo dap an (so cfo_<so>, TX#<so>) de tranh SV chep tu prestop.stdout.
trap "echo Timed out; exit" SIGTERM
echo "PRESTOP_MARKER"

F=/home/analyst/findings.txt
LOG=/var/log/xpay/transactions.log

# --- UNG PHO 1: chan IP ke tan cong (.5) bang iptables (chan theo LUAT) ---
sudo -n iptables -S 2>/dev/null | grep -qE '172\.20\.0\.5(/32)?.*-j (DROP|REJECT)' && echo "ATTACKER_BLOCKED"

# --- SLA: ket noi toi SIEM (.20) con song (agent van day log, khong chan bua) ---
SL=$(ss -tn 2>/dev/null | grep -c '172.20.0.20:')
[ "${SL:-0}" -ge 1 ] && echo "SLA_OK"

# --- UNG PHO 2: khoa tai khoan VIP bi chiem (cfo_<so> co trong /etc/xpay/locked_accounts) ---
CFO=$(grep -oE 'cfo_[0-9]+' "$LOG" 2>/dev/null | head -1)
ACID=$(echo "$CFO" | tr -cd '0-9')
if [ -n "$CFO" ] && grep -qE "(^|[^0-9])${ACID}([^0-9]|$)" /etc/xpay/locked_accounts 2>/dev/null; then
  echo "ACCOUNT_LOCKED"
fi

# --- DIEU TRA: doi chieu 5 cau findings.txt voi SU THAT trong log ---
GTTX=$(grep 'ACT=WITHDRAW' "$LOG" 2>/dev/null | grep -oE 'TX#[0-9]+' | head -1 | tr -cd '0-9')
val(){ sed -n "s/^$1=//p" "$F" 2>/dev/null | head -1 | tr -d ' \r'; }

echo "$(val LOG_PROGRAM)" | grep -qiE '^xpayd$' && echo "REP_PROG_OK"
[ "$(val ATTACKER_IP)" = "172.20.0.5" ] && echo "REP_ATTACKER_OK"
[ -n "$ACID" ] && [ "$(val VICTIM_USER | tr -cd '0-9')" = "$ACID" ] && echo "REP_VICTIM_OK"
[ -n "$GTTX" ] && [ "$(val FRAUD_TX_ID | tr -cd '0-9')" = "$GTTX" ] && echo "REP_TXID_OK"
[ "$(val FRAUD_AMOUNT | tr -cd '0-9')" = "85000000" ] && echo "REP_AMOUNT_OK"

echo "=== findings (bao cao cua analyst) ==="
cat "$F" 2>/dev/null
exit 0
__EOF_DEC_7q4m__
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_DEC_7q4m__'
iptables
chmod
chown
tee
pkill
kill
rm
__EOF_DEC_7q4m__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/attacker/_bin/*.sh "$LAB"/target/_bin/* "$LAB"/siem/_bin/* "$LAB"/defender/_bin/*.sh 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-decoder"
