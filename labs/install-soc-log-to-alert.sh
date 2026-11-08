#!/bin/bash
# ============================================================================
# Trinh cai dat lab soc-log-to-alert (Bai 2 - Tu log -> alert) len VM Labtainers.
#   bash install-soc-log-to-alert.sh
# TU-CHUA (nhung toan bo file bang heredoc). Yeu cau: co $LABTAINER_DIR; da dung anh nen chung
# localhost:5000/soc-wazuh:latest. KHONG chay apply-shared-siem.sh len lab nay.
# (File nay SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then
  echo "LOI: chua co \$LABTAINER_DIR. Chay ./update-designer.sh roi mo terminal moi."
  exit 1
fi
LAB="$LABTAINER_DIR/labs/soc-log-to-alert"
echo ">> Tao lab tai: $LAB"
mkdir -p "$LAB/config" "$LAB/dockerfiles" "$LAB/docs" "$LAB/instr_config" "$LAB/siem/_bin" "$LAB/defender/_bin"

cat > "$LAB/config/start.config" <<'__LT_01__'
# start.config - Lab soc-log-to-alert (Bai 2 - Tu log -> alert)
# Muc tieu: mo xe cau truc 1 alert, hieu pipeline log tho -> decoder -> rule -> alert.
# Du lieu alert (co full_log that + decoder + rule.id/level) da nap san. SV doc & tra loi tai defender.
#
# 2 container (giong Bai 1):
#   siem     - Wazuh, SEED bang systemd (self-random). TERMINALS 0 (an, khong lo dap an).
#   defender - tram analyst: Firefox + terminal ghi bai lam (~/answers.txt). Noi cham diem.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-log-to-alert_student_master_seed
	GRADE_CONTAINER defender

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST defender:172.20.0.30
	TERMINALS 0

CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	X11 YES
	TERMINALS 1
__LT_01__

cat > "$LAB/config/parameter.config" <<'__LT_02__'
# parameter.config - Bai 2 KHONG dung RAND_REPLACE.
# siem chay anh nen chung soc-wazuh -> Labtainers boot-hook (parameterize/fixlocal) bi bo qua.
# Ca nhan hoa chong chep bai lam bang SEED TU RANDOM moi container (xem siem/seed-data.py).
# (De trong co chu dich - khong co directive.)
__LT_02__

cat > "$LAB/config/about.txt" <<'__LT_03__'
soc-log-to-alert - Bai 2 trong lo trinh "Dieu tra su co & Ky nghe phat hien tren SIEM".
Hieu pipeline: log tho -> pre-decoder -> decoder -> rule -> alert. Mo xe 1 alert trong Discover:
doc full_log, decoder.name, rule.id/level/description, data.*. Du lieu nap san, ca nhan hoa tung SV.
Muc tieu nang luc: A2+A3. Thoi luong ~75 phut. Buoc dem sang Detection Engineering.
__LT_03__

cat > "$LAB/docs/read_first.txt" <<'__LT_04__'
========================================================================
  BAI 2 - TU LOG -> ALERT: "Giai phau mot canh bao" (Cong ty X)
========================================================================

Bai 1 ban hoc TRUY VAN/DEM du lieu. Hom nay khac han: ban hoc DOC HIEU mot alert -
no duoc tao ra the nao, moi truong nghia la gi, luat nao da ban no. Nam cho nay ban moi
tin/triage dung va sau nay moi TU VIET duoc luat (Detection Engineering).

------------------------------------------------------------------------
PIPELINE CUA WAZUH (hoc ky - co cau hoi)
------------------------------------------------------------------------
  Log tho  ->  (1) PRE-DECODER  ->  (2) DECODER  ->  (3) RULE  ->  ALERT
  - (1) pre-decoder: tach thoi gian, hostname, ten chuong trinh.
  - (2) DECODER: "boc tach" cac truong trong NOI DUNG log (vd IP, user, ma HTTP...) -> nam o data.*
        ; decoder.name cho biet DECODER NAO da tach.
  - (3) RULE: so khop & GAN cho su kien: muc do rule.level, ten rule.description, ma rule.id, nhom rule.groups.
  => CUNG MOT DECODER co the dan toi NHIEU RULE khac nhau (vd sshd tach ca dang nhap that bai lan thanh cong,
     nhung moi loai bi mot RULE khac nhau bat -> rule.id khac nhau). DECODER != RULE.
  Thang muc do rule.level: 0 (thap nhat) -> 15 (cao nhat).

------------------------------------------------------------------------
0) MO DASHBOARD + CACH GIAI PHAU 1 ALERT
------------------------------------------------------------------------
  - Firefox tu mo https://172.20.0.20 ; dang nhap:  admin / Q*uJjovx2guqFRqntC568k?lf3evm.jl
  - Discover, index "wazuh-alerts-*", thoi gian = Yesterday.
  - Bam MUI TEN ">" dau mot dong de MO RONG -> doc: full_log (log tho), decoder.name,
    rule.id, rule.level, rule.description, data.srcip, data.srcuser, data.id ...
  - Banner "API offline" (wazuh-manager) -> BO QUA.

------------------------------------------------------------------------
1) TRA LOI 8 CAU (ghi SO vao ~/answers.txt tren defender)
------------------------------------------------------------------------
  C1. Mo alert NGHIEM TRONG NHAT (rule.level cao nhat) -> rule.id cua no la bao nhieu?
  C2. rule.level cua alert nghiem trong nhat do la may?
  C3. SSH that bai va SSH thanh cong CUNG decoder 'sshd' nhung KHAC luat.
      rule.id cua alert SSH THAT BAI la bao nhieu?
  C4. rule.id cua alert SSH THANH CONG la bao nhieu?
  C5. Mo mot alert WEB. Trong full_log (dong Apache tho) co ma HTTP (vd 404). Decoder tach ma HTTP do
      vao FIELD nao? Chon 1 so:   (1) data.srcip   (2) data.id   (3) rule.level   (4) decoder.name
  C6. rule.id cua mot alert WEB la bao nhieu?
  C7. Buoc GAN muc do (level) & ten luat cho su kien la buoc thu may? (pre-decoder=1, decoder=2, rule=3)
  C8. rule.level TOI DA cua thang diem Wazuh la bao nhieu?

  Ghi: nano ~/answers.txt ; vi du  C1=161279  C5=2  C7=3

------------------------------------------------------------------------
2) GOI Y 3 CAP
------------------------------------------------------------------------
 Cap 1: Mo rong (">") mot su kien de doc field. Muon tim "cai nghiem trong nhat" -> sap xep theo rule.level giam dan.
 Cap 2 (loc gi):
   - Nghiem trong nhat: Search rule.groups:attack  (hoac sort rule.level desc) -> doc rule.id (C1), rule.level (C2)
   - SSH that bai:  rule.groups:authentication_failed   -> doc rule.id (C3)
   - SSH thanh cong: rule.groups:authentication_success -> doc rule.id (C4)
   - Alert web:  decoder.name:web-accesslog             -> doc rule.id (C6) ; xem full_log vs field data.id (C5)
 Cap 3:
   - C1/C2: Search rule.groups:attack -> mo 1 dong -> rule.id (C1) va rule.level (C2).
   - C3: Search rule.groups:authentication_failed -> mo 1 dong -> rule.id.
   - C4: Search rule.groups:authentication_success -> mo 1 dong -> rule.id. (khac rule.id cua C3 du cung decoder sshd!)
   - C5: mo 1 alert web, so sanh so trong full_log ("... 404 512") voi cac field -> ma HTTP nam o data.id -> dap an 2.
   - C6: Search decoder.name:web-accesslog -> mo 1 dong -> rule.id.
   - C7: so do pipeline o tren -> rule la buoc 3.  C8: thang 0 -> 15.

------------------------------------------------------------------------
3) PHAN B - DUNG 2 BIEU DO (ten bat dau "bai2")
------------------------------------------------------------------------
  Visualize -> Create visualization -> index wazuh-alerts-*:
    - bai2-theo-decoder : Pie/Bar, Buckets Terms field decoder.name  (Update -> Save)
    - bai2-theo-level   : Bar, Buckets Terms field rule.level         (Update -> Save)
  (Bam nut "Update" o day panel moi ve; luu ten bat dau "bai2".)

------------------------------------------------------------------------
4) NOP BAI
------------------------------------------------------------------------
  checkwork  ; cac muc: q1..q8, bai2_partA (dung >=7/8), bai2_partB (>=2 bieu do bai2)
  Xong:  stoplab
__LT_04__

cat > "$LAB/instr_config/results.config" <<'__LT_05__'
# results.config - trich cau tra loi SV (defender) + dap an chuan (siem) + Phan B
# Ca 8 cau deu la SO NGUYEN (rule.id / level / so luong / so thu tu buoc).

# --- Cau tra loi cua sinh vien ---
_c1 = defender:prestop.stdout : GROUP : 1 : REGEX : C1\s*=\s*([0-9]+)
_c2 = defender:prestop.stdout : GROUP : 1 : REGEX : C2\s*=\s*([0-9]+)
_c3 = defender:prestop.stdout : GROUP : 1 : REGEX : C3\s*=\s*([0-9]+)
_c4 = defender:prestop.stdout : GROUP : 1 : REGEX : C4\s*=\s*([0-9]+)
_c5 = defender:prestop.stdout : GROUP : 1 : REGEX : C5\s*=\s*([0-9]+)
_c6 = defender:prestop.stdout : GROUP : 1 : REGEX : C6\s*=\s*([0-9]+)
_c7 = defender:prestop.stdout : GROUP : 1 : REGEX : C7\s*=\s*([0-9]+)
_c8 = defender:prestop.stdout : GROUP : 1 : REGEX : C8\s*=\s*([0-9]+)

# --- Dap an chuan (siem phat qua prestop) ---
_gt1 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C1=([0-9]+)
_gt2 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C2=([0-9]+)
_gt3 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C3=([0-9]+)
_gt4 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C4=([0-9]+)
_gt5 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C5=([0-9]+)
_gt6 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C6=([0-9]+)
_gt7 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C7=([0-9]+)
_gt8 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C8=([0-9]+)

# --- Phan B: >= 2 visualization/dashboard ten bat dau "bai2" ---
_partb = siem:prestop.stdout : FILE_REGEX : PARTB_PASS
__LT_05__

cat > "$LAB/instr_config/goals.config" <<'__LT_06__'
# goals.config - so khop cau tra loi SV (_cN) voi dap an chuan (_gtN) do seed tu random & ghi.

# --- Phan A: 8 cau ---
q1 = matchany : integer_equal : _c1 : result._gt1
q2 = matchany : integer_equal : _c2 : result._gt2
q3 = matchany : integer_equal : _c3 : result._gt3
q4 = matchany : integer_equal : _c4 : result._gt4
q5 = matchany : integer_equal : _c5 : result._gt5
q6 = matchany : integer_equal : _c6 : result._gt6
q7 = matchany : integer_equal : _c7 : result._gt7
q8 = matchany : integer_equal : _c8 : result._gt8

# Dat Phan A khi dung >= 7/8
bai2_partA = count_greater : 6 : (q1, q2, q3, q4, q5, q6, q7, q8)

# --- Phan B: da luu >= 2 visualization/dashboard ten "bai2" ---
bai2_partB = boolean : _partb
__LT_06__

cat > "$LAB/dockerfiles/Dockerfile.soc-log-to-alert.siem.student" <<'__LT_07__'
#
# siem - dung anh nen chung soc-wazuh. Boot-hook Labtainers (fixlocal/param) BI BO QUA tren anh chung,
# nen SEED duoc lam boi SYSTEMD unit 'seed-lta.service' (bake duoi day). seed-data.py self-random.
# LUU Y: KHONG chay apply-shared-siem.sh len lab nay.
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
RUN (command -v python3 >/dev/null 2>&1) || (apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*) || true
#
# Cho prestop doc marker/dap an + chay helper dem saved-object (can doc chung chi root)
RUN printf '%s\n' \
  'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /root/.lta_seeded, /usr/bin/cat /root/.lta_seeded, /bin/cat /root/.lta_answers, /usr/bin/cat /root/.lta_answers, /usr/bin/python3 /home/ubuntu/savedobj-count.py' \
  > /etc/sudoers.d/labtainer-lta && chmod 440 /etc/sudoers.d/labtainer-lta
#
# === SEED bang SYSTEMD ===
RUN printf '%s\n' \
  '[Unit]' \
  'Description=Seed log-to-alert data into Wazuh indexer' \
  'After=wazuh-indexer.service network-online.target' \
  'Wants=wazuh-indexer.service' \
  '[Service]' \
  'Type=oneshot' \
  'RemainAfterExit=yes' \
  'ExecStart=/usr/bin/python3 /home/ubuntu/seed-data.py' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > /etc/systemd/system/seed-lta.service \
 && mkdir -p /etc/systemd/system/multi-user.target.wants \
 && ln -sf /etc/systemd/system/seed-lta.service /etc/systemd/system/multi-user.target.wants/seed-lta.service
#
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Entrypoint: khoi phuc quyen cac user Wazuh truoc systemd
RUN printf '%s\n' \
  '#!/bin/bash' \
  'for u in wazuh-indexer wazuh-dashboard; do' \
  '  id "$u" >/dev/null 2>&1 || continue' \
  '  chown -R "$u:$u" /usr/share/$u /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
  'done' \
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
RUN mkdir -p /home/$user_name/.local && echo "soc-log-to-alert" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__LT_07__

cat > "$LAB/dockerfiles/Dockerfile.soc-log-to-alert.defender.student" <<'__LT_08__'
#
# Labtainer Dockerfile - defender (tram analyst, Firefox xem dashboard Wazuh)
#
ARG registry
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
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
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
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__LT_08__

cat > "$LAB/siem/_bin/fixlocal.sh" <<'__LT_09__'
#!/bin/bash
# siem (anh nen chung soc-wazuh). Boot-hook Labtainers bi bo qua tren anh chung -> viec SEED do
# SYSTEMD unit 'seed-lta.service' (bake trong Dockerfile) lam, KHONG dua vao fixlocal nay.
exit 0
__LT_09__

cat > "$LAB/siem/_bin/prestop" <<'__LT_10__'
#!/bin/bash
# Chay luc checkwork/stoplab tren siem. Phat DAP AN chuan (do seed ghi) + trang thai Phan B.
# SV khong xem duoc prestop.stdout, siem an (TERMINALS 0) -> khong lo dap an.
trap "echo Timed out; exit" SIGTERM

echo "SIEM_PRESTOP_MARKER"

echo "=== seed status ==="
sudo -n cat /root/.lta_seeded 2>/dev/null || echo "NOT_SEEDED"

echo "=== ground truth (dap an chuan) ==="
sudo -n cat /root/.lta_answers 2>/dev/null || echo "NO_ANSWERS"

echo "=== saved objects (title bat dau bang bai2) ==="
sudo -n python3 /home/ubuntu/savedobj-count.py 2>/dev/null || echo "SAVEDOBJ_COUNT=0"
__LT_10__

cat > "$LAB/siem/seed-data.py" <<'__LT_11__'
#!/usr/bin/env python3
# ============================================================================
# seed-data.py  (Bai 2 - Tu log -> alert)  -- chay BOI SYSTEMD tren siem luc boot.
# Nap alert co day du giai phau (full_log that + decoder.name + rule.id/level/groups) de nguoi hoc
# MO XE 1 alert va hieu pipeline: log tho -> pre-decoder -> decoder -> rule -> alert.
# Self-random moi container -> moi sinh vien du lieu khac nhau (chong chep bai), KHONG can parameter.config.
# Ghi DAP AN chuan vao /root/.lta_answers; siem:prestop phat ra cho grader so khop.
#
# 8 dap an (huong "giai phau & noi ghep alert"):
#   C1 = rule.id cua alert NGHIEM TRONG NHAT (level cao nhat = nhom attack) = RULE_ATTACK
#   C2 = rule.level cua alert do                                            = LEVEL_ATTACK
#   C3 = rule.id SSH THAT BAI (cung decoder sshd, khac luat voi thanh cong) = RULE_SSHFAIL
#   C4 = rule.id SSH THANH CONG                                             = RULE_SSHOK
#   C5 = ma HTTP trong full_log web tach vao field nao (trac nghiem 1-4)    = 2 (data.id)
#   C6 = rule.id cua alert web                                              = RULE_WEB
#   C7 = buoc gan level & ten luat la thu may (pre-decoder=1,decoder=2,rule=3) = 3 [khai niem]
#   C8 = rule.level toi da cua Wazuh                                        = 15 [khai niem]
# ============================================================================
import json, os, random, subprocess, sys, time
from datetime import datetime, timedelta

MARKER  = "/root/.lta_seeded"
ANSWERS = "/root/.lta_answers"
CERTS   = "/etc/wazuh-indexer/certs"
HOST    = "https://localhost:9200"

if os.path.exists(MARKER):
    sys.exit(0)

os.system("systemctl start wazuh-manager >/dev/null 2>&1 &")
random.seed(int.from_bytes(os.urandom(8), "big"))

FAILCOUNT = random.randint(120, 350)
SUCCESS   = random.randint(5, 9)
C404 = random.randint(25, 95); C403 = random.randint(12, 70); C200 = random.randint(150, 260)
ATTACK = random.randint(3, 14)
LEVEL_ATTACK = random.randint(10, 14)   # < 15 de khac C8 (thang toi da 15)

# 4 rule.id phan biet nhau (tranh nhap nhang giua cac cau)
rids = set()
while len(rids) < 4:
    rids.add(random.randint(100000, 199999))
RULE_SSHFAIL, RULE_SSHOK, RULE_WEB, RULE_ATTACK = sorted(rids)

yesterday = (datetime.now() - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
INDEX = "wazuh-alerts-4.x-" + yesterday.strftime("%Y.%m.%d")
MON = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][yesterday.month - 1]

_uid = [0]
def ts(hour):
    t = yesterday.replace(hour=hour, minute=random.randint(0, 59), second=random.randint(0, 59))
    return t, t.strftime("%Y-%m-%dT%H:%M:%S.000+0700")

docs = []
def add(level, desc, groups, decoder, rid, agent, full_log, data=None):
    _uid[0] += 1
    t, iso = ts(random.randint(0, 23))
    doc = {
        "timestamp": iso,
        "rule": {"level": level, "description": desc, "groups": groups, "id": str(rid), "firedtimes": 1, "mail": False},
        "agent": {"id": "00%d" % agent[0], "name": agent[1]},
        "manager": {"name": "siem"}, "id": "%d.%d" % (int(time.time()), _uid[0]),
        "decoder": {"name": decoder}, "location": agent[2],
        "predecoder": {"timestamp": "%s %02d %02d:%02d:%02d" % (MON, yesterday.day, t.hour, t.minute, t.second),
                       "hostname": agent[1], "program_name": decoder},
        "full_log": full_log,
    }
    if data:
        doc["data"] = data
    docs.append(doc)

APP = (1, "app-01", "/var/log/auth.log")
WEB = (2, "web-01", "/var/log/apache2/access.log")

# SSH that bai (decoder sshd, rule.id RULE_SSHFAIL)
for _ in range(FAILCOUNT):
    u = "user%d" % random.randint(11, 89); ip = "203.0.113.%d" % random.randint(2, 254)
    fl = "%s %02d %02d:%02d:%02d app-01 sshd[%d]: Failed password for %s from %s port %d ssh2" % (
        MON, yesterday.day, random.randint(0,23), random.randint(0,59), random.randint(0,59),
        random.randint(1000,9999), u, ip, random.randint(1025,65000))
    add(5, "sshd: authentication failed", ["authentication_failed", "syslog", "sshd"], "sshd", RULE_SSHFAIL, APP,
        fl, data={"srcip": ip, "srcuser": u})

# SSH thanh cong (decoder sshd, rule.id RULE_SSHOK)
for _ in range(SUCCESS):
    ip = "172.20.0.%d" % random.randint(31, 59)
    fl = "%s %02d %02d:%02d:%02d app-01 sshd[%d]: Accepted password for admin from %s port 22 ssh2" % (
        MON, yesterday.day, random.randint(0,23), random.randint(0,59), random.randint(0,59),
        random.randint(1000,9999), ip)
    add(3, "sshd: Accepted password", ["authentication_success", "syslog", "sshd"], "sshd", RULE_SSHOK, APP,
        fl, data={"srcip": ip, "srcuser": "admin"})

# Web (decoder web-accesslog, rule.id RULE_WEB)
web_status = (["404"] * C404) + (["403"] * C403) + (["200"] * C200)
random.shuffle(web_status)
for st in web_status:
    ip = "203.0.113.%d" % random.randint(2, 254); url = random.choice(["/", "/index.php", "/admin", "/login"])
    fl = '%s - - [%02d/%s/%d:%02d:%02d:%02d +0700] "GET %s HTTP/1.1" %s %d' % (
        ip, yesterday.day, MON, yesterday.year, random.randint(0,23), random.randint(0,59), random.randint(0,59),
        url, st, random.randint(120, 4096))
    add(5 if st in ("404", "403") else 3, "apache: HTTP request %s" % st, ["web", "accesslog"], "web-accesslog",
        RULE_WEB, WEB, fl, data={"srcip": ip, "id": st, "url": url, "protocol": "GET"})

# Attack/correlation (decoder correlation, rule.id RULE_ATTACK, level cao nhat)
for _ in range(ATTACK):
    ip = "203.0.113.%d" % random.randint(2, 254)
    add(LEVEL_ATTACK, "Multiple correlated events - possible attack", ["ids", "attack"], "correlation",
        RULE_ATTACK, APP, "ids: correlated alert from %s" % ip, data={"srcip": ip})

# --- Nap vao indexer ---
def curl(args, data=None):
    base = ["curl", "-s", "-k", "--cert", CERTS + "/admin.pem", "--key", CERTS + "/admin-key.pem"]
    if os.path.exists(CERTS + "/root-ca.pem"):
        base += ["--cacert", CERTS + "/root-ca.pem"]
    return subprocess.run(base + args, input=data, capture_output=True, text=True).stdout

for _ in range(80):
    if '"status"' in curl([HOST + "/_cluster/health"]):
        break
    time.sleep(5)

curl([HOST + "/_plugins/_security/api/internalusers/analyst", "-X", "PUT",
      "-H", "Content-Type: application/json", "--data-binary", "@-"],
     data=json.dumps({"password": "analyst", "backend_roles": ["admin"], "description": "SOC analyst (lab)"}))

lines = []
for d in docs:
    lines.append('{"index":{"_index":"%s"}}' % INDEX)
    lines.append(json.dumps(d))
for i in range(0, len(lines), 1000):
    curl([HOST + "/_bulk", "-H", "Content-Type: application/x-ndjson", "--data-binary", "@-"],
         data="\n".join(lines[i:i + 1000]) + "\n")
curl([HOST + "/" + INDEX + "/_refresh", "-X", "POST"])

# Dap an (huong "giai phau & noi ghep alert"):
#  C1 = rule.id cua alert nghiem trong nhat (level cao nhat = nhom attack) = RULE_ATTACK
#  C2 = rule.level cua alert do                                            = LEVEL_ATTACK
#  C3 = rule.id SSH THAT BAI  (cung decoder sshd voi thanh cong, khac luat)= RULE_SSHFAIL
#  C4 = rule.id SSH THANH CONG                                             = RULE_SSHOK
#  C5 = ma HTTP trong full_log web duoc decoder tach vao field nao (trac nghiem)
#       (1) data.srcip (2) data.id (3) rule.level (4) decoder.name  -> dap an 2
#  C6 = rule.id cua alert web                                              = RULE_WEB
#  C7 = buoc gan level & ten luat (pre-decoder=1, decoder=2, rule=3)       = 3
#  C8 = rule.level toi da cua Wazuh                                        = 15
with open(ANSWERS, "w") as f:
    f.write("GT_C1=%d\nGT_C2=%d\nGT_C3=%d\nGT_C4=%d\nGT_C5=2\nGT_C6=%d\nGT_C7=3\nGT_C8=15\n"
            % (RULE_ATTACK, LEVEL_ATTACK, RULE_SSHFAIL, RULE_SSHOK, RULE_WEB))
with open(MARKER, "w") as f:
    f.write("%d docs @ %s\n" % (len(docs), INDEX))
sys.exit(0)
__LT_11__

cat > "$LAB/siem/savedobj-count.py" <<'__LT_12__'
#!/usr/bin/env python3
# Chay boi root (qua sudo tu prestop). Dem so visualization/dashboard SV da luu voi TIEU DE
# bat dau bang "bai2" -> cham Phan B. Dung chung chi admin; dem truc tiep tren index cau hinh dashboard.
import json, os, subprocess

CERTS = "/etc/wazuh-indexer/certs"
HOST  = "https://localhost:9200"
QUERY = {"query": {"bool": {"minimum_should_match": 1, "should": [
    {"wildcard": {"visualization.title": "bai2*"}},
    {"wildcard": {"dashboard.title": "bai2*"}},
]}}}

def curl(path, body):
    base = ["curl", "-s", "-k", "--cert", CERTS + "/admin.pem", "--key", CERTS + "/admin-key.pem"]
    if os.path.exists(CERTS + "/root-ca.pem"):
        base += ["--cacert", CERTS + "/root-ca.pem"]
    p = subprocess.run(base + [HOST + path, "-H", "Content-Type: application/json",
                               "--data-binary", "@-"], input=body, capture_output=True, text=True)
    return p.stdout

total = 0
for idx in (".kibana", ".opensearch_dashboards"):
    out = curl("/" + idx + "/_count", json.dumps(QUERY))
    try:
        total = max(total, int(json.loads(out).get("count", 0)))
    except Exception:
        pass
print("SAVEDOBJ_COUNT=%d" % total)
# Bai 2: Phan B nhe -> can >= 2 visualization/dashboard ten bat dau "bai2"
if total >= 2:
    print("PARTB_PASS")
__LT_12__

cat > "$LAB/defender/_bin/fixlocal.sh" <<'__LT_13__'
#!/bin/bash
# Defender (tram analyst). Tao san file bai lam mau cho sinh vien dien dap an.
# Khong dung vao /tmp/.X11-unix (Labtainers tu lo symlink; student_startup se bao dam).
if [ ! -f /home/ubuntu/answers.txt ]; then
cat > /home/ubuntu/answers.txt <<'TXT'
# ===== BAI LAM - Bai 2: Tu log -> alert =====
# Dien dap an ngay sau dau '=' (giu nguyen dinh dang C1= ...). Chi 1 gia tri (so) moi dong.
# Luu file lai sau khi dien, roi chay 'checkwork'.
C1=
C2=
C3=
C4=
C5=
C6=
C7=
C8=
TXT
chown ubuntu:ubuntu /home/ubuntu/answers.txt 2>/dev/null || true
chmod 644 /home/ubuntu/answers.txt 2>/dev/null || true
fi
exit 0
__LT_13__

cat > "$LAB/defender/_bin/prestop" <<'__LT_14__'
#!/bin/bash
# Chay luc checkwork/stoplab tren defender. Chup bai lam cua sinh vien de cham.
trap "echo Timed out; exit" SIGTERM
echo "DEFENDER_PRESTOP_MARKER"
echo "=== answers ==="
cat /home/ubuntu/answers.txt 2>/dev/null
__LT_14__

cat > "$LAB/defender/_bin/student_startup.sh" <<'__LT_15__'
#!/bin/bash
# Mo Wazuh dashboard trong Firefox tren tram defender.
# LUU Y: file nay duoc SOURCE vao shell dang nhap -> TUYET DOI khong goi 'exit' (tat terminal)
# va khong chay vong lap/sleep o foreground (treo terminal). Toan bo bon vao MOT SUBSHELL NEN ( ) &.
#
# CHONG LOI "firefox khong len / cannot open display": tu bao dam symlink socket X bang cach tao MOT
# FILE symlink /tmp/.X11-unix/X<n> -> /var/tmp/.X11-unix/X<n> (TUYET DOI khong bien ca thu muc
# /tmp/.X11-unix thanh symlink -> tranh loi doX11Link "same file").
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
__LT_15__

rm -rf "$LAB/attacker" "$LAB/target" 2>/dev/null || true

chmod +x "$LAB/siem/_bin/fixlocal.sh"
chmod +x "$LAB/siem/_bin/prestop"
chmod +x "$LAB/siem/seed-data.py"
chmod +x "$LAB/siem/savedobj-count.py"
chmod +x "$LAB/defender/_bin/fixlocal.sh"
chmod +x "$LAB/defender/_bin/prestop"
chmod +x "$LAB/defender/_bin/student_startup.sh"

echo ""
echo ">> XONG! Lab san sang tai: $LAB"
echo ">> Kiem anh nen:  docker images | grep soc-wazuh"
echo ">> Build & chay:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-log-to-alert && labtainer soc-log-to-alert"
echo ">> Kiem seed:     docker exec \$(docker ps -q -f name=soc-log-to-alert.siem) cat /root/.lta_seeded"
