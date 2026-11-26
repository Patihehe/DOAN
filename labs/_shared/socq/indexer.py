#!/usr/bin/env python3
# ============================================================================
# indexer.py - client toi gian cho wazuh-indexer (OpenSearch :9200) + saved-objects cua dashboard.
# CHI chay tren siem (indexer nghe 127.0.0.1 - spike S-C). Mat khau admin doc tu ANH NEN:
#   /root/wazuh-admin-credentials.txt  (indexer_password: '...')
# Bai hoc Lab 17: HTTP 200 khong co nghia la thanh cong -> luon kiem 'errors' / items[].error.
# ============================================================================
import base64
import json
import re
import ssl
import time
import urllib.error
import urllib.request

CRED = "/root/wazuh-admin-credentials.txt"
_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class IndexerError(Exception):
    pass


def admin_password(path=CRED):
    m = re.search(r"indexer_password:\s*'([^']+)'", open(path).read())
    if not m:
        raise IndexerError("khong doc duoc mat khau admin tu %s" % path)
    return m.group(1)


class Indexer:
    def __init__(self, base="https://127.0.0.1:9200", dash="https://127.0.0.1", user="admin", password=None, timeout=60):
        self.base, self.dash, self.user = base, dash, user
        self.password = password or admin_password()
        self.timeout = timeout

    def _req(self, method, url, body=None, nd=False, hdr=None, ok=(200, 201)):
        data = None
        if body is not None:
            data = (body if isinstance(body, str) else json.dumps(body)).encode()
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", "Basic " + base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode())
        req.add_header("Content-Type", "application/x-ndjson" if nd else "application/json")
        for k, v in (hdr or {}).items():
            req.add_header(k, v)
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                    txt = r.read().decode() or "{}"
                    return r.status, json.loads(txt)
            except urllib.error.HTTPError as e:
                txt = e.read().decode(errors="replace")
                if e.code in ok:
                    return e.code, json.loads(txt or "{}")
                if e.code in (429, 502, 503) and attempt < 3:      # indexer qua tai / dang khoi dong
                    time.sleep(5 * (attempt + 1))
                    continue
                return e.code, {"error": txt[:500]}
            except (urllib.error.URLError, OSError) as e:
                if attempt < 3:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise IndexerError("%s %s: %s" % (method, url, e))
        raise IndexerError("%s %s: het so lan thu" % (method, url))

    # ------------------------------------------------------------ cum
    def wait_ready(self, wait=900):
        t0 = time.time()
        while time.time() - t0 < wait:
            try:
                c, h = self._req("GET", self.base + "/_cluster/health")
                if c == 200 and h.get("status") in ("green", "yellow"):
                    return True
            except IndexerError:
                pass
            time.sleep(10)
        return False

    def wait_dashboard(self, wait=900):
        t0 = time.time()
        while time.time() - t0 < wait:
            try:
                c, h = self._req("GET", self.dash + "/api/status")
                lvl = (((h.get("status") or {}).get("overall") or {}).get("state")
                       or ((h.get("status") or {}).get("overall") or {}).get("level"))
                if c == 200 and str(lvl).lower() in ("green", "available"):
                    return True
            except IndexerError:
                pass
            time.sleep(10)
        return False

    # ------------------------------------------------------------ du lieu
    def ensure_index(self, name, mappings=None):
        c, r = self._req("HEAD" if False else "GET", self.base + "/" + name)
        if c == 200:
            return False
        body = {"settings": {"number_of_replicas": 0}}
        if mappings:
            body["mappings"] = mappings
        c, r = self._req("PUT", self.base + "/" + name, body)
        if c not in (200, 201) and "resource_already_exists" not in json.dumps(r):
            raise IndexerError("tao index %s: %s %s" % (name, c, r))
        return True

    def bulk(self, docs_by_index, chunk=500, refresh=False):
        """docs_by_index: {index: [doc,...]} hoac list (index, doc). Tra so doc da ghi; loi -> IndexerError."""
        items = []
        if isinstance(docs_by_index, dict):
            for idx, ds in docs_by_index.items():
                items += [(idx, d) for d in ds]
        else:
            items = list(docs_by_index)
        n = 0
        for i in range(0, len(items), chunk):
            part = items[i:i + chunk]
            body = "".join(json.dumps({"index": {"_index": idx}}) + "\n" + json.dumps(d) + "\n" for idx, d in part)
            last = i + chunk >= len(items)
            c, r = self._req("POST", self.base + "/_bulk" + ("?refresh=true" if (refresh and last) else ""), body, nd=True)
            if c != 200 or r.get("errors"):
                bad = [it for it in r.get("items", []) if (it.get("index") or {}).get("error")]
                raise IndexerError("bulk loi (HTTP %s): %s" % (c, json.dumps(bad[:2] or r)[:600]))
            n += len(part)
        return n

    def count(self, index, query):
        c, r = self._req("POST", self.base + "/%s/_count" % index, {"query": query})
        return r.get("count", 0) if c == 200 else -1

    def delete_index(self, name):
        return self._req("DELETE", self.base + "/" + name, ok=(200, 404))[0]

    # ------------------------------------------------------------ dashboard
    def index_pattern(self, pid, title, time_field=None):
        attrs = {"title": title}
        if time_field:
            attrs["timeFieldName"] = time_field
        c, r = self._req("POST", self.dash + "/api/saved_objects/index-pattern/%s?overwrite=true" % pid,
                         {"attributes": attrs}, hdr={"osd-xsrf": "true"})
        if c not in (200, 201):
            raise IndexerError("tao index pattern %s: %s %s" % (title, c, r))
        return True


CTX_MAPPING = {"properties": {
    "id": {"type": "keyword"}, "type": {"type": "keyword"}, "kind": {"type": "keyword"},
    "host": {"type": "keyword"}, "ip": {"type": "keyword"}, "status": {"type": "keyword"},
    "criticality": {"type": "keyword"}, "user": {"type": "keyword"}, "actor": {"type": "keyword"},
    "name": {"type": "text", "fields": {"raw": {"type": "keyword"}}},
    "match": {"type": "keyword"}, "start": {"type": "date"}, "end": {"type": "date"},
    "description": {"type": "text"}, "@timestamp": {"type": "date"}}}
