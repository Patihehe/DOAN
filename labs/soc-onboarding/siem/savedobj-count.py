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
