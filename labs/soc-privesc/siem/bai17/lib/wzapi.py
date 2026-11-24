#!/usr/bin/env python3
# ============================================================================
# wzapi.py - client toi gian cho Wazuh API (cong 55000). Chi dung thu vien chuan.
# Dung chung cho: kiem-thu-luat, thu-dong, replay.py (defender) va grade (siem).
#
# Cau hinh (bien moi truong, co mac dinh cho lab):
#   WZ_API_URL   (mac dinh https://172.20.0.20:55000)
#   WZ_API_USER  (mac dinh bai17-tool)
#   WZ_API_PASS  (mac dinh xem DEFAULT_PASS)
# ============================================================================
import base64, json, os, ssl, time, urllib.error, urllib.parse, urllib.request

DEFAULT_URL = "https://172.20.0.20:55000"
DEFAULT_USER = "soc-tool"
DEFAULT_PASS = "Soc.Tool.2026!"

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class WazuhError(Exception):
    pass


class Wazuh:
    def __init__(self, url=None, user=None, password=None, timeout=30):
        self.url = (url or os.environ.get("WZ_API_URL") or DEFAULT_URL).rstrip("/")
        self.user = user or os.environ.get("WZ_API_USER") or DEFAULT_USER
        self.password = password or os.environ.get("WZ_API_PASS") or DEFAULT_PASS
        self.timeout = timeout
        self.token = None

    # ---------------- tang thap ----------------
    def _req(self, method, path, body=None, raw=None, ctype="application/json", auth=True, params=None, _try=0):
        url = self.url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = None
        if raw is not None:
            data = raw if isinstance(raw, bytes) else raw.encode("utf-8")
        elif body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", ctype)
        if auth:
            if not self.token:
                self.login()
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                txt = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")
            if e.code == 401 and auth and self.token:
                # token het han -> dang nhap lai 1 lan
                self.token = None
                return self._req(method, path, body, raw, ctype, auth, params)
            if e.code == 500 and '"error": 3021' in txt and _try < 3:
                # 3021 = "Timeout executing API request": may ao qua tai, manager cham -> thu lai
                time.sleep(5 * (_try + 1))
                return self._req(method, path, body, raw, ctype, auth, params, _try + 1)
            raise WazuhError("HTTP %s %s %s: %s" % (e.code, method, path, txt[:400]))
        except Exception as e:
            raise WazuhError("%s %s: %s" % (method, path, e))
        try:
            return json.loads(txt) if txt else {}
        except ValueError:
            return {"raw": txt}

    def login(self):
        url = self.url + "/security/user/authenticate"
        req = urllib.request.Request(url, data=b"", method="POST")
        cred = base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode()
        req.add_header("Authorization", "Basic " + cred)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                self.token = json.loads(r.read().decode())["data"]["token"]
        except urllib.error.HTTPError as e:
            raise WazuhError("Dang nhap API that bai (HTTP %s) - API chua san sang hoac sai tai khoan" % e.code)
        except Exception as e:
            raise WazuhError("Khong ket noi duoc Wazuh API %s: %s" % (self.url, e))
        return self.token

    # ---------------- ruleset ----------------
    def get_rule_file(self, name):
        r = self._req("GET", "/rules/files/" + name, params={"raw": "true"})
        return r.get("raw", "") if isinstance(r, dict) else r

    @staticmethod
    def _check_items(r, what):
        """API tra HTTP 200 ca khi KHONG ghi duoc file: loi nam trong data.failed_items."""
        d = (r or {}).get("data") or {}
        fails = d.get("failed_items") or []
        if fails or (d.get("total_affected_items") == 0 and "affected_items" in d):
            raise WazuhError("Wazuh KHONG ghi %s: %s" % (what, json.dumps(fails or r, ensure_ascii=False)[:500]))
        return r

    def put_rule_file(self, name, content):
        return self._check_items(self._req("PUT", "/rules/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    def put_list_file(self, name, content):
        return self._check_items(self._req("PUT", "/lists/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    # ---------------- manager ----------------
    def validate(self):
        """Tra ve (ok, thong_bao)."""
        r = self._req("GET", "/manager/configuration/validation")
        items = (r.get("data") or {}).get("affected_items") or []
        for it in items:
            if it.get("status") != "OK":
                return False, json.dumps(it.get("details", it), ensure_ascii=False)[:800]
        fails = (r.get("data") or {}).get("failed_items") or []
        if fails:
            return False, json.dumps(fails, ensure_ascii=False)[:800]
        return True, "OK"

    def restart(self, wait=240):
        """PUT /manager/restart chi XEP LICH restart (bat dong bo): vai giay dau /manager/status van
        bao tien trinh CU 'running' -> neu tra ve luc do, phat lai se chay tren bo luat CU.
        Phai thay manager XUONG (API mat ket noi / analysisd khong running) roi moi cho no LEN lai."""
        self._req("PUT", "/manager/restart")
        t0 = time.time()
        seen_down = False
        while time.time() - t0 < wait:
            time.sleep(3)
            try:
                self.token = None
                st = self._req("GET", "/manager/status")
                items = (st.get("data") or {}).get("affected_items") or [{}]
                up = items[0].get("wazuh-analysisd") == "running"
            except WazuhError:
                up = False
            if not up:
                seen_down = True
            elif seen_down or time.time() - t0 > 60:
                # da thay xuong roi len (hoac qua 60s ma khong bat duoc luc xuong) -> cho analysisd nap xong
                time.sleep(10)
                return True
        return False

    # ---------------- logtest ----------------
    def logtest(self, event, token=None, location="/var/log/auth.log", log_format="syslog"):
        body = {"event": event, "log_format": log_format, "location": location}
        if token:
            body["token"] = token
        r = self._req("PUT", "/logtest", body=body)
        d = r.get("data") or {}
        return d.get("token"), d.get("output") or {}

    def logtest_close(self, token):
        if not token:
            return
        try:
            self._req("DELETE", "/logtest/sessions/" + token)
        except WazuhError:
            pass
