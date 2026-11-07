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
