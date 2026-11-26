#!/usr/bin/env python3
# ============================================================================
# grade18.py - cham phia siem cua Bai 18 (root). Ba lenh:
#   rules [settle]  phat lai tap AN R-A/R-B tren luat DANG NAP -> /root/.bai18/rules.txt
#                   (grade-bai18.path goi khi local_rules.xml doi; doi analysisd khoi dong SAU lan sua cuoi)
#   live            doc alerts.json trong [T0, T0+90'] -> duong cong bao, C3_SEEN, C5_SEEN, moc R-A no that
#   print [--all]   (prestop) dap an theo THU TU PHAT (GT_*_k), moc phat tung ticket, rules.txt, live
#                   CHI SAU HET CA (truoc do: SHIFT_RUNNING); --all = phat trien
# Dap an chi nam trong output nay (SV khong doc duoc siem). Thu tu k = thu tu ticket da phat, giong het
# thu tu ma defender in (doc shift.json) -> goals.config so tung cap bang matchany + result._gt_* (D3).
# ============================================================================
import datetime, fcntl, hashlib, json, os, subprocess, sys, time
import xml.etree.ElementTree as ET

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
import replay  # noqa: E402
from wzapi import Wazuh, WazuhError  # noqa: E402
from socq import families, shift  # noqa: E402

ST = "/root/.bai18"
PUB = "/srv/shiftd"
RULES = "/var/ossec/etc/rules/local_rules.xml"
ALERTS = "/var/ossec/logs/alerts/alerts.json"
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"
RANGES = replay.parse_ranges(families.RANGES)          # ra, rb
RB_RECALL_GATE = 0.9
STORM_EXPECTED = 20          # canh bao R-B/phut khi bao CHUA xu ly (VM: 21-25) - moc 'giam 80%'


def canon(nums):
    """Tap so -> so nguyen duy nhat (giong bai18-thu-thap tren defender): 1 + moi so dem 0 thanh 5 chu so."""
    v = sorted({int(x) for x in nums if str(x).strip().isdigit()})
    return int("1" + "".join("%05d" % x for x in v)) if v else 0


def crc(text):
    import zlib
    return zlib.crc32((text or "").strip().lower().encode())


def write_atomic(path, text):
    open(path + ".tmp", "w").write(text)
    os.replace(path + ".tmp", path)


def rules_sha():
    try:
        return hashlib.sha256(open(RULES, "rb").read()).hexdigest()[:16]
    except OSError:
        return "none"


def static_check():
    """Dem luat level>=10 moi dai, MITRE; R-A 'trien khai' = co >=1 luat level>=10 trong dai R-A."""
    try:
        root = ET.fromstring("<root>" + open(RULES, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return False, {f: 0 for f in RANGES}
    ok, count = True, {f: 0 for f in RANGES}
    for r in root.iter("rule"):
        try:
            rid, lvl = int(r.get("id", "0")), int(r.get("level", "0"))
        except ValueError:
            continue
        for f, (lo, hi) in RANGES.items():
            if lo <= rid <= hi and lvl >= 10:
                count[f] += 1
                if r.find("mitre") is None:
                    ok = False
    return ok, count


def analysisd_started():
    try:
        pid = subprocess.run(["pidof", "wazuh-analysisd"], capture_output=True, text=True).stdout.split()[0]
        return os.stat("/proc/" + pid).st_ctime
    except (IndexError, OSError):
        return 0


def wait_rules_loaded(wait=300):
    t0 = time.time()
    while time.time() - t0 < wait:
        mt = os.path.getmtime(RULES) if os.path.exists(RULES) else 0
        st = analysisd_started()
        if st and st > mt:
            if time.time() - st < 30:
                time.sleep(10)
            return True
        time.sleep(5)
    return False


def do_rules(settle=20):
    lockf = open(os.path.join(ST, ".lock"), "w")
    fcntl.flock(lockf, fcntl.LOCK_EX)
    time.sleep(settle)
    wait_rules_loaded()
    record_history()
    out = ["RULES_SHA=%s" % rules_sha(), "GRADED_AT=%d" % int(time.time())]
    api = Wazuh("https://127.0.0.1:55000", TOOL_USER, TOOL_PASS)
    try:
        for i in range(24):
            try:
                api.login()
                break
            except WazuhError:
                if i == 23:
                    raise
                time.sleep(5)
        res = replay.run(replay.ApiEngine(api), replay.load_set(os.path.join(ST, "hidden.jsonl")), RANGES)
    except Exception as e:  # noqa: BLE001
        out.append("GRADE_ERROR=%s" % str(e)[:120].replace("\n", " "))
        write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")
        return
    valid, count = static_check()
    out.append("RULES_VALID=%s" % ("Y" if valid else "N"))
    for f, r in res.items():
        u = f.upper()
        out.append("%s_TP=%d %s_FP=%d %s_FN=%d %s_NRULES=%d" % (u, r["tp"], u, r["fp"], u, r["fn"], u, count[f]))
        out.append("%s_P100=%d %s_R100=%d" % (u, round(100 * r["precision"]), u, round(100 * r["recall"])))
    rb = res.get("rb")
    if rb and rb["recall"] >= RB_RECALL_GATE and count["rb"] > 0:
        out.append("RB_NOT_BLIND")
    if count["ra"] > 0:
        out.append("RA_LOADED")
    write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")


KHUNG = os.path.join(HERE, "local_rules_khung.xml")


def rb_signature(path):
    """Chuoi chuan hoa cua cac luat dai R-B (100340-100349) - de biet SV da sua R-B so voi khung chua."""
    try:
        root = ET.fromstring("<root>" + open(path, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return None
    sig = []
    for r in root.iter("rule"):
        try:
            rid = int(r.get("id", "0"))
        except ValueError:
            continue
        if 100340 <= rid <= 100349:
            sig.append(" ".join(ET.tostring(r, encoding="unicode").split()))
    return "|".join(sorted(sig))


def record_history():
    """Moi lan cham: ghi (mtime file luat, sha, R-B da sua?) - live dung de biet C5 co con THAY sau khi SV sua R-B."""
    try:
        # moc HIEU LUC = luc analysisd (da nap file nay) khoi dong; goi SAU wait_rules_loaded
        mt = int(max(os.path.getmtime(RULES), analysisd_started()))
    except OSError:
        return
    sha = rules_sha()
    p = os.path.join(ST, "rules-history")
    if os.path.exists(p) and any(l.split()[1] == sha for l in open(p) if len(l.split()) > 1):
        return
    rbmod = "Y" if rb_signature(RULES) != rb_signature(KHUNG) else "N"
    with open(p, "a") as f:
        f.write("%d %s RBMOD=%s RA=%s\n" % (mt, sha, rbmod, "Y" if ra_alert_rules(RULES) else "N"))


def ra_alert_rules(path):
    """So luat CANH BAO (level >= 10) trong dai R-A cua file luat."""
    try:
        root = ET.fromstring("<root>" + open(path, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return 0
    n = 0
    for r in root.iter("rule"):
        try:
            if 100330 <= int(r.get("id", "0")) <= 100339 and int(r.get("level", "0")) >= 10:
                n += 1
        except ValueError:
            pass
    return n


def first_ra_deploy():
    """Lan nap THANH CONG dau tien co luat canh bao dai R-A (quy uoc P5)."""
    p = os.path.join(ST, "rules-history")
    if not os.path.exists(p):
        return None
    ts = [int(l.split()[0]) for l in open(p) if " RA=Y" in l]
    return min(ts) if ts else None


def first_rb_fix():
    p = os.path.join(ST, "rules-history")
    if not os.path.exists(p):
        return None
    ts = [int(l.split()[0]) for l in open(p) if "RBMOD=Y" in l]
    return min(ts) if ts else None


def load_plan():
    return json.load(open(os.path.join(ST, "plan.json")))


def do_live():
    """Tu alerts.json: so canh bao dai R-B moi phut, phut khoanh vung bao (giam >= 80%), C3/C5 thay that."""
    st = shift.State(ST, PUB)
    t0 = st.t0()
    if not t0:
        return ["LIVE_ERROR=chua co T0"]
    plan = load_plan()
    at = {e["id"]: e["at"] for e in plan["events"]}
    end = t0 + at["END"]
    import socq.ca as ca  # noqa: E402
    seed = int(open(os.path.join(ST, "seed")).read())
    w = ca.build(seed, int(open(os.path.join(ST, "t_ref")).read()))["world"]
    ws_ip, att = w.ip("web-shop"), w.attacker_ip
    per_min, c3_first, c5_first = {}, None, None
    t_fix = first_rb_fix()          # C5 "con thay" chi co nghia SAU khi SV sua R-B (luat khung tu no da bat C5)
    try:
        f = open(ALERTS)
    except OSError:
        return ["LIVE_ERROR=khong doc duoc alerts.json"]
    for line in f:
        if '"1003' not in line:                  # loc nhanh: chi luat 1003xx
            continue
        try:
            a = json.loads(line)
        except ValueError:
            continue
        rid, lvl = int(a["rule"]["id"]), int(a["rule"]["level"])
        if lvl < 10:
            continue
        try:
            ts = datetime.datetime.strptime(a["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z").timestamp()
        except (KeyError, ValueError):
            continue
        if not (t0 <= ts <= end):
            continue
        data = a.get("data") or {}
        if 100340 <= rid <= 100349:
            m = int((ts - t0) // 60)
            per_min[m] = per_min.get(m, 0) + 1
            if data.get("srcip") == ws_ip and t_fix and ts >= t_fix and c5_first is None:
                c5_first = ts
        if 100330 <= rid <= 100339 and data.get("srcip") == att and w.webshell in (data.get("url") or ""):
            c3_first = c3_first or ts
    out = ["STORM_CURVE=%s" % ",".join("%d:%d" % kv for kv in sorted(per_min.items()))]
    m0 = int(at["R-B"] // 60)
    base = [per_min.get(m, 0) for m in range(m0, m0 + 3)]
    peak = max(base) if base else 0
    contain = None
    end_min = int(at["END"] // 60)
    # moc so sanh = max(dinh do duoc, toc do bao CHUA xu ly): SV sua R-B NGAY khi bao vua bat dau -> dinh
    # do duoc nho, khong duoc coi la "khong co bao" (gap tren VM 27/11: dinh 9, sua sau 26s)
    ref = max(peak, STORM_EXPECTED)
    for m in range(m0 + 1, end_min - 1):              # can 2 phut lien tiep TRUOC het ca
        if all(per_min.get(x, 0) <= 0.2 * ref for x in (m, m + 1)):
            contain = m
            break
    # phut THEO CA THAT (che do nhanh chia moc cho scale) -> nguong SOP 10'/20'/30' dung chung
    sc = float(plan.get("scale") or 1.0)
    mn = lambda sec: int(round(sec / 60.0 / sc))  # noqa: E731
    out.append("STORM_PEAK=%d" % peak)
    if contain is not None:
        out.append("RB_CONTAIN_MIN=%d" % round((contain - m0) / sc))
    if c3_first:
        out.append("C3_SEEN")
        out.append("C3_FIRST_MIN=%d" % mn(c3_first - t0))
    if t_fix:
        out.append("RB_FIX_MIN=%d" % mn(t_fix - t0))
        out.append("RB_FIX_REL=%d" % mn(t_fix - (t0 + at["R-B"])))
    t_ra = first_ra_deploy()
    if t_ra:
        out.append("RA_DEPLOY_REL=%d" % mn(t_ra - (t0 + at["R-A"])))
    if t_ra and t_ra <= end:
        out.append("GATE_RA_DEPLOYED")
    if c5_first:
        out.append("C5_SEEN")
    # siem tat giua ca (stoplab) -> luong that bi hong: khong tinh moc khoanh vung theo duong cong bao
    # LIVE_GAP = lich-ca khoi dong lai (siem tat/khoi dong lai) trong khoang [R-B, het ca]
    restarts, gap = 0, False
    try:
        base_day = time.mktime(time.localtime(t0)[:3] + (0, 0, 0, 0, 0, -1))
        for l in open(os.path.join(ST, "lich-ca.log")):
            if "bat dau: T0=%d " % t0 not in l:
                continue
            restarts += 1
            h, mi, se = (int(x) for x in l[:8].split(":"))
            ts = base_day + h * 3600 + mi * 60 + se
            if ts < t0 - 60:
                ts += 86400                                   # qua nua dem
            if restarts > 1 and t0 + at["R-B"] - 60 <= ts <= end + 60:
                gap = True
    except (OSError, ValueError):
        pass
    out.append("LICH_CA_RESTARTS=%d" % max(0, restarts - 1))
    if gap:
        out.append("LIVE_GAP")
    return out


def giu_cho():
    """Gia tri giu cho cho MOI result GROUP cua goals.config: Labtainers LOI grader neu result thieu
    (gap tren VM). 999999 khong bao gio trung bai lam (defender dung 999998 cho o bo trong)."""
    X = 999999
    for k in range(1, 14):
        print("GT_INC_%d=%d GT_V_%d=%d GT_P_%d=%d GT_E_%d=%d GT_ISP1_%d=%d" % (k, X, k, X, k, X, k, X, k, X))
    print("GT_SC_TK_C=%d GT_SC_HOST_C=%d GT_SC_HOSTIP_C=%d GT_SC_GIAI_DOAN=%d" % (X, X, X, X))
    print("GT_SC_T1=%d GT_SC_T2=%d GT_SC_T3=%d GT_SC_T4=%d" % (X, X, X, X))
    print("GT_SC_ASSET=%d GT_SC_STAGE=%d GT_SC_MITRE_C=%d GT_SC_IOC_C2=%d GT_SC_DE_XUAT_C=%d" % (X, X, X, X, X))


CACHE = os.path.join(ST, "print.cache")


def do_print(all_=False):
    print("SIEM18_MARKER")
    if not os.path.exists(os.path.join(ST, "seeded")):
        print("SEED_MISSING")
        return
    print(open(os.path.join(ST, "seeded")).read().strip())
    plan = load_plan()
    st = shift.State(ST, PUB)
    t0 = st.t0()
    dn = st.done()
    print("T0=%s" % t0)
    print("SHIFT_END=%s" % ("Y" if "END" in dn else "N"))
    if "END" not in dn and not all_:
        # TRONG CA: khong in dap an / ket qua tap an (checkwork giua ca KHONG duoc thanh "may do dap an")
        print("SHIFT_RUNNING")
        giu_cho()
        print("PRINT_DONE")
        return
    # dap an theo thu tu PHAT (k = 1..n); cung thu tu ma defender in
    rel = sorted([(dn[e["id"]], e["inc"]) for e in plan["events"] if e["kind"] == "ticket" and e["id"] in dn])
    for k, (ts, inc) in enumerate(sorted(rel, key=lambda x: (x[0], x[1])), 1):
        a = plan["answers"][inc]
        print("GT_INC_%d=%s REL_%d=%d" % (k, inc[4:], k, ts))
        print("GT_V_%d=%d GT_P_%d=%d GT_E_%d=%d GT_ISP1_%d=%d" % (k, a["V"], k, a["P"], k, a["E"], k, a["isp1"]))
    print("GT_N=%d" % len(rel))
    sc = plan["sc"]
    print("GT_SC_TICKETS=%s" % ",".join(t[4:] for t in sc["TICKETS"]))
    print("GT_SC_HOST=%s GT_SC_GIAI_DOAN=%d GT_SC_ASSET=%d GT_SC_IOC_C2=%d" % (sc["HOST"], sc["GIAI_DOAN"], sc["ASSET_LEVEL"], sc["IOC_C2"]))
    print("GT_SC_MITRE=%s GT_SC_DE_XUAT=%s" % (",".join(sc["MITRE"]), ",".join(str(x) for x in sc["DE_XUAT"])))
    # ma so nguyen chuan hoa (goals chi so integer_equal): tap so -> "1"+so dem 0 noi tiep ; ten may -> crc32
    import socq.ca as ca  # noqa: E402
    w = ca.build(int(open(os.path.join(ST, "seed")).read()), int(open(os.path.join(ST, "t_ref")).read()))["world"]
    print("GT_SC_TK_C=%d" % canon(t[4:] for t in sc["TICKETS"]))
    for i, t in enumerate(sc["TICKETS"], 1):
        print("GT_SC_T%d=%s" % (i, t[4:]))
    print("GT_SC_HOST_C=%d GT_SC_HOSTIP_C=%d" % (crc(sc["HOST"]), crc(w.ip(sc["HOST"]))))
    print("GT_SC_STAGE=%d" % {"A": 1, "B": 2, "C": 3}[sc["STAGE"]])
    print("GT_SC_MITRE_C=%d GT_SC_DE_XUAT_C=%d" % (canon(sc["MITRE"]), canon(sc["DE_XUAT"])))
    for k in ("R-A", "R-B"):
        if k in dn:
            print("REL_%s=%d" % (k.replace("-", ""), dn[k]))
    p = os.path.join(ST, "rules.txt")
    if os.path.exists(p):
        txt = open(p).read()
        print(txt.strip())
        if "RULES_SHA=%s" % rules_sha() not in txt:
            print("RULES_STALE")
    try:
        for line in do_live():
            print(line)
    except Exception as e:  # noqa: BLE001
        print("LIVE_ERROR=%s" % str(e)[:100].replace("\n", " "))
    print("PRINT_DONE")          # prestop chi tin ban in co dong nay (khong bi cat giua chung)


MAU_XML = """<group name="bai18,">
  <rule id="100330" level="12">
    <if_sid>31100</if_sid>
    <url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>
    <description>R-A: goi script trong thu muc upload co tham so</description>
    <mitre><id>T1505.003</id></mitre>
  </rule>
  <rule id="100331" level="0">
    <if_sid>100330</if_sid>
    <url type="pcre2">^%(script)s\\?</url>
    <description>R-A ngoai le: script da duyet SVC-%(svc)s</description>
  </rule>
  <rule id="100342" level="1">
    <if_sid>4100</if_sid>
    <description>Su kien ket noi (dem cho R-B)</description>
  </rule>
  <rule id="100341" level="0">
    <if_sid>100342</if_sid>
    <list field="srcip" lookup="address_match_key">etc/lists/sao-luu-hosts</list>
    <list field="dstport" lookup="match_key">etc/lists/sao-luu-ports</list>
    <description>R-B ngoai le: agent sao luu CHG-%(chg)s (may nguon VA cong)</description>
  </rule>
  <rule id="100340" level="10" frequency="8" timeframe="120">
    <if_matched_sid>100342</if_matched_sid>
    <same_srcip />
    <different_dstip />
    <description>Mot may ket noi toi nhieu may noi bo trong thoi gian ngan</description>
    <mitre><id>T1046</id></mitre>
  </rule>
</group>
"""


def do_mau(install):
    """CHI DE PHAT TRIEN / P7: in (hoac cai) giai mau R-A/R-B cho the gioi cua SV nay. Chay bang root tren siem."""
    import socq.ca as ca  # noqa: E402
    seed = int(open(os.path.join(ST, "seed")).read())
    s = ca.build(seed, int(open(os.path.join(ST, "t_ref")).read()))
    w, cx = s["world"], s["ctx"]
    xml = MAU_XML % {"script": (w.upload_dir + w.approved_script).replace(".", "\\."), "svc": cx.svc_upload, "chg": cx.chg_backup}
    hosts = "".join("%s:\n" % w.ip(h) for h in w.backup_hosts)
    ports = "%d:\n" % w.backup_port
    if not install:
        print(xml + "\n# sao-luu-hosts\n" + hosts + "# sao-luu-ports\n" + ports)
        return
    open(RULES, "w").write(xml)
    open("/var/ossec/etc/lists/sao-luu-hosts", "w").write(hosts)
    open("/var/ossec/etc/lists/sao-luu-ports", "w").write(ports)
    os.system("chown wazuh:wazuh %s /var/ossec/etc/lists/sao-luu-*; /var/ossec/bin/wazuh-analysisd -t && /var/ossec/bin/wazuh-control restart >/dev/null && echo DA_NAP_GIAI_MAU" % RULES)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "print"
    if cmd == "rules":
        do_rules(int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    elif cmd in ("mau", "mau-nap"):
        do_mau(cmd == "mau-nap")
    elif cmd == "live":
        print("\n".join(do_live()))
    elif cmd == "cached":
        # prestop du phong (nhanh, khong indexer): ban in sau het ca do grade-bai18 luu; khong co -> giu cho
        if os.path.exists(CACHE):
            sys.stdout.write(open(CACHE).read())
            print("FROM_CACHE")
        else:
            print("SIEM18_MARKER")
            print("PRESTOP_FALLBACK")
            giu_cho()
    elif "--cache" in sys.argv:
        # grade-bai18 (sau moi lan cham + sau het ca): luu ban in cho prestop du phong
        import contextlib, io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            do_print()
        if "SHIFT_END=Y" in buf.getvalue():
            write_atomic(CACHE, buf.getvalue())
    else:
        do_print("--all" in sys.argv)          # --all: CHI phat trien (in ca khi chua het ca)
