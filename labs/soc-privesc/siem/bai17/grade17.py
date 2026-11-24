#!/usr/bin/env python3
# ============================================================================
# grade17.py - cham phan "luat" va tinh dap an "ban do phu" cua Bai 17. Chay tren siem (root).
#
#   grade17.py rules   phat lai TAP KIEM TRA AN voi luat dang nap -> /root/.bai17/rules.txt
#                      (chay boi grade-bai17.service moi khi local_rules.xml / lists doi;
#                       prestop goi lai neu ket qua cu khong khop sha luat hien tai)
#   grade17.py cover   tinh GT_COVER_0..6 tu alerts.json (luat NGUYEN TRANG, level >= 10)
#   grade17.py print   in ket qua (dung trong prestop)
#
# Nguong (kich ban 6.4): moi luat recall = 100% (FN = 0) va FP <= 1 tren tap an.
# ============================================================================
import fcntl, hashlib, json, os, re, subprocess, sys, time
import xml.etree.ElementTree as ET

HERE = "/home/ubuntu/bai17"
sys.path.insert(0, os.path.join(HERE, "lib"))
import replay  # noqa: E402
from wzapi import Wazuh, WazuhError  # noqa: E402

ST = "/root/.bai17"
RULES = "/var/ossec/etc/rules/local_rules.xml"
ALERTS = "/var/ossec/logs/alerts/alerts.json"
RANGES = {"l1": (100270, 100279), "l2": (100280, 100289), "l3": (100290, 100299)}
STUDENT_LO, STUDENT_HI = 100270, 100299
ATTACKER = "172.20.0.5"
DESIGN = "0000010"
L1_MIN_TIMEFRAME = 600          # >= do dai dot do rai cham (kich ban 6.4)
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"


def rules_sha():
    try:
        return hashlib.sha256(open(RULES, "rb").read()).hexdigest()[:16]
    except OSError:
        return "none"


def write_atomic(path, text):
    tmp = path + ".tmp"
    open(tmp, "w").write(text)
    os.replace(tmp, path)


def rules_validity():
    """MITRE cho moi luat level>=10 trong dai SV; dem luat moi dai.
    L1 (kiem TINH): bo phat lai gui ca kich ban gan nhu cung luc nen KHONG do duoc do dai cua so;
    vi vay moi luat tan suat level>=10 cua L1 phai co timeframe >= L1_MIN_TIMEFRAME (dot do rai cham)."""
    try:
        root = ET.fromstring("<root>" + open(RULES, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return False, {f: 0 for f in RANGES}, False
    ok, count = True, {f: 0 for f in RANGES}
    l1_freq, l1_window_ok = 0, True
    lo1, hi1 = RANGES["l1"]
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
        if lo1 <= rid <= hi1 and lvl >= 10 and r.get("frequency"):
            l1_freq += 1
            try:
                if int(r.get("timeframe", "0")) < L1_MIN_TIMEFRAME:
                    l1_window_ok = False
            except ValueError:
                l1_window_ok = False
    return ok, count, (l1_freq > 0 and l1_window_ok)


def wait_analysisd(api, wait=120):
    t0 = time.time()
    while time.time() - t0 < wait:
        try:
            st = api._req("GET", "/manager/status")
            if ((st.get("data") or {}).get("affected_items") or [{}])[0].get("wazuh-analysisd") == "running":
                return True
        except WazuhError:
            pass
        time.sleep(4)
    return False


def analysisd_started():
    """Thoi diem tien trinh wazuh-analysisd hien tai khoi dong (0 neu khong chay)."""
    try:
        pid = subprocess.run(["pidof", "wazuh-analysisd"], capture_output=True, text=True).stdout.split()[0]
        return os.stat("/proc/" + pid).st_ctime
    except (IndexError, OSError):
        return 0


def wait_rules_loaded(wait=300):
    """kiem-thu-luat ghi file (path unit kich hoat ta) ROI moi restart manager (1-2 phut tren VM cham).
    Cho den khi analysisd DANG CHAY va khoi dong SAU lan sua file luat/list cuoi -> bo luat tren dia da nap.
    Het gio (vd kiem-thu-luat khong restart vi cau hinh loi -> da khoi phuc ban cu) thi cham voi ban dang chay."""
    files = [RULES] + [os.path.join("/var/ossec/etc/lists", n) for n in ("gtfo-shell", "sudo-approved", "admin-hosts")]
    t0 = time.time()
    while time.time() - t0 < wait:
        mt = max((os.path.getmtime(f) for f in files if os.path.exists(f)), default=0)
        st = analysisd_started()
        if st and st > mt:
            if time.time() - st < 30:          # vua khoi dong -> cho nap xong ruleset
                time.sleep(10)
            return True
        time.sleep(5)
    return False


def do_rules(settle=20):
    os.makedirs(ST, exist_ok=True)
    lockf = open(os.path.join(ST, ".lock"), "w")
    fcntl.flock(lockf, fcntl.LOCK_EX)          # tranh 2 lan cham chong nhau
    time.sleep(settle)                         # cho kiem-thu-luat nap xong + restart
    wait_rules_loaded()
    sha = rules_sha()
    api = Wazuh("https://127.0.0.1:55000", TOOL_USER, TOOL_PASS)
    out = ["RULES_SHA=%s" % sha, "GRADED_AT=%s" % time.strftime("%H:%M:%S")]
    try:
        for i in range(24):                      # API len cham sau restart (HTTP 500 / tu choi ket noi)
            try:
                api.login()
                break
            except WazuhError:
                if i == 23:
                    raise
                time.sleep(5)
        wait_analysisd(api)
        res = replay.run(replay.ApiEngine(api), replay.load_set(os.path.join(ST, "hidden.jsonl")), RANGES)
    except Exception as e:  # noqa: BLE001
        out.append("GRADE_ERROR=%s" % str(e)[:120].replace("\n", " "))
        write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")
        return
    valid, count, l1_window = rules_validity()
    out.append("RULES_VALID=%s" % ("Y" if valid else "N"))
    out.append("L1_WINDOW=%s" % ("Y" if l1_window else "N"))
    for f, r in res.items():
        u = f.upper()
        out.append("%s_TP=%d %s_FP=%d %s_FN=%d %s_NRULES=%d" % (u, r["tp"], u, r["fp"], u, r["fn"], u, count[f]))
        if r["fn"] == 0 and r["fp"] <= 1 and r["n_mal"] > 0 and (f != "l1" or l1_window):
            out.append("%s_OK" % u)
    write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")


# ---------------------------------------------------------------- ban do phu
def _ts(a):
    t = a.get("timestamp", "")[:19]
    try:
        return time.mktime(time.strptime(t, "%Y-%m-%dT%H:%M:%S"))
    except ValueError:
        return 0


def stage_of(a):
    """Tra ve so giai doan (0-6) ma canh bao thuoc ve, hoac None."""
    fl = a.get("full_log", "") or ""
    data = a.get("data") or {}
    rid = str((a.get("rule") or {}).get("id", ""))
    groups = (a.get("rule") or {}).get("groups") or []
    path = ((a.get("syscheck") or {}).get("path")) or ""
    src = data.get("srcip") or ""
    if "Failed password" in fl and (src == ATTACKER or ("from " + ATTACKER + " ") in fl):
        return 0
    if "Accepted password" in fl and ("from " + ATTACKER + " ") in fl:
        return 1
    if "COMMAND=list" in fl and "sudo" in fl:
        return 2
    if "COMMAND=/usr/bin/awk" in fl and "sudo" in fl:
        return 3
    if path.startswith("/tmp/.") or ("syscheck" in groups and "/tmp/." in fl):
        return 4
    if rid == "100300" or "new user" in fl and "UID=0" in fl or path.startswith(
            ("/etc/passwd", "/root/.ssh", "/usr/local/bin/.", "/etc/cron.d/sysbackup")):
        return 5
    if "Accepted publickey for root" in fl and ("from " + ATTACKER + " ") in fl:
        return 6
    return None


def do_cover():
    alerts = []
    try:
        with open(ALERTS, errors="ignore") as f:
            for ln in f:
                try:
                    alerts.append(json.loads(ln))
                except ValueError:
                    pass
    except OSError:
        pass
    # moc cat: 2 phut sau khi ke tan cong quay lai (giai doan 6) -> bo qua hanh dong cua SV ve sau
    t6 = [_ts(a) for a in alerts if stage_of(a) == 6]
    cutoff = (min(t6) + 120) if t6 else None
    seen = [False] * 7
    stage_seen = [False] * 7
    for a in alerts:
        st = stage_of(a)
        if st is None or (cutoff and _ts(a) > cutoff):
            continue
        stage_seen[st] = True
        rule = a.get("rule") or {}
        try:
            rid, lvl = int(rule.get("id", 0)), int(rule.get("level", 0))
        except ValueError:
            continue
        if lvl >= 10 and not (STUDENT_LO <= rid <= STUDENT_HI):
            seen[st] = True
    gt = "".join("1" if s else "0" for s in seen)
    out = ["GT_COVER=%s" % gt, "CHAIN_STAGES_SEEN=%s" % "".join("1" if s else "0" for s in stage_seen)]
    if gt == DESIGN:
        out.append("COVER_DESIGN_OK")
    return "\n".join(out) + "\n"


def do_print():
    p = os.path.join(ST, "rules.txt")
    txt = open(p).read() if os.path.exists(p) else ""
    if "RULES_SHA=%s" % rules_sha() not in txt:
        print("RULES_STALE")
    print(txt.strip())
    print(do_cover().strip())


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "print"
    if cmd == "rules":
        do_rules(settle=int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    elif cmd == "cover":
        print(do_cover(), end="")
    else:
        do_print()
