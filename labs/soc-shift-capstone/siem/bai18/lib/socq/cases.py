#!/usr/bin/env python3
# ============================================================================
# cases.py - mau tinh huong hang doi (hop dong du lieu Bai 14, muc 4.4) - BAN TOI THIEU cho Bai 18.
#
# Hai buoc tach nhau (vi T0 cua ca chi biet SAU khi seed xong):
#   plan(...)   luc seed: chon mau, sinh tham so, ghi ngu canh (ctx), CHOT dap an (V, P, E)
#   render(...) luc phat: sinh ticket + su kien bang chung voi timestamp quanh gio phat thuc te
#
# Dap an theo SOP Bai 14:  V 1=TP 2=BTP 3=FP ;  P 1..4 (BTP/FP luon 4) ;  E so nguyen (muc 7 SOP).
# Bai 18: TP cua hang doi thuong KHONG BAO GIO la P1 (moi P1 thuoc chuoi tan cong).
#
# Khac Bai 14 (co chu dich, de chay dung o MOI gio trong ngay):
#   - T5/B4 dung luat "dang nhap tu dia chi moi" thay vi "ngoai gio"; can cu la LV / OC.
#   - bo F3 (logrotate 00:00); them M1 = beacon cua agent hop le (moi gom su co voi C4).
#   - ten nguoi dung sshd o data.dstuser (nhu Wazuh 4.14 that).
# ============================================================================
import random
import string

from . import docs

PRIO = {("A", "Cao"): 1, ("A", "TB"): 1, ("A", "Thap"): 2,
        ("B", "Cao"): 1, ("B", "TB"): 2, ("B", "Thap"): 3,
        ("C", "Cao"): 3, ("C", "TB"): 3, ("C", "Thap"): 4}

# luat "san xuat" cua cac ticket ghi thang vao indexer (khong trung dai luat cua SV 100330-100349)
R = {
    "ssh_fail":   ("5760", 5, "sshd: authentication failed.", ["syslog", "sshd", "authentication_failed"]),
    "ssh_ok":     ("5715", 3, "sshd: authentication success.", ["syslog", "sshd", "authentication_success"]),
    "ssh_brute":  ("5763", 10, "sshd: brute force trying to get access to the system. Authentication failed.",
                   ["syslog", "sshd", "authentication_failures"]),
    "new_src":    ("100111", 10, "Dang nhap thanh cong tu dia chi chua tung thay voi tai khoan nay",
                   ["syslog", "sshd", "authentication_success", "soc_login"]),
    "dns":        ("100121", 12, "Nghi tuon du lieu qua DNS (subdomain dai)", ["dns", "soc_exfil"]),
    "dns_q":      ("100120", 3, "DNS query", ["dns"]),
    "revshell":   ("100131", 12, "Nghi reverse shell (ten tien trinh khop mau)", ["audit", "soc_process"]),
    "audit_exec": ("100130", 3, "Audit: thuc thi chuong trinh", ["audit"]),
    "beacon":     ("100141", 13, "Tien trinh nguy trang ket noi ra ngoai dinh ky", ["netmon", "soc_c2"]),
    "conn":       ("100140", 3, "netmon: ket noi ra ngoai", ["netmon"]),
}

FAMILY = {"T1": "ssh", "B1": "ssh", "X1B1": "ssh", "T5": "login", "B4": "login",
          "T4": "dns", "F1": "dns", "F2": "proc", "M1": "beacon"}
LABEL = {"T1": 1, "T5": 1, "T4": 1, "X1B1": 1, "B1": 2, "B4": 2, "F1": 3, "F2": 3, "M1": 3}


def _alert(key, ts, host, data, full_log, decoder, program=None, mitre=None):
    rid, lv, desc, groups = R[key]
    return docs.alert(ts, host, rid, lv, desc, groups, data=data, full_log=full_log, decoder=decoder,
                      program=program, mitre=mitre)


def _b32(rng, n):
    return "".join(rng.choice(string.ascii_lowercase + "234567") for _ in range(n))


# =============================================================== PLAN (luc seed)
def plan_T1(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    victim = w.take_staff()
    return {"pattern": "T1", "host": host, "src": w.new_ext_ip(), "victim": victim,
            "users": [w.rng.choice(w.staff)["user"] for _ in range(rng.randint(15, 25))] + [victim["user"]],
            "n_fail": rng.randint(40, 80), "V": 1, "P": PRIO[("B", w.crit(host))], "E": victim["id"]}


def plan_X1B1(w, ctx, rng):
    host = w.pick_host(["TB"], exclude=("web-shop",))
    _ensure_scanner(w, ctx)
    victim = w.take_staff()
    kind = rng.choice(["a", "b", "c"])
    t0 = ctx.t0
    if kind == "a":       # CHG ket thuc >= 2h truoc canh bao
        ctx.change([host], "vuln_scan", t0 - 6 * 3600, t0 - 2.5 * 3600, ip=w.ip("scan-01"), actor="Security")
    elif kind == "b":     # CHG ghi IP may quet KHAC
        ctx.change([host], "vuln_scan", t0 - 3600, t0 + 4 * 3600, ip=w.ip("scan-02"), actor="Security")
    else:                 # CHG da huy
        ctx.change([host], "vuln_scan", t0 - 3600, t0 + 4 * 3600, ip=w.ip("scan-01"), status="cancelled", actor="Security")
    return {"pattern": "X1B1", "host": host, "src": w.ip("scan-01"), "victim": victim, "x1": kind,
            "users": [w.rng.choice(w.staff)["user"] for _ in range(rng.randint(15, 25))] + [victim["user"]],
            "n_fail": rng.randint(40, 80), "V": 1, "P": PRIO[("B", "TB")], "E": victim["id"]}


def plan_B1(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    _ensure_scanner(w, ctx)
    n = ctx.change([host], "vuln_scan", ctx.t0 - 1800, ctx.t0 + 4 * 3600, ip=w.ip("scan-01"), actor="Security",
                   description="Quet lo hong dinh ky")
    return {"pattern": "B1", "host": host, "src": w.ip("scan-01"),
            "users": [w.rng.choice(w.staff)["user"] for _ in range(rng.randint(15, 25))],
            "n_fail": rng.randint(40, 80), "V": 2, "P": 4, "E": n}


def plan_T5(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    st = w.take_staff()
    ctx.leave(st, ctx.t0 - 2 * 86400, ctx.t0 + 3 * 86400)
    return {"pattern": "T5", "host": host, "user": st, "src": w.new_ext_ip(), "home": _home_ip(w, rng),
            "V": 1, "P": PRIO[("B", w.crit(host))], "E": st["id"]}


def plan_B4(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    st = w.take_staff()
    n = ctx.oncall(st, [host, "jump-01"], ctx.t0 - 3600, ctx.t0 + 8 * 3600)
    # moi: cung nguoi, dung gio nhung KHONG gom may nay
    other = rng.choice([h for h in w.hosts_by_crit("TB") if h != host])
    ctx.oncall(st, [other], ctx.t0 + 9 * 3600, ctx.t0 + 17 * 3600)
    return {"pattern": "B4", "host": host, "user": st, "src": "10.250.%d.%d" % (rng.randint(1, 9), rng.randint(11, 249)),
            "home": _home_ip(w, rng), "V": 2, "P": 4, "E": n}


def plan_T4(w, ctx, rng):
    host = w.pick_host(["Thap"], exclude=("web-staging", "print-01"))
    dom = "%s.%s" % ("".join(rng.choice("bcdfghklmnpqrstvz") for _ in range(7)), rng.choice(["net", "info", "top"]))
    return {"pattern": "T4", "host": host, "domain": dom, "n": rng.randint(120, 200),
            "V": 1, "P": PRIO[("A", "Thap")], "E": w.octet(w.ip(host))}


def plan_F1(w, ctx, rng):
    host = w.pick_host(["Thap"])
    vendor, dom = w.av
    hosts = [h for h in w.hosts if h.startswith("ws-")] + [host]
    n = ctx.service(sorted(set(hosts)), "Phan mem diet virus %s (tra cuu danh tieng file qua DNS)" % vendor, dom)
    return {"pattern": "F1", "host": host, "domain": dom, "others": [h for h in hosts if h != host][:3],
            "V": 3, "P": 4, "E": n}


def plan_F2(w, ctx, rng):
    host = w.pick_host(["TB"], exclude=("web-shop",))
    proc, path = w.mon
    n = ctx.service([h for h in w.hosts if not h.startswith("ws-")], "Agent giam sat %s" % proc, path)
    return {"pattern": "F2", "host": host, "path": path, "V": 3, "P": 4, "E": n}


def plan_M1(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    vendor_ip = w.new_ext_ip()
    path = rng.choice(["/opt/netdata/bin/netdata", "/opt/veeam/bin/veeamtransport", "/usr/sbin/telemetryd"])
    n = ctx.service([host], "Agent gui so lieu van hanh ve nha cung cap (moi 30 giay)", "%s -> %s:443" % (path, vendor_ip))
    return {"pattern": "M1", "host": host, "dst": vendor_ip, "path": path, "V": 3, "P": 4, "E": n}


PLANNERS = {"T1": plan_T1, "X1B1": plan_X1B1, "B1": plan_B1, "T5": plan_T5, "B4": plan_B4,
            "T4": plan_T4, "F1": plan_F1, "F2": plan_F2, "M1": plan_M1}


def _ensure_scanner(w, ctx):
    for name in ("scan-01", "scan-02"):
        if name not in w.hosts:
            w.hosts[name] = {"name": name, "role": "may quet lo hong", "crit": "TB", "ip": w._new_ip(w.subnet_srv)}
            w.ip2host[w.hosts[name]["ip"]] = name
            ctx.asset(name)


def _home_ip(w, rng):
    return "%s.%d" % (w.subnet_ws, rng.randint(11, 249))


# =============================================================== chon co cau hang doi
def compose(rng, n=9, waves=(4, 3, 2)):
    """Chon n mau + chia dot. Rang buoc (kich ban 5.1 + chong suy luan cau truc cua Bai 14 muc 4.4)."""
    for _ in range(500):
        n_tp = rng.choice([3, 4])
        tps = [rng.choice(["T1", "T5", "T4"]) for _ in range(n_tp)]
        if rng.random() < 0.5:
            tps[rng.randrange(n_tp)] = "X1B1"
        rest = ["M1"] + [rng.choice(["B1", "B4", "F1", "F2"]) for _ in range(n - n_tp - 1)]
        pats = tps + rest
        labels = [LABEL[p] for p in pats]
        if labels.count(2) < 2 or labels.count(3) < 2:
            continue
        fam = {}
        for p in pats:
            fam.setdefault(FAMILY[p], []).append(LABEL[p])
        if not any(len(v) == 1 for v in fam.values()):                       # (a)
            continue
        if not any(max(v.count(x) for x in set(v)) >= 2 for v in fam.values()):   # (b)
            continue
        rng.shuffle(pats)
        out, i = [], 0
        for wv, size in enumerate(waves):
            grp = pats[i:i + size]
            i += size
            if all(LABEL[p] == 1 for p in grp):
                break
            out.append(grp)
        else:
            return out
    raise RuntimeError("khong dung duoc hang doi thoa rang buoc")


# =============================================================== RENDER (luc phat)
def render(plan, ts, w, rng):
    """-> (ticket_doc_khong_INC, [evidence_docs]). Moi bang chung co timestamp <= ts."""
    return RENDER[plan["pattern"]](plan, ts, w, rng)


def _ssh_lines(host, src, users, n, t_end, rng, success_user=None):
    out, t = [], t_end - rng.randint(300, 900)
    step = (t_end - t) / max(n, 1)
    for k in range(n):
        u = rng.choice(users)
        tt = t + k * step + rng.random()
        line = "%s %s sshd[%d]: Failed password for %s from %s port %d ssh2" % (
            docs.syslog_ts(tt), host, rng.randint(1000, 60000), u, src, rng.randint(30000, 60000))
        out.append(_alert("ssh_fail", tt, host, {"srcip": src, "dstuser": u}, line, "sshd", "sshd", ["T1110"]))
    if success_user:
        tt = t_end - rng.randint(5, 40)
        line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
            docs.syslog_ts(tt), host, rng.randint(1000, 60000), success_user, src, rng.randint(30000, 60000))
        out.append(_alert("ssh_ok", tt, host, {"srcip": src, "dstuser": success_user}, line, "sshd", "sshd", ["T1078"]))
    return out


def r_ssh(plan, ts, w, rng):
    victim = plan.get("victim")
    ev = _ssh_lines(plan["host"], plan["src"], plan["users"], plan["n_fail"], ts - 60, rng,
                    success_user=victim["user"] if victim else None)
    tk = _alert("ssh_brute", ts, plan["host"], {"srcip": plan["src"]},
                "%s %s sshd: brute force from %s" % (docs.syslog_ts(ts), plan["host"], plan["src"]), "sshd", "sshd", ["T1110"])
    return tk, ev


def r_login(plan, ts, w, rng):
    host, u = plan["host"], plan["user"]["user"]
    ev = []
    for d in range(1, 8):                     # baseline 7 ngay: chi tu 1 IP noi bo, gio hanh chinh
        tt = ts - d * 86400 + rng.randint(-3 * 3600, 3 * 3600)
        line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
            docs.syslog_ts(tt), host, rng.randint(1000, 60000), u, plan["home"], rng.randint(30000, 60000))
        ev.append(_alert("ssh_ok", tt, host, {"srcip": plan["home"], "dstuser": u}, line, "sshd", "sshd"))
    line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
        docs.syslog_ts(ts - 20), host, rng.randint(1000, 60000), u, plan["src"], rng.randint(30000, 60000))
    ev.append(_alert("ssh_ok", ts - 20, host, {"srcip": plan["src"], "dstuser": u}, line, "sshd", "sshd"))
    tk = _alert("new_src", ts, host, {"srcip": plan["src"], "dstuser": u}, line, "sshd", "sshd", ["T1078"])
    return tk, ev


def _dns(ts, client, q, src_ip):
    """Truy van DNS cua may 'client' (ghi o dns-01, IP nguon = src_ip)."""
    line = "%s %s dnsmasq[%d]: query[A] %s from %s" % (docs.syslog_ts(ts), "dns-01", 700, q, src_ip)
    return _alert("dns_q", ts, "dns-01", {"srcip": src_ip, "query": q}, line, "dnsmasq", "dnsmasq")


def r_T4(plan, ts, w, rng):
    host, ip = plan["host"], w.ip(plan["host"])
    t = ts - 1200
    ev = [_dns(t + k * 1200 / plan["n"], host, "%s.%s" % (_b32(rng, rng.randint(40, 60)), plan["domain"]), ip)
          for k in range(plan["n"])]
    tk = _alert("dns", ts, host, {"srcip": ip, "query": "*.%s" % plan["domain"]}, "dns exfil heuristic", "dnsmasq", mitre=["T1048"])
    return tk, ev


def r_F1(plan, ts, w, rng):
    vendor, dom = w.av
    ev = []
    for h in [plan["host"]] + plan["others"]:
        for k in range(rng.randint(15, 30)):
            ev.append(_dns(ts - rng.randint(60, 1800), h, "%s.%s" % ("".join(rng.choice("0123456789abcdef") for _ in range(48)), dom), w.ip(h)))
    tk = _alert("dns", ts, plan["host"], {"srcip": w.ip(plan["host"]), "query": "*.%s" % dom}, "dns exfil heuristic", "dnsmasq", mitre=["T1048"])
    return tk, ev


def r_F2(plan, ts, w, rng):
    host = plan["host"]
    ev = []
    for k in range(rng.randint(3, 6)):
        tt = ts - rng.randint(30, 900)
        ev.append(_alert("audit_exec", tt, host, {"audit": {"exe": plan["path"], "command": plan["path"].rsplit("/", 1)[1]}},
                         "type=EXECVE exe=%s" % plan["path"], "auditd"))
    tk = _alert("revshell", ts, host, {"audit": {"exe": plan["path"]}}, "type=EXECVE exe=%s" % plan["path"], "auditd", mitre=["T1059"])
    return tk, ev


def netmon(ts, host, dst, port, proc, src_ip):
    line = "%s %s netmon: conn dst=%s port=%d proc=%s" % (docs.syslog_ts(ts), host, dst, port, proc)
    return _alert("conn", ts, host, {"srcip": src_ip, "dstip": dst, "dstport": str(port), "process": {"name": proc}}, line, "netmon", "netmon")


def r_M1(plan, ts, w, rng):
    host = plan["host"]
    ev = [netmon(ts - 30 * k, host, plan["dst"], 443, plan["path"], w.ip(host)) for k in range(1, rng.randint(25, 40))]
    tk = _alert("beacon", ts, host, {"srcip": w.ip(host), "dstip": plan["dst"], "dstport": "443", "process": {"name": plan["path"]}},
                "periodic outbound", "netmon", mitre=["T1071"])
    return tk, ev


RENDER = {"T1": r_ssh, "X1B1": r_ssh, "B1": r_ssh, "T5": r_login, "B4": r_login,
          "T4": r_T4, "F1": r_F1, "F2": r_F2, "M1": r_M1}


def plan_queue(w, ctx, rng):
    """-> list cac dot, moi dot la list plan (da chot dap an)."""
    return [[dict(PLANNERS[p](w, ctx, random.Random(rng.random())), family=FAMILY[p]) for p in grp]
            for grp in compose(rng)]
