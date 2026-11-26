#!/usr/bin/env python3
# ============================================================================
# ctx.py - ngu canh doanh nghiep (hop dong du lieu Bai 14, muc 4.3):
#   ctx-assets  (type asset | service)   AST-### / SVC-###
#   ctx-changes                          CHG-####
#   ctx-hr      (kind leave | oncall)    LV-#### / OC-####
# Registry cap so ID DUY NHAT va giu moi ban ghi; cases.py / chain.py them ban ghi rieng cua minh.
# ============================================================================
import time

from . import docs


def hhmm(ts):
    """ISO 8601 co mui gio dang +07:00 (OpenSearch 'date' doc duoc; nguoi doc thay dung gio dia phuong)."""
    z = time.strftime("%z", time.localtime(ts))
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(ts)) + z[:3] + ":" + z[3:]


class Ctx:
    def __init__(self, world, t0):
        self.w, self.t0, self.rng = world, t0, world.rng
        self.records = {"ctx-assets": [], "ctx-changes": [], "ctx-hr": []}
        self._used = {"AST": set(), "SVC": set(), "CHG": set(), "LV": set(), "OC": set()}

    def _id(self, kind, lo, hi):
        while True:
            n = self.rng.randint(lo, hi)
            if n not in self._used[kind] and all(n not in s for s in self._used.values()):
                # so DUY NHAT tren moi loai -> cot E cua BTP/FP khong trung nhau
                self._used[kind].add(n)
                return n

    # ------------------------------------------------------------ them ban ghi
    def asset(self, host):
        h = self.w.hosts[host]
        n = self._id("AST", 100, 999)
        self.records["ctx-assets"].append({"id": "AST-%03d" % n, "type": "asset", "host": host, "ip": h["ip"],
                                           "criticality": h["crit"], "name": h["role"], "status": "active",
                                           "actor": "IT", "description": ""})
        return n

    def service(self, hosts, name, match, status="approved", actor="IT Ops", description=""):
        # mot phan mem = MOT ban ghi SVC (2 ticket cung phan mem -> cung so E, khong mo ho)
        for r in self.records["ctx-assets"]:
            if r.get("type") == "service" and r["match"] == match and r["status"] == status:
                r["host"] = sorted(set(r["host"]) | set(hosts))
                return int(r["id"].split("-")[1])
        n = self._id("SVC", 100, 999)
        self.records["ctx-assets"].append({"id": "SVC-%03d" % n, "type": "service", "host": list(hosts),
                                           "name": name, "match": match, "status": status,
                                           "actor": actor, "description": description})
        return n

    def change(self, hosts, kind, start, end, status="approved", ip=None, actor="", description=""):
        n = self._id("CHG", 1000, 9999)
        rec = {"id": "CHG-%04d" % n, "host": list(hosts), "kind": kind, "start": hhmm(start), "end": hhmm(end),
               "status": status, "actor": actor, "description": description}
        if ip:
            rec["ip"] = ip if isinstance(ip, list) else [ip]
        self.records["ctx-changes"].append(rec)
        return n

    def oncall(self, staff, hosts, start, end, status="approved"):
        n = self._id("OC", 100, 9999)
        self.records["ctx-hr"].append({"id": "OC-%04d" % n, "kind": "oncall", "user": staff["user"], "name": staff["name"],
                                       "host": list(hosts), "start": hhmm(start), "end": hhmm(end), "status": status})
        return n

    def leave(self, staff, start, end, status="approved"):
        n = self._id("LV", 100, 9999)
        self.records["ctx-hr"].append({"id": "LV-%04d" % n, "kind": "leave", "user": staff["user"], "name": staff["name"],
                                       "start": hhmm(start), "end": hhmm(end), "status": status})
        return n

    # ------------------------------------------------------------ nen + moi chung
    def base(self):
        """Tai san moi may + dich vu nen + CHG dot trien khai agent sao luu (nguyen nhan bao)."""
        w, t0, r = self.w, self.t0, self.rng
        for host in w.hosts:
            self.asset(host)
        allsrv = [n for n in w.hosts if not n.startswith("ws-")]
        self.svc_upload = self.service(["web-shop"], "Script xu ly anh dai dien (da duyet)",
                                       w.upload_dir + w.approved_script, actor="Web team",
                                       description="Script hop le DUY NHAT trong thu muc upload; nhan tham so w,h")
        self.service(list(w.hosts), "Log rotate", "/var/log", description="logrotate 00:00 hang ngay")
        # CHG dot trien khai agent sao luu - CO nhac cong agent va may nguon
        bk_ips = [w.ip(h) for h in w.backup_hosts]
        self.chg_backup = self.change(
            w.backup_hosts, "deploy", t0 - 3600, t0 + 4 * 3600, ip=bk_ips, actor="DevOps",
            description="Trien khai agent sao luu moi tu %s toi toan bo may chu; agent ket noi cong TCP %d"
                        % (", ".join(w.backup_hosts), w.backup_port))
        # moi: CHG cua may khac / da xong / da huy; SVC retired
        self.change(["web-staging"], "deploy", t0 - 86400, t0 - 80000, status="completed", actor="Web team",
                    description="Cap nhat giao dien thu nghiem")
        self.change(["mail-01"], "patch", t0 - 3 * 86400, t0 - 3 * 86400 + 7200, status="completed", actor="IT Ops",
                    description="Va loi may chu thu")
        self.change(w.backup_hosts[:1], "deploy", t0 - 7 * 86400, t0 - 7 * 86400 + 3600, status="cancelled",
                    actor="DevOps", description="Trien khai agent sao luu (lan 1, da huy)")
        self.service(["web-shop"], "Script tai anh cu", w.upload_dir + "upload_old.php", status="retired",
                     actor="Web team", description="Ngung su dung tu Q2")
        self.service(allsrv, "Agent giam sat cu", "/opt/oldmon/bin/agent", status="retired")

    # ------------------------------------------------------------ xuat
    def as_docs(self):
        """{index: [doc...]} - moi doc kem @timestamp = t0 (index pattern ctx-* KHONG dung truong thoi gian)."""
        out = {}
        for idx, recs in self.records.items():
            out[idx] = [dict(r, **{"@timestamp": docs.iso(self.t0)}) for r in recs]
        return out
