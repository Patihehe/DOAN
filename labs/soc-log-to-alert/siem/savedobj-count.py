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
