#!/bin/bash
# ============================================================================
# Trinh cai dat lab soc-baseline (Bai 3 - Baseline & bat thuong) len VM Labtainers.
#   bash install-soc-baseline.sh
# TU-CHUA (nhung toan bo file bang heredoc). Yeu cau: co $LABTAINER_DIR; da dung anh nen chung
# localhost:5000/soc-wazuh:latest. KHONG chay apply-shared-siem.sh len lab nay.
# (File nay SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then
  echo "LOI: chua co \$LABTAINER_DIR. Chay ./update-designer.sh roi mo terminal moi."
  exit 1
fi
LAB="$LABTAINER_DIR/labs/soc-baseline"
echo ">> Tao lab tai: $LAB"
mkdir -p "$LAB/config" "$LAB/dockerfiles" "$LAB/docs" "$LAB/instr_config" "$LAB/siem/_bin" "$LAB/defender/_bin"

cat > "$LAB/config/start.config" <<'__LT_01__'
# start.config - Lab soc-baseline (Bai 3 - Baseline & bat thuong)
# Muc tieu: phan biet binh thuong <-> bat thuong. Log ~7 ngay baseline + 3 bat thuong cay san.
# Khong co alert do chi san. SV tu phat hien tai defender.
#
# 2 container (giong Bai 1/2):
#   siem     - Wazuh, SEED bang systemd (self-random). TERMINALS 0 (an).
#   defender - tram analyst: Firefox + terminal ghi bai lam. Noi cham diem.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-baseline_student_master_seed
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
# parameter.config - Bai 3 KHONG dung RAND_REPLACE.
# siem chay anh nen chung soc-wazuh -> Labtainers boot-hook bi bo qua. Ca nhan hoa bang SEED TU RANDOM
# moi container (xem siem/seed-data.py). (De trong co chu dich.)
__LT_02__

cat > "$LAB/config/about.txt" <<'__LT_03__'
soc-baseline - Bai 3 (khep Chang 0) trong lo trinh "Dieu tra su co & Ky nghe phat hien tren SIEM".
Phan biet binh thuong <-> bat thuong: log ~7 ngay baseline + 3 bat thuong cay san (dang nhap ngoai gio,
1 tai khoan nhieu IP, 1 may gui nhieu du lieu ra ngoai). Khong co alert do chi san - tu phat hien.
Muc tieu nang luc: A4 (phan doan/anomaly). Thoi luong ~75 phut.
__LT_03__

cat > "$LAB/docs/read_first.txt" <<'__LT_04__'
========================================================================
  BAI 3 - BASELINE & BAT THUONG: "Ngui ra cai la" (Cong ty X)
========================================================================

Bai 1 ban DEM, Bai 2 ban DOC HIEU alert. Hom nay khac han: KHONG co canh bao do chi san.
Ban duoc giao log ~7 NGAY "binh thuong" cua Cong ty X va phai TU PHAT HIEN 3 hanh vi bat thuong
bang cach so voi "muc binh thuong" (baseline). Day la kieu phat hien theo HANH VI (anomaly),
khac bat theo chu ky/dau hieu co san.

BASELINE binh thuong cua Cong ty X:
  - Dang nhap: trong GIO HANH CHINH (8h-17h), tu IP NOI BO quen (172.20.0.x), moi tai khoan 1-2 IP.
  - Ket noi ra ngoai (outbound): moi may noi bo chi vai ket noi.
Cai gi LECH khoi nhung muc tren -> dang ngo.

------------------------------------------------------------------------
0) MO DASHBOARD
------------------------------------------------------------------------
  - Firefox tu mo https://172.20.0.20 ; dang nhap:  analyst / analyst
  - Discover, index "wazuh-alerts-*".
  - !!! DAT THOI GIAN = "Last 7 days" (du lieu trai 7 ngay, khong phai 1 ngay).
  - Banner "API offline" -> BO QUA.

------------------------------------------------------------------------
3 BAT THUONG CAN TIM
------------------------------------------------------------------------
  (A) Mot lan DANG NHAP NGOAI GIO (rang sang), trong khi moi dang nhap khac deu 8h-17h.
  (B) MOT TAI KHOAN dang nhap tu NHIEU IP khac nhau (la), trong khi nguoi thuong chi 1-2 IP.
  (C) MOT MAY noi bo gui RAT NHIEU ket noi RA NGOAI, lech han cac may khac.

------------------------------------------------------------------------
1) TRA LOI 8 CAU (ghi SO vao ~/answers.txt)
------------------------------------------------------------------------
  C1. GIO (0-23) cua lan dang nhap NGOAI GIO la may?
  C2. Octet cuoi IP nguon cua lan dang nhap ngoai gio do (dang 203.0.113.X -> ghi so X)?
  C3. id cua tai khoan dang nhap tu NHIEU IP nhat (ten user<id> -> ghi so id)?
  C4. Tai khoan do dang nhap tu BAO NHIEU IP khac nhau?
  C5. Octet cuoi IP noi bo (172.20.0.X) cua MAY gui nhieu du lieu ra ngoai (ghi so X)?
  C6. May do co BAO NHIEU ket noi di ra ngoai?
  C7. Ban tim duoc TONG CONG bao nhieu hanh vi bat thuong? (tim du, dung sot)
  C8. Phat hien kieu nay dua tren: (1) hanh vi/lech baseline  (2) chu ky co san ? -> ghi 1 hoac 2

  Ghi: nano ~/answers.txt ; vi du  C1=3  C2=88  C3=45  C4=6

------------------------------------------------------------------------
2) GOI Y 3 CAP
------------------------------------------------------------------------
 Cap 1: Dung histogram (bieu do cot theo thoi gian) va "Top values" cua cac field de so sanh.
 Cap 2 (tim o dau):
   (A) Loc rule.groups:authentication_success -> xem histogram theo GIO -> 1 cot nam ngoai 8-17h.
       Mo dong do -> doc gio (C1) va data.srcip (C2).
   (B) Loc authentication_success va data.srcip:203.0.113.*  (dang nhap tu IP NGOAI la bat thuong)
       -> Top values data.srcuser -> tai khoan xuat hien nhieu = tai khoan dang ngo (C3).
       Loc them data.srcuser:user<id> -> so hits = so IP khac nhau (C4).
   (C) Loc rule.groups:firewall (hoac decoder.name:firewall) -> Top values data.srcip
       -> may noi bo 172.20.0.x co so ket noi lon vuot troi (C5); so hits cua may do = C6.
 Cap 3:
   - C1/C2: authentication_success -> histogram -> cot rang sang -> mo -> gio + octet cuoi srcip.
   - C3/C4: authentication_success + data.srcip:203.0.113.* -> Top data.srcuser (dau bang) = user bat thuong;
            so hits khi them data.srcuser:user<id> = so IP khac nhau.
   - C5/C6: rule.groups:firewall -> Top data.srcip -> 172.20.0.X dau bang; so hits cua no = C6.
   - C7 = 3.  C8 = 1 (phat hien dua tren HANH VI lech baseline).

------------------------------------------------------------------------
3) PHAN B - DUNG 2 BIEU DO (ten bat dau "bai3")
------------------------------------------------------------------------
  - bai3-dangnhap-theo-gio : Bar, Buckets Date Histogram field timestamp (de lo cot rang sang)
  - bai3-outbound-theo-may : Bar, Buckets Terms field data.srcip  (de lo may vuot troi)
  (Bam "Update" moi ve; luu ten bat dau "bai3".)

------------------------------------------------------------------------
4) NOP BAI
------------------------------------------------------------------------
  checkwork ; muc: q1..q8, bai3_partA (dung >=7/8), bai3_partB (>=2 bieu do bai3)
  Xong: stoplab
__LT_04__

cat > "$LAB/instr_config/results.config" <<'__LT_05__'
# results.config - trich cau tra loi SV (defender) + dap an chuan (siem) + Phan B. Ca 8 cau la SO NGUYEN.

_c1 = defender:prestop.stdout : GROUP : 1 : REGEX : C1\s*=\s*([0-9]+)
_c2 = defender:prestop.stdout : GROUP : 1 : REGEX : C2\s*=\s*([0-9]+)
_c3 = defender:prestop.stdout : GROUP : 1 : REGEX : C3\s*=\s*([0-9]+)
_c4 = defender:prestop.stdout : GROUP : 1 : REGEX : C4\s*=\s*([0-9]+)
_c5 = defender:prestop.stdout : GROUP : 1 : REGEX : C5\s*=\s*([0-9]+)
_c6 = defender:prestop.stdout : GROUP : 1 : REGEX : C6\s*=\s*([0-9]+)
_c7 = defender:prestop.stdout : GROUP : 1 : REGEX : C7\s*=\s*([0-9]+)
_c8 = defender:prestop.stdout : GROUP : 1 : REGEX : C8\s*=\s*([0-9]+)

_gt1 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C1=([0-9]+)
_gt2 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C2=([0-9]+)
_gt3 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C3=([0-9]+)
_gt4 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C4=([0-9]+)
_gt5 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C5=([0-9]+)
_gt6 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C6=([0-9]+)
_gt7 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C7=([0-9]+)
_gt8 = siem:prestop.stdout : GROUP : 1 : REGEX : GT_C8=([0-9]+)

_partb = siem:prestop.stdout : FILE_REGEX : PARTB_PASS
__LT_05__

cat > "$LAB/instr_config/goals.config" <<'__LT_06__'
# goals.config - so khop cau tra loi SV (_cN) voi dap an chuan (_gtN) do seed tu random & ghi.

q1 = matchany : integer_equal : _c1 : result._gt1
q2 = matchany : integer_equal : _c2 : result._gt2
q3 = matchany : integer_equal : _c3 : result._gt3
q4 = matchany : integer_equal : _c4 : result._gt4
q5 = matchany : integer_equal : _c5 : result._gt5
q6 = matchany : integer_equal : _c6 : result._gt6
q7 = matchany : integer_equal : _c7 : result._gt7
q8 = matchany : integer_equal : _c8 : result._gt8

# Dat Phan A khi dung >= 7/8
bai3_partA = count_greater : 6 : (q1, q2, q3, q4, q5, q6, q7, q8)

# Phan B: >= 2 visualization/dashboard ten "bai3"
bai3_partB = boolean : _partb
__LT_06__

cat > "$LAB/dockerfiles/Dockerfile.soc-baseline.siem.student" <<'__LT_07__'
#
# siem - dung anh nen chung soc-wazuh. Boot-hook Labtainers BI BO QUA tren anh chung -> SEED bang
# SYSTEMD unit 'seed-baseline.service'. seed-data.py self-random. KHONG chay apply-shared-siem.sh len lab nay.
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
RUN printf '%s\n' \
  'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /root/.bl_seeded, /usr/bin/cat /root/.bl_seeded, /bin/cat /root/.bl_answers, /usr/bin/cat /root/.bl_answers, /usr/bin/python3 /home/ubuntu/savedobj-count.py' \
  > /etc/sudoers.d/labtainer-bl && chmod 440 /etc/sudoers.d/labtainer-bl
#
# === SEED bang SYSTEMD ===
RUN printf '%s\n' \
  '[Unit]' \
  'Description=Seed baseline data into Wazuh indexer' \
  'After=wazuh-indexer.service network-online.target' \
  'Wants=wazuh-indexer.service' \
  '[Service]' \
  'Type=oneshot' \
  'RemainAfterExit=yes' \
  'ExecStart=/usr/bin/python3 /home/ubuntu/seed-data.py' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > /etc/systemd/system/seed-baseline.service \
 && mkdir -p /etc/systemd/system/multi-user.target.wants \
 && ln -sf /etc/systemd/system/seed-baseline.service /etc/systemd/system/multi-user.target.wants/seed-baseline.service
#
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
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
RUN mkdir -p /home/$user_name/.local && echo "soc-baseline" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__LT_07__

cat > "$LAB/dockerfiles/Dockerfile.soc-baseline.defender.student" <<'__LT_08__'
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
# siem (anh nen chung soc-wazuh). SEED do SYSTEMD unit 'seed-baseline.service' lam (boot-hook Labtainers
# bi bo qua tren anh chung). fixlocal nay toi thieu.
exit 0
__LT_09__

cat > "$LAB/siem/_bin/prestop" <<'__LT_10__'
#!/bin/bash
# Chay luc checkwork/stoplab tren siem. Phat DAP AN chuan + trang thai Phan B.
trap "echo Timed out; exit" SIGTERM

echo "SIEM_PRESTOP_MARKER"

echo "=== seed status ==="
sudo -n cat /root/.bl_seeded 2>/dev/null || echo "NOT_SEEDED"

echo "=== ground truth (dap an chuan) ==="
sudo -n cat /root/.bl_answers 2>/dev/null || echo "NO_ANSWERS"

echo "=== saved objects (title bat dau bang bai3) ==="
sudo -n python3 /home/ubuntu/savedobj-count.py 2>/dev/null || echo "SAVEDOBJ_COUNT=0"
__LT_10__

cat > "$LAB/siem/seed-data.py" <<'__LT_11__'
#!/usr/bin/env python3
# ============================================================================
# seed-data.py  (Bai 3 - Baseline & bat thuong)  -- chay BOI SYSTEMD tren siem luc boot.
# Nap ~7 NGAY log "binh thuong" + CAY 3 BAT THUONG. Khong co alert do chi san -> nguoi hoc tu phat
# hien outlier bang cach so voi baseline. Self-random moi container (chong chep bai).
# Ghi dap an chuan vao /root/.bl_answers; siem:prestop phat ra cho grader.
#
# 3 bat thuong + 8 dap an:
#   C1 = gio (0-23) cua dang nhap NGOAI GIO (chi co 1)          = ANOM_HOUR
#   C2 = octet cuoi IP nguon lan dang nhap ngoai gio (203.0.113.X) = ANOM1_IP_OCT
#   C3 = id user dang nhap tu NHIEU IP nhat                     = ANOM_USER_ID
#   C4 = user do dang nhap tu bao nhieu IP khac nhau            = ANOM_IP_COUNT
#   C5 = octet cuoi IP noi bo may gui du lieu ra ngoai (172.20.0.X) = ANOM_HOST_OCT
#   C6 = may do co bao nhieu ket noi di ra ngoai                = ANOM_OUT_COUNT
#   C7 = tong so hanh vi bat thuong                             = 3   [kiem tra tim du]
#   C8 = phat hien dua tren hanh vi/lech baseline (1) hay chu ky (2) = 1 [khai niem]
# ============================================================================
import json, os, random, subprocess, sys, time
from datetime import datetime, timedelta

MARKER  = "/root/.bl_seeded"
ANSWERS = "/root/.bl_answers"
CERTS   = "/etc/wazuh-indexer/certs"
HOST    = "https://localhost:9200"

if os.path.exists(MARKER):
    sys.exit(0)

os.system("systemctl start wazuh-manager >/dev/null 2>&1 &")
random.seed(int.from_bytes(os.urandom(8), "big"))

ANOM_HOUR     = random.randint(2, 5)       # ngoai gio hanh chinh (binh thuong 8-18)
ANOM1_IP_OCT  = random.randint(2, 254)
ANOM_USER_ID  = random.randint(11, 89)
ANOM_IP_COUNT = random.randint(5, 8)
ANOM_HOST_OCT = random.randint(31, 59)
ANOM_OUT_COUNT = random.randint(40, 90)

today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
days = [today - timedelta(days=i) for i in range(1, 8)]   # 7 ngay gan nhat
MON = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

_uid = [0]
docs = []   # (index_name, doc)
def add(day, hour, level, desc, groups, decoder, agent, full_log, data=None, minute=None):
    _uid[0] += 1
    mn = random.randint(0, 59) if minute is None else minute
    t = day.replace(hour=hour, minute=mn, second=random.randint(0, 59))
    doc = {
        "timestamp": t.strftime("%Y-%m-%dT%H:%M:%S.000+0700"),
        "rule": {"level": level, "description": desc, "groups": groups, "id": str(5500 + level), "firedtimes": 1, "mail": False},
        "agent": {"id": "00%d" % agent[0], "name": agent[1]},
        "manager": {"name": "siem"}, "id": "%d.%d" % (int(time.time()), _uid[0]),
        "decoder": {"name": decoder}, "location": agent[2],
        "predecoder": {"hostname": agent[1], "program_name": decoder},
        "full_log": full_log,
    }
    if data:
        doc["data"] = data
    docs.append(("wazuh-alerts-4.x-" + day.strftime("%Y.%m.%d"), doc))

APP = (1, "app-01", "/var/log/auth.log")
FW  = (3, "fw-01", "/var/log/firewall.log")

def login(day, hour, user, srcip):
    add(day, hour, 3, "sshd: Accepted password", ["authentication_success", "syslog", "sshd"], "sshd", APP,
        "%s %02d %02d:00:00 app-01 sshd[%d]: Accepted password for %s from %s port 22 ssh2" % (
            MON[day.month-1], day.day, hour, random.randint(1000,9999), user, srcip),
        data={"srcip": srcip, "srcuser": user})

def outbound(day, host_oct):
    dst = "%d.%d.%d.%d" % (random.randint(1,223), random.randint(0,255), random.randint(0,255), random.randint(1,254))
    add(day, random.randint(0, 23), 3, "firewall: outbound connection", ["firewall", "outbound"], "firewall", FW,
        "%s %02d app-fw: OUT src=172.20.0.%d dst=%s proto=TCP" % (MON[day.month-1], day.day, host_oct, dst),
        data={"srcip": "172.20.0.%d" % host_oct, "dstip": dst})

# ---- BASELINE: dang nhap BINH THUONG (gio 8-18, IP noi bo, moi user 1-2 IP) ----
normal_users = []
while len(normal_users) < 12:
    u = random.randint(11, 89)
    if u != ANOM_USER_ID and u not in normal_users:
        normal_users.append(u)
for uid in normal_users:
    ips = ["172.20.0.%d" % random.randint(60, 120) for _ in range(random.randint(1, 2))]
    for _ in range(random.randint(3, 8)):
        login(random.choice(days), random.randint(8, 17), "user%d" % uid, random.choice(ips))
# admin: vai dang nhap binh thuong (noi bo, 1 IP co dinh, gio hanh chinh)
admin_ip = "172.20.0.%d" % random.randint(10, 20)
for _ in range(random.randint(2, 3)):
    login(random.choice(days), random.randint(8, 17), "admin", admin_ip)

# ---- BAT THUONG 1: dang nhap NGOAI GIO (duy nhat ngoai 8-18) ----
login(random.choice(days), ANOM_HOUR, "admin", "203.0.113.%d" % ANOM1_IP_OCT)

# ---- BAT THUONG 2: user<ANOM_USER_ID> dang nhap tu ANOM_IP_COUNT IP ngoai khac nhau (gio hanh chinh) ----
octs = set()
while len(octs) < ANOM_IP_COUNT:
    o = random.randint(2, 254)
    if o != ANOM1_IP_OCT:
        octs.add(o)
for o in octs:
    login(random.choice(days), random.randint(8, 17), "user%d" % ANOM_USER_ID, "203.0.113.%d" % o)

# ---- BASELINE: outbound BINH THUONG (moi may noi bo 1-5 ket noi) ----
normal_hosts = []
while len(normal_hosts) < 15:
    h = random.randint(31, 59)
    if h != ANOM_HOST_OCT and h not in normal_hosts:
        normal_hosts.append(h)
for h in normal_hosts:
    for _ in range(random.randint(1, 5)):
        outbound(random.choice(days), h)

# ---- BAT THUONG 3: may 172.20.0.<ANOM_HOST_OCT> gui RAT NHIEU ra ngoai ----
for _ in range(ANOM_OUT_COUNT):
    outbound(random.choice(days), ANOM_HOST_OCT)

# ---- Nap vao indexer ----
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
for idx, d in docs:
    lines.append('{"index":{"_index":"%s"}}' % idx)
    lines.append(json.dumps(d))
for i in range(0, len(lines), 1000):
    curl([HOST + "/_bulk", "-H", "Content-Type: application/x-ndjson", "--data-binary", "@-"],
         data="\n".join(lines[i:i + 1000]) + "\n")
curl([HOST + "/wazuh-alerts-4.x-*/_refresh", "-X", "POST"])

with open(ANSWERS, "w") as f:
    f.write("GT_C1=%d\nGT_C2=%d\nGT_C3=%d\nGT_C4=%d\nGT_C5=%d\nGT_C6=%d\nGT_C7=3\nGT_C8=1\n"
            % (ANOM_HOUR, ANOM1_IP_OCT, ANOM_USER_ID, ANOM_IP_COUNT, ANOM_HOST_OCT, ANOM_OUT_COUNT))
with open(MARKER, "w") as f:
    f.write("%d docs @ 7 days\n" % len(docs))
sys.exit(0)
__LT_11__

cat > "$LAB/siem/savedobj-count.py" <<'__LT_12__'
#!/usr/bin/env python3
# Chay boi root (qua sudo tu prestop). Dem so visualization/dashboard SV da luu voi TIEU DE
# bat dau bang "bai3" -> cham Phan B (can >= 2).
import json, os, subprocess

CERTS = "/etc/wazuh-indexer/certs"
HOST  = "https://localhost:9200"
QUERY = {"query": {"bool": {"minimum_should_match": 1, "should": [
    {"wildcard": {"visualization.title": "bai3*"}},
    {"wildcard": {"dashboard.title": "bai3*"}},
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
if total >= 2:
    print("PARTB_PASS")
__LT_12__

cat > "$LAB/defender/_bin/fixlocal.sh" <<'__LT_13__'
#!/bin/bash
# Defender (tram analyst). Tao san file bai lam mau cho sinh vien dien dap an.
if [ ! -f /home/ubuntu/answers.txt ]; then
cat > /home/ubuntu/answers.txt <<'TXT'
# ===== BAI LAM - Bai 3: Baseline & bat thuong =====
# Dien dap an ngay sau dau '=' (giu nguyen C1= ...). Chi 1 gia tri (so) moi dong.
# C2, C5 dien OCTET CUOI cua IP (so cuoi). Luu file roi chay 'checkwork'.
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
echo ">> Build & chay:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-baseline && labtainer soc-baseline"
echo ">> Kiem seed:     docker exec \$(docker ps -q -f name=soc-baseline.siem) cat /root/.bl_seeded"
