#!/usr/bin/env python3
# ============================================================================
# test_socq.py - kiem bat bien cua thu vien socq tren nhieu seed (chay truoc moi commit):
#   python3 -m socq.test_socq [so_seed]        (dung tu thu muc labs/_shared)
# Moi bat bien gan voi mot dong cua kich ban Bai 18 (muc 5.1, 9.2) hoac SOP Bai 14.
# ============================================================================
import datetime
import json
import re
import sys
import time

from . import ca, cases, chain, docs, families

RE_WEB = re.compile(r'^\w{3} [ \d]\d \d\d:\d\d:\d\d web-shop nginx: \S+ - - \[[^\]]+\] "(GET|POST) \S+ HTTP/1.1" \d{3} \d+ ')
RE_CONN = re.compile(r'^\w{3} [ \d]\d \d\d:\d\d:\d\d \S+ kernel: \[\d+\.\d+\] ACCEPT IN=eth0 .* SRC=\S+ DST=\S+ .*PROTO=TCP SPT=\d+ DPT=\d+ ')


def parse_iso(s):
    return datetime.datetime.fromisoformat(s).timestamp()


def ctx_match(c, plan, ts):
    """Ban ghi ngu canh KHOP DU theo SOP muc 4 cho ticket nay (-> danh sach so ID khop)."""
    w = c.w
    out = []
    pat = plan["pattern"]
    for r in c.records["ctx-changes"] + c.records["ctx-hr"] + c.records["ctx-assets"]:
        if r.get("type") == "asset":
            continue
        ok_status = r["status"] == "approved"
        if pat in ("T1", "X1B1", "B1") and r["id"].startswith("CHG") and r["kind"] == "vuln_scan":
            if plan["host"] in r["host"] and plan["src"] in r.get("ip", []) and ok_status and \
                    parse_iso(r["start"]) <= ts <= parse_iso(r["end"]):
                out.append(int(r["id"].split("-")[1]))
        if pat in ("T5", "B4") and r["id"].startswith("OC"):
            if plan["host"] in r["host"] and r["user"] == plan["user"]["user"] and ok_status and \
                    parse_iso(r["start"]) <= ts <= parse_iso(r["end"]):
                out.append(int(r["id"].split("-")[1]))
        if pat in ("F1", "F2", "M1") and r["id"].startswith("SVC") and ok_status and plan["host"] in r["host"]:
            m = r["match"]
            if (pat == "F1" and m == plan["domain"]) or (pat == "F2" and m == plan["path"]) or \
                    (pat == "M1" and plan["path"] in m and plan["dst"] in m):
                out.append(int(r["id"].split("-")[1]))
    return out


def check(seed):
    t_ref = 1795500000 + seed * 977
    s = ca.build(seed, t_ref)
    w, cx, ev, ans = s["world"], s["ctx"], s["events"], s["answers"]
    errs = []
    E = lambda m: errs.append("seed %d: %s" % (seed, m))
    q = [e for e in ev if e["kind"] == "ticket" and e["id"].startswith("Q")]
    # ---- hang doi
    if len(q) != 9:
        E("hang doi co %d ticket" % len(q))
    waves = [[e for e in q if lo <= e["at"] <= hi] for lo, hi in [(0, 0), (25 * 60, 40 * 60), (55 * 60, 70 * 60)]]
    if [len(x) for x in waves] != [4, 3, 2]:
        E("co cau dot %s" % [len(x) for x in waves])
    for i, wv in enumerate(waves):
        if all(ans[e["inc"]]["V"] == 1 for e in wv):
            E("dot %d toan TP" % (i + 1))
    for e in q:
        a = ans[e["inc"]]
        if a["V"] == 1 and a["P"] == 1:
            E("ticket thuong %s la TP P1" % e["inc"])
        if a["V"] in (2, 3) and a["P"] != 4:
            E("BTP/FP %s co P=%s" % (e["inc"], a["P"]))
    pats = [e["pattern"] for e in q]
    if "M1" not in pats:
        E("thieu M1 (moi gom su co)")
    if sum(1 for p in pats if cases.LABEL[p] == 2) < 2 or sum(1 for p in pats if cases.LABEL[p] == 3) < 2:
        E("it hon 2 BTP hoac 2 FP")
    # ---- chuoi
    for k in ("C1", "C2", "C4", "C6"):
        a = ans[s["inc"][k]]
        if (a["V"], a["P"]) != (1, 1):
            E("%s khong phai TP P1" % k)
    p1 = sorted(i for i, a in ans.items() if a["isp1"])
    if p1 != s["sc"]["TICKETS"]:
        E("tap P1 %s != SC1 %s" % (p1, s["sc"]["TICKETS"]))
    at = {e["id"]: e["at"] for e in ev}
    for a, b in [("C1", "C2"), ("C2", "C3"), ("C3", "R-A"), ("C3", "C4"), ("C4", "R-B"), ("R-B", "C5"), ("C5", "C6")]:
        if not at[a] < at[b]:
            E("thu tu %s < %s sai (%s, %s)" % (a, b, at[a], at[b]))
    if not (60 * 60 <= at["C6"] <= 85 * 60):
        E("C6 luc %d'" % (at["C6"] // 60))
    if max(at.values()) > 90 * 60:
        E("su kien sau het ca")
    incs = [e["inc"] for e in ev if e["kind"] == "ticket"]
    if len(set(incs)) != len(incs):
        E("INC trung")
    order = [e["inc"] for e in sorted([e for e in ev if e["kind"] == "ticket" and not e.get("backlog")], key=lambda e: (e["at"], e["id"]))]
    nums = [int(x[4:]) for x in order]
    if nums != sorted(nums):
        E("INC khong tang theo thoi gian")
    bl = [e for e in ev if e.get("backlog")]
    if len(bl) != 1 or int(bl[0]["inc"][4:]) >= min(nums):
        E("ticket ton ca chieu sai")
    # ---- render + ngu canh khop du (SOP muc 4)
    for e in ev:
        if e["kind"] != "ticket":
            continue
        p = s["plans"][e["id"]]
        ts = t_ref + 600 + e["at"]
        rng = ca.event_rng(seed, e["id"])
        tk, evd = (chain.render(e["id"], p, ts, w, rng) if e["id"].startswith("C") else cases.render(p, ts, w, rng))
        tk = docs.ticket(tk, e["inc"])
        json.dumps(tk), json.dumps(evd)
        if tk["predecoder"]["hostname"] != p["host"]:
            E("%s ticket tren may %s != %s" % (e["inc"], tk["predecoder"]["hostname"], p["host"]))
        if any(parse_iso(d["@timestamp"].replace("+0000", "+00:00")) > ts + 1 for d in evd):
            E("%s co bang chung SAU ticket" % e["inc"])
        if e["id"].startswith("Q"):
            m = ctx_match(cx, p, ts)
            a = ans[e["inc"]]
            if a["V"] == 1 and m:
                E("%s TP nhung co ngu canh khop du %s" % (e["inc"], m))
            if a["V"] in (2, 3) and m != [a["E"]]:
                E("%s %s: ngu canh khop %s != E %s" % (e["inc"], p["pattern"], m, a["E"]))
    # ---- dong log that
    rng = ca.event_rng(seed, "live")
    for l in chain.lines_webshell_cmd(t_ref, w, rng) + chain.lines_web_noise(t_ref, w, rng, 30):
        if not RE_WEB.match(l):
            E("dong web sai dinh dang: %s" % l[:90])
    for l in chain.lines_webshell_cmd(t_ref, w, rng):
        if "cmd=" in l or w.webshell not in l or "?" not in l:
            E("lenh webshell sai: %s" % l[:90])
    for l in chain.lines_storm(t_ref, w, rng, 30) + chain.lines_scan(t_ref, w, rng, 30):
        if not RE_CONN.match(l):
            E("dong ket noi sai dinh dang: %s" % l[:90])
    for l in chain.lines_storm(t_ref, w, rng, 50):
        src = re.search(r"SRC=(\S+)", l).group(1)
        if w.ip2host.get(src) not in w.backup_hosts or "DPT=%d " % w.backup_port not in l:
            E("bao khong tu may sao luu/cong CHG")
    bk = cx.records["ctx-changes"]
    chg = [r for r in bk if r["kind"] == "deploy" and r["status"] == "approved" and set(r["host"]) == set(w.backup_hosts)]
    if len(chg) != 1 or str(w.backup_port) not in chg[0]["description"]:
        E("CHG trien khai agent sao luu sai")
    # ---- tap R-A / R-B: nhan khop voi "giai mau" mo phong (oracle) - luat mau spike S-B
    ra_re = re.compile(r'"GET (%s[^?" ]*\.(?:php|phtml|phar)\?\S*) ' % re.escape(w.upload_dir))
    for hidden in (False, True):
        fam = families.build(w, seed, hidden)
        for sc in fam["ra"]:
            hit = any(m and not m.group(1).startswith(w.upload_dir + w.approved_script) for m in (ra_re.search(l) for l in sc["lines"]))
            if hit != (sc["label"] == "mal"):
                E("R-A %s (%s, an=%s): oracle=%s" % (sc["id"], sc["variant"], hidden, hit))
        for sc in fam["rb"]:
            dst = set()
            for l in sc["lines"]:
                src = re.search(r"SRC=(\S+)", l).group(1)
                port = int(re.search(r"DPT=(\d+)", l).group(1))
                if w.ip2host.get(src) in w.backup_hosts and port == w.backup_port:
                    continue                                  # ngoai le co can cu: may CHG + cong CHG
                dst.add(re.search(r"DST=(\S+)", l).group(1))
            hit = len(dst) >= 8
            if hit != (sc["label"] == "mal"):
                E("R-B %s (%s, an=%s): %d dich" % (sc["id"], sc["variant"], hidden, len(dst)))
        if hidden:
            vs = {x["variant"] for x in fam["rb"]}
            for need in ("quet-ssh", "quet-ssh-tu-web-shop", "may-sao-luu-sai-cong", "may-ngoai-CHG-dung-cong-agent", "quet-tu-web-shop"):
                if need not in vs:
                    E("tap an R-B thieu %s" % need)
    return errs


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    t = time.time()
    errs = []
    for seed in range(1, n + 1):
        try:
            errs += check(seed)
        except Exception as ex:  # noqa: BLE001
            import traceback
            errs.append("seed %d: LOI %r\n%s" % (seed, ex, traceback.format_exc()[-600:]))
    for e in errs[:40]:
        print(e)
    print("%d seed, %d loi, %.1fs" % (n, len(errs), time.time() - t))
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
