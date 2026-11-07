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
