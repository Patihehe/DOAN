#!/bin/bash
# ============================================================================
# Trinh cai dat lab soc-onboarding (Bai 1 - Lam quen Wazuh) len VM Labtainers.
#   bash install-soc-onboarding.sh
# TU-CHUA: nhung toan bo file bang heredoc (chep 1 file nay len VM la chay duoc).
# Yeu cau: co $LABTAINER_DIR ; da dung anh nen chung localhost:5000/soc-wazuh:latest.
# KHONG chay apply-shared-siem.sh len lab nay (se ghi de fixlocal -> mat buoc seed).
# (File nay SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then
  echo "LOI: chua co \$LABTAINER_DIR. Chay ./update-designer.sh roi mo terminal moi."
  exit 1
fi
LAB="$LABTAINER_DIR/labs/soc-onboarding"
echo ">> Tao lab tai: $LAB"
mkdir -p "$LAB/config" "$LAB/dockerfiles" "$LAB/docs" "$LAB/instr_config" "$LAB/siem/_bin" "$LAB/defender/_bin"

cat > "$LAB/config/start.config" <<'__OB_01__'
# start.config - Lab soc-onboarding (Bai 1 - Lam quen Wazuh)
# Muc tieu: lam quen "doi mat" cua SOC. Khong co tan cong truc tiep.
# Du lieu log cua "hom qua" da duoc NAP SAN vao Wazuh (seed vao index).
# Sinh vien ngoi o defender (Firefox xem dashboard), truy van tra loi 8 cau + dung 3 bieu do.
#
# 2 container:
#   siem     - Wazuh (indexer+manager+dashboard), chay tren anh nen chung soc-wazuh.
#              fixlocal tu nap du lieu seed ca nhan hoa vao index. TERMINALS 0 (an) de
#              sinh vien KHONG mo duoc shell tren siem -> khong xem duoc script seed/dap an.
#   defender - tram analyst: Firefox + terminal ghi bai lam (~/answers.txt). Noi cham diem.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-onboarding_student_master_seed
	GRADE_CONTAINER defender

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- SIEM: Wazuh, nap du lieu seed. An (khong terminal) de khong lo dap an ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST defender:172.20.0.30
	TERMINALS 0

# --- DEFENDER: tram analyst, Firefox xem dashboard Wazuh, ghi bai lam ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	X11 YES
	TERMINALS 1
__OB_01__

cat > "$LAB/config/parameter.config" <<'__OB_02__'
# parameter.config - Bai 1 KHONG dung RAND_REPLACE.
# Ly do: siem chay anh nen chung soc-wazuh -> Labtainers boot-hook (parameterize/fixlocal) bi bo qua
# (anh mang san "dau da parameterize" tu luc docker commit). Nen ca nhan hoa chong chep bai duoc lam
# bang cach SEED TU RANDOM moi lan khoi tao container (xem siem/seed-data.py) -> moi SV du lieu khac nhau.
# (De trong co chu dich - khong co directive.)
__OB_02__

cat > "$LAB/config/about.txt" <<'__OB_03__'
soc-onboarding - Bai 1 trong lo trinh "Dieu tra su co & Ky nghe phat hien tren SIEM".
Lam quen dashboard Wazuh: truy van, loc, doc field, dung bieu do. Du lieu log "hom qua"
cua Cong ty X duoc nap san, ca nhan hoa tung sinh vien. Khong co tan cong truc tiep.
Muc tieu nang luc: A1 (su dung SIEM). Thoi luong ~60 phut.
__OB_03__

cat > "$LAB/docs/read_first.txt" <<'__OB_04__'
========================================================================
  BAI 1 - LAM QUEN WAZUH: "Ngay dau di truc" (Cong ty X)
========================================================================

Chao mung den SOC cua Cong ty X! Hom nay la ngay dau ban truc. Chua co dieu tra
gi gap - viec cua ban la LAM QUEN "doi mat" cua SOC: dashboard Wazuh. Toan bo log
cua HOM QUA da nam san trong he thong. Hay hoc cach TIM CAU TRA LOI trong do.

(Khong co tan cong dang chay. Day la bai luyen truy van - doc du lieu.)

------------------------------------------------------------------------
0) MO DASHBOARD (tren tram DEFENDER)
------------------------------------------------------------------------
  - Firefox tu mo trang:  https://172.20.0.20
    (Lan dau bao chung chi: Advanced -> Accept the Risk / Add Exception)
  - Dang nhap:   analyst / analyst
  - Vao muc "Discover" (hoac Threat Hunting -> Events). Chon index pattern
    "wazuh-alerts-*" neu duoc hoi.
  - DAT KHOANG THOI GIAN (goc tren ben phai) = "Yesterday" (hoac Last 24 hours)
    thi moi thay du lieu hom qua.

  * LUU Y: siem can ~1-2 phut sau khi len de nap xong du lieu. Neu Discover trong,
    doi chut roi bam Refresh.
  * Neu dashboard bao "API connection ... offline" (wazuh-manager) -> BO QUA. Bai nay chi
    dung Discover (doc tu indexer), khong can wazuh-manager.

------------------------------------------------------------------------
1) TRA LOI 8 CAU (ghi vao file ~/answers.txt tren DEFENDER)
------------------------------------------------------------------------
  C1. Hom qua co BAO NHIEU lan dang nhap SSH THAT BAI?
  C2. User nao bi thu dang nhap sai NHIEU NHAT? (ten dang user<so> -> ghi ca "user<so>")
  C3. IP web nao gui NHIEU request nhat? (dang 203.0.113.X -> ghi ca IP day du)
  C4. Co bao nhieu request tra ma HTTP 404?
  C5. KHUNG GIO nao (0-23) co nhieu su kien nhat?
  C6. Co bao nhieu request tra ma HTTP 403?
  C7. Co bao nhieu alert muc do cao (rule.level >= 10)?
  C8. IP cua lan dang nhap SSH THANH CONG DAU TIEN trong ngay? (dang 172.20.0.X -> ghi ca IP)

  Cach ghi: mo terminal defender, sua file mau:   nano ~/answers.txt
  Dien ngay sau dau '=' , vi du:  C1=237   C2=user45   C3=203.0.113.88

------------------------------------------------------------------------
2) GOI Y 3 CAP (tu doc neu bi, cap 3 gan nhu chi tan noi)
------------------------------------------------------------------------
 Cap 1 (nhe):
   - Dung o Discover: go tu khoa vao o Search, hoac bam vao mot field ben trai
     roi xem "Top values" / "Visualize".
   - So luong ket qua hien o goc (vd "1,234 hits") = so dem cho cac cau "bao nhieu".
 Cap 2 (field nao):
   - SSH that bai: loc rule.groups: authentication_failed
   - SSH thanh cong: loc rule.groups: authentication_success  (sap xep theo thoi gian TANG dan de thay cai DAU TIEN)
   - Request web + ma HTTP: field data.id (gia tri "404" / "403" / "200")
   - IP nguon: field data.srcip ;  user: field data.srcuser ;  muc do: field rule.level
   - Khung gio: xem bieu do cot theo thoi gian (histogram) o dau trang Discover.
 Cap 3 (gan nhu loi giai):
   - C1: Search  rule.groups:authentication_failed   -> doc so hits.
   - C2: loc nhu C1 -> bam field data.srcuser -> Top values (gia tri dau bang).
   - C3: loc  data.id:*  (hoac rule.groups:web) -> bam data.srcip -> Top values.
   - C4/C6: Search  data.id:404   /   data.id:403   -> doc so hits.
   - C5: nhin histogram, di chuot vao cot cao nhat -> xem gio.
   - C7: Search  rule.level >= 10   -> doc so hits.
   - C8: rule.groups:authentication_success, sap xep Time tang dan -> dong tren cung -> data.srcip.

------------------------------------------------------------------------
3) PHAN B - DUNG DASHBOARD 3 BIEU DO
------------------------------------------------------------------------
  Tao 3 visualization va LUU LAI, TEN bat dau bang "bai1", vi du:
    - bai1-top-ip      (bar: Top data.srcip)
    - bai1-http-status (pie: ty le data.id)
    - bai1-theo-gio    (line: so su kien theo thoi gian)
  (Vao Visualize -> Create -> chon kieu -> chon field -> Save voi ten "bai1...").

------------------------------------------------------------------------
4) NOP BAI
------------------------------------------------------------------------
  - Tren terminal defender:  checkwork   (tu kiem tra - khong lo dap an)
  - Cac muc cham:
       q1..q8      = tung cau dung/sai
       bai1_partA  = Y khi dung >= 7/8 cau
       bai1_partB  = Y khi da luu >= 3 bieu do ten "bai1"
  - Xong xuoi:  stoplab   (nop bai)

Chuc ca truc dau tien hanh thong!
__OB_04__

cat > "$LAB/instr_config/results.config" <<'__OB_05__'
# results.config - trich cau tra loi SV (defender) + dap an chuan (siem) + Phan B
# C1,C4,C5,C6,C7 = so nguyen.  C2 = id trong user<id>.  C3,C8 = octet cuoi IP.
# Doc tu prestop.stdout (luon duoc thu thap + co timestamp).

# --- Cau tra loi cua sinh vien (tram defender) ---
_c1 = defender:prestop.stdout : GROUP : 1 : REGEX : C1\s*=\s*([0-9]+)
_c2 = defender:prestop.stdout : GROUP : 1 : REGEX : C2\s*=\s*user([0-9]+)
_c3 = defender:prestop.stdout : GROUP : 1 : REGEX : C3\s*=\s*203\.0\.113\.([0-9]+)
_c4 = defender:prestop.stdout : GROUP : 1 : REGEX : C4\s*=\s*([0-9]+)
_c5 = defender:prestop.stdout : GROUP : 1 : REGEX : C5\s*=\s*([0-9]+)
_c6 = defender:prestop.stdout : GROUP : 1 : REGEX : C6\s*=\s*([0-9]+)
_c7 = defender:prestop.stdout : GROUP : 1 : REGEX : C7\s*=\s*([0-9]+)
_c8 = defender:prestop.stdout : GROUP : 1 : REGEX : C8\s*=\s*172\.20\.0\.([0-9]+)

# --- Dap an chuan do seed ghi (siem phat ra qua prestop) ---
_gt1 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C1=([0-9]+)
_gt2 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C2=([0-9]+)
_gt3 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C3=([0-9]+)
_gt4 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C4=([0-9]+)
_gt5 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C5=([0-9]+)
_gt6 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C6=([0-9]+)
_gt7 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C7=([0-9]+)
_gt8 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C8=([0-9]+)

# --- Phan B: >= 3 visualization/dashboard ten bat dau "bai1" (helper in PARTB_PASS) ---
_partb = siem:prestop.stdout : FILE_REGEX : PARTB_PASS
__OB_05__

cat > "$LAB/instr_config/goals.config" <<'__OB_06__'
# goals.config - so khop cau tra loi SV (_cN) voi dap an chuan (_gtN) do seed tu random & ghi.
# Dap an KHONG co san tren may hoc vien; grader lay tu siem:prestop.

# --- Phan A: 8 cau hoi ---
q1 = matchany : integer_equal : _c1 : result._gt1
q2 = matchany : integer_equal : _c2 : result._gt2
q3 = matchany : integer_equal : _c3 : result._gt3
q4 = matchany : integer_equal : _c4 : result._gt4
q5 = matchany : integer_equal : _c5 : result._gt5
q6 = matchany : integer_equal : _c6 : result._gt6
q7 = matchany : integer_equal : _c7 : result._gt7
q8 = matchany : integer_equal : _c8 : result._gt8

# Dat Phan A khi dung >= 7/8 (count_greater: so goal TRUE > 6)
bai1_partA = count_greater : 6 : (q1, q2, q3, q4, q5, q6, q7, q8)

# --- Phan B: da luu >= 3 visualization/dashboard ten "bai1" ---
bai1_partB = boolean : _partb
__OB_06__

cat > "$LAB/dockerfiles/Dockerfile.soc-onboarding.siem.student" <<'__OB_07__'
#
# siem - dung anh nen chung soc-wazuh (Wazuh cai san). Entrypoint khoi phuc quyen Wazuh truoc init.
# Bai 1 (soc-onboarding): du lieu log duoc NAP qua _bin/fixlocal.sh -> seed-data.py (sau khi init len).
# LUU Y: KHONG chay apply-shared-siem.sh len lab nay (no se ghi de fixlocal -> mat buoc seed).
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
# Bao dam co python3 (de chay seed + helper dem saved-object)
RUN (command -v python3 >/dev/null 2>&1) || (apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*) || true
#
# Cho prestop doc marker/dap an + chay helper dem saved-object (can doc chung chi root)
RUN printf '%s\n' \
  'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /root/.onboarding_seeded, /usr/bin/cat /root/.onboarding_seeded, /bin/cat /root/.onboarding_answers, /usr/bin/cat /root/.onboarding_answers, /usr/bin/python3 /home/ubuntu/savedobj-count.py' \
  > /etc/sudoers.d/labtainer-onboarding && chmod 440 /etc/sudoers.d/labtainer-onboarding
#
# === SEED bang SYSTEMD (vi boot-hook cua Labtainers bi bo qua tren anh nen chung) ===
# Unit chay /home/ubuntu/seed-data.py (do lab tar dua vao) sau khi indexer len. Enable bang
# symlink (systemctl enable khong chay duoc luc build). seed-data.py tu random + tu ghi dap an.
RUN printf '%s\n' \
  '[Unit]' \
  'Description=Seed onboarding data into Wazuh indexer' \
  'After=wazuh-indexer.service network-online.target' \
  'Wants=wazuh-indexer.service' \
  '[Service]' \
  'Type=oneshot' \
  'RemainAfterExit=yes' \
  'ExecStart=/usr/bin/python3 /home/ubuntu/seed-data.py' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > /etc/systemd/system/seed-onboarding.service \
 && mkdir -p /etc/systemd/system/multi-user.target.wants \
 && ln -sf /etc/systemd/system/seed-onboarding.service /etc/systemd/system/multi-user.target.wants/seed-onboarding.service
#
# Dong bo mui gio voi VM (ICT = UTC+7)
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Entrypoint: khoi phuc quyen cac user Wazuh (bi reset ve root khi layer anh chung), chay TRUOC systemd.
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
# Ghi DUNG ten lab cho siem (tranh lech firstlevelzip -> loi grader). Literal, khong dung ${lab%%.*}.
RUN mkdir -p /home/$user_name/.local && echo "soc-onboarding" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__OB_07__

cat > "$LAB/dockerfiles/Dockerfile.soc-onboarding.defender.student" <<'__OB_08__'
#
# Labtainer Dockerfile - defender (tram analyst, Firefox xem dashboard Wazuh)
#
ARG registry
# firefox3 = Firefox moi (chay duoc dashboard Wazuh hien dai)
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
# Dong bo mui gio voi VM (ICT = UTC+7)
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
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
__OB_08__

cat > "$LAB/siem/_bin/fixlocal.sh" <<'__OB_09__'
#!/bin/bash
# siem (anh nen chung soc-wazuh). LUU Y: tren anh nen chung, Labtainers boot-hook (fixlocal/param)
# BI BO QUA (anh mang san "dau da parameterize"). Vi vay viec SEED duoc lam boi SYSTEMD UNIT
# 'seed-onboarding.service' (bake trong Dockerfile), KHONG dua vao fixlocal nay.
# Giu fixlocal toi thieu (neu Labtainers co chay thi cung vo hai).
exit 0
__OB_09__

cat > "$LAB/siem/_bin/prestop" <<'__OB_10__'
#!/bin/bash
# Chay luc checkwork/stoplab tren siem (prestop van chay binh thuong voi anh nen chung).
# Phat DAP AN chuan (do seed ghi) cho grader so khop, va trang thai Phan B.
# SV khong xem duoc prestop.stdout, va siem an (TERMINALS 0) nen khong lo dap an.
trap "echo Timed out; exit" SIGTERM

echo "SIEM_PRESTOP_MARKER"

echo "=== seed status ==="
sudo -n cat /root/.onboarding_seeded 2>/dev/null || echo "NOT_SEEDED"

echo "=== ground truth (dap an chuan) ==="
sudo -n cat /root/.onboarding_answers 2>/dev/null || echo "NO_ANSWERS"

echo "=== saved objects (title bat dau bang bai1) ==="
sudo -n python3 /home/ubuntu/savedobj-count.py 2>/dev/null || echo "SAVEDOBJ_COUNT=0"
__OB_10__

cat > "$LAB/siem/seed-data.py" <<'__OB_11__'
#!/usr/bin/env python3
# ============================================================================
# seed-data.py  (Bai 1 - Lam quen Wazuh)  -- chay BOI SYSTEMD tren siem luc boot.
# Vi anh nen chung soc-wazuh KHONG chay Labtainers boot-hook (param/fixlocal) do mang
# san "dau da parameterize", ta KHONG dua vao parameter.config. Thay vao do:
#   - Seed TU RANDOM moi lan khoi tao container -> moi sinh vien du lieu khac nhau (chong chep bai).
#   - Ghi DAP AN chuan vao /root/.onboarding_answers (root-only; siem an TERMINALS 0 -> SV khong doc duoc).
#     siem:prestop se phat file nay ra cho grader so khop (SV khong thay prestop.stdout).
# Chay 1 lan (marker /root/.onboarding_seeded). Dung chung chi admin -> localhost:9200.
# ============================================================================
import json, os, random, subprocess, sys, time
from datetime import datetime, timedelta

MARKER  = "/root/.onboarding_seeded"
ANSWERS = "/root/.onboarding_answers"
CERTS   = "/etc/wazuh-indexer/certs"
HOST    = "https://localhost:9200"

if os.path.exists(MARKER):
    sys.exit(0)

# Bat wazuh-manager cho het banner "API offline" tren dashboard (best-effort)
os.system("systemctl start wazuh-manager >/dev/null 2>&1 &")

# --- Random RIENG moi lan (unique tung container/sinh vien) ---
random.seed(int.from_bytes(os.urandom(8), "big"))
FAILCOUNT    = random.randint(120, 350)
TOPUSER_ID   = random.randint(11, 89)
TOPIP_OCT    = random.randint(20, 240)
COUNT_404    = random.randint(25, 95)
PEAK_HOUR    = random.randint(8, 20)
COUNT_403    = random.randint(12, 70)
LEVEL_HIGH   = random.randint(3, 14)
FIRSTSSH_OCT = random.randint(31, 59)

yesterday = (datetime.now() - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
INDEX = "wazuh-alerts-4.x-" + yesterday.strftime("%Y.%m.%d")

_uid = [0]
def ts(hour, minute=None, second=None):
    minute = random.randint(0, 59) if minute is None else minute
    second = random.randint(0, 59) if second is None else second
    return yesterday.replace(hour=hour, minute=minute, second=second).strftime("%Y-%m-%dT%H:%M:%S.000+0700")

docs = []  # (hour, doc)
def add(hour, level, desc, groups, decoder, agent, data=None, when=None):
    _uid[0] += 1
    doc = {
        "timestamp": when if when else ts(hour),
        "rule": {"level": level, "description": desc, "groups": groups,
                 "id": str(1000 + (level * 37) % 9000), "firedtimes": 1, "mail": False},
        "agent": {"id": "00%d" % agent[0], "name": agent[1]},
        "manager": {"name": "siem"}, "id": "%d.%d" % (int(time.time()), _uid[0]),
        "decoder": {"name": decoder}, "location": agent[2], "full_log": desc,
        "predecoder": {"hostname": agent[1], "program_name": decoder},
    }
    if data:
        doc["data"] = data
    docs.append((hour, doc))

WEB = (2, "web-01", "/var/log/apache2/access.log")
APP = (1, "app-01", "/var/log/auth.log")
rh = lambda: random.randint(0, 23)

# C8: SSH thanh cong DAU TIEN (som nhat)
add(0, 3, "sshd: Accepted password for admin", ["authentication_success", "syslog", "sshd"], "sshd", APP,
    data={"srcip": "172.20.0.%d" % FIRSTSSH_OCT, "srcuser": "admin"}, when=ts(0, 3, 11))
for _ in range(random.randint(4, 7)):
    add(random.randint(1, 22), 3, "sshd: Accepted password for staff", ["authentication_success", "syslog", "sshd"], "sshd", APP,
        data={"srcip": "172.20.0.%d" % random.choice([12, 15, 18, 22, 25, 28]), "srcuser": "staff"})

# C1 + C2: SSH that bai, user<TOPUSER_ID> nhieu nhat
others = []
while len(others) < 6:
    u = random.randint(11, 89)
    if u != TOPUSER_ID and u not in others:
        others.append(u)
top_fail = int(FAILCOUNT * 0.40) + 1
assign = [TOPUSER_ID] * top_fail + [others[i % len(others)] for i in range(FAILCOUNT - top_fail)]
random.shuffle(assign)
for u in assign:
    add(rh(), 5, "sshd: authentication failed", ["authentication_failed", "syslog", "sshd"], "sshd", APP,
        data={"srcip": "203.0.113.%d" % random.randint(2, 254), "srcuser": "user%d" % u})

# C3 + C4 + C6: web; 203.0.113.<TOPIP_OCT> nhieu nhat
web_status = (["404"] * COUNT_404) + (["403"] * COUNT_403) + (["200"] * random.randint(150, 260))
random.shuffle(web_status)
total_web = len(web_status)
top_web = int(total_web * 0.40) + 1
other_ips = []
while len(other_ips) < 7:
    o = random.randint(2, 254)
    if o != TOPIP_OCT and o not in other_ips:
        other_ips.append(o)
ip_assign = [TOPIP_OCT] * top_web + [other_ips[i % len(other_ips)] for i in range(total_web - top_web)]
random.shuffle(ip_assign)
for st, oct_ in zip(web_status, ip_assign):
    add(rh(), 5 if st in ("404", "403") else 3, "apache: HTTP request %s" % st, ["web", "accesslog"], "web-accesslog", WEB,
        data={"srcip": "203.0.113.%d" % oct_, "id": st, "url": random.choice(["/", "/index.php", "/admin", "/login"]), "protocol": "GET"})

# C7: alert level>=10 (DUY NHAT co level>=10)
for _ in range(LEVEL_HIGH):
    add(rh(), random.choice([10, 12]), "Multiple correlated events - possible attack", ["ids", "attack"], "correlation", APP,
        data={"srcip": "203.0.113.%d" % random.randint(2, 254)})

# C5: dam bao PEAK_HOUR nhieu su kien nhat
hist = {}
for h, _d in docs:
    hist[h] = hist.get(h, 0) + 1
need = (max([c for h, c in hist.items() if h != PEAK_HOUR] or [0]) + 12) - hist.get(PEAK_HOUR, 0)
for _ in range(max(0, need)):
    add(PEAK_HOUR, 3, "systemd: routine service status", ["syslog"], "systemd", APP)

# --- Nap vao indexer (chung chi admin) ---
def curl(args, data=None):
    base = ["curl", "-s", "-k", "--cert", CERTS + "/admin.pem", "--key", CERTS + "/admin-key.pem"]
    if os.path.exists(CERTS + "/root-ca.pem"):
        base += ["--cacert", CERTS + "/root-ca.pem"]
    return subprocess.run(base + args, input=data, capture_output=True, text=True).stdout

for _ in range(80):  # cho indexer san sang (~6-7 phut toi da)
    out = curl([HOST + "/_cluster/health"])
    if '"status"' in out:
        break
    time.sleep(5)

# Tao tai khoan dang nhap dashboard: analyst / analyst (quyen admin -> xem Discover)
curl([HOST + "/_plugins/_security/api/internalusers/analyst", "-X", "PUT",
      "-H", "Content-Type: application/json", "--data-binary", "@-"],
     data=json.dumps({"password": "analyst", "backend_roles": ["admin"], "description": "SOC analyst (lab)"}))

lines = []
for _h, d in docs:
    lines.append('{"index":{"_index":"%s"}}' % INDEX)
    lines.append(json.dumps(d))
for i in range(0, len(lines), 1000):
    curl([HOST + "/_bulk", "-H", "Content-Type: application/x-ndjson", "--data-binary", "@-"],
         data="\n".join(lines[i:i + 1000]) + "\n")
curl([HOST + "/" + INDEX + "/_refresh", "-X", "POST"])

# Ghi DAP AN chuan (root-only) de grader so khop
with open(ANSWERS, "w") as f:
    f.write("GT_C1=%d\nGT_C2=%d\nGT_C3=%d\nGT_C4=%d\nGT_C5=%d\nGT_C6=%d\nGT_C7=%d\nGT_C8=%d\n"
            % (FAILCOUNT, TOPUSER_ID, TOPIP_OCT, COUNT_404, PEAK_HOUR, COUNT_403, LEVEL_HIGH, FIRSTSSH_OCT))
with open(MARKER, "w") as f:
    f.write("%d docs @ %s\n" % (len(docs), INDEX))
sys.exit(0)
__OB_11__

cat > "$LAB/siem/savedobj-count.py" <<'__OB_12__'
#!/usr/bin/env python3
# Chay boi root (qua sudo tu prestop). Dem so saved-object (visualization/dashboard)
# ma sinh vien da luu voi TIEU DE bat dau bang "bai1" -> cham Phan B.
# Dung chung chi admin cua wazuh-indexer; dem truc tiep tren index cau hinh dashboard.
import json, os, subprocess

CERTS = "/etc/wazuh-indexer/certs"
HOST  = "https://localhost:9200"
QUERY = {"query": {"bool": {"minimum_should_match": 1, "should": [
    {"wildcard": {"visualization.title": "bai1*"}},
    {"wildcard": {"dashboard.title": "bai1*"}},
]}}}

def curl(path, body):
    base = ["curl", "-s", "-k",
            "--cert", CERTS + "/admin.pem", "--key", CERTS + "/admin-key.pem"]
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
# In them co PASS (boolean) de cham chac chan, tranh phu thuoc chieu toan tu integer
if total >= 3:
    print("PARTB_PASS")
__OB_12__

cat > "$LAB/defender/_bin/fixlocal.sh" <<'__OB_13__'
#!/bin/bash
# Defender (tram analyst). Tao san file bai lam mau cho sinh vien dien dap an.
# Khong dung vao /tmp/.X11-unix (Labtainers tu lo symlink X0; dung vao se gay loi "same file").
if [ ! -f /home/ubuntu/answers.txt ]; then
cat > /home/ubuntu/answers.txt <<'TXT'
# ===== BAI LAM - Bai 1: Lam quen Wazuh =====
# Dien dap an ngay sau dau '=' (giu nguyen dinh dang C1= ... ). Chi 1 gia tri moi dong.
# Luu file lai sau khi dien (Ctrl+O neu dung nano), roi chay 'checkwork'.
C1=
C2=user
C3=203.0.113.
C4=
C5=
C6=
C7=
C8=172.20.0.
TXT
chown ubuntu:ubuntu /home/ubuntu/answers.txt 2>/dev/null || true
chmod 644 /home/ubuntu/answers.txt 2>/dev/null || true
fi
exit 0
__OB_13__

cat > "$LAB/defender/_bin/prestop" <<'__OB_14__'
#!/bin/bash
# Chay luc checkwork/stoplab tren defender. Chup bai lam cua sinh vien de cham.
trap "echo Timed out; exit" SIGTERM
echo "DEFENDER_PRESTOP_MARKER"
echo "=== answers ==="
cat /home/ubuntu/answers.txt 2>/dev/null
__OB_14__

cat > "$LAB/defender/_bin/student_startup.sh" <<'__OB_15__'
#!/bin/bash
# Mo Wazuh dashboard trong Firefox tren tram defender.
# LUU Y: file nay duoc SOURCE vao shell dang nhap cua terminal -> TUYET DOI khong goi 'exit'
# (se tat terminal) va khong chay vong lap/sleep o foreground (se treo terminal). Vi vay toan bo
# cong viec duoc bon vao MOT SUBSHELL NEN ( ... ) & -> terminal tra ve ngay, van tuong tac duoc.
#
# CHONG LOI "firefox khong len / cannot open display": Labtainers bind-mount socket X that cua host
# vao /var/tmp/.X11-unix, roi LE RA tao symlink /tmp/.X11-unix/X<n>. Doi khi symlink nay khong co
# -> firefox bao "cannot open display". Ta tu bao dam bang cach tao MOT FILE symlink ben trong thu
# muc that (TUYET DOI khong bien ca /tmp/.X11-unix thanh symlink -> tranh loi doX11Link "same file").
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
__OB_15__

# lab 2 container: don rac neu co
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
echo ">> Kiem anh nen:  docker images | grep soc-wazuh   (can localhost:5000/soc-wazuh:latest)"
echo ">> Build & chay:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-onboarding ; labtainer soc-onboarding"
echo ">> Kiem seed:     docker exec \$(docker ps -q -f name=soc-onboarding.siem) cat /root/.onboarding_seeded"
