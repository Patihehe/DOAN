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
