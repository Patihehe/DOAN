#!/usr/bin/env python3
# ============================================================================
# gen17.py - bo sinh kich ban log cho 3 luat lap lo hong cua Bai 17 (dinh dang JSONL cua replay.py).
#   l1 = do mat khau rai cham (L1, dai 100270-100279)
#   l2 = sudo toi chuong trinh thoat duoc shell (L2, dai 100280-100289)
#   l3 = root dang nhap tu xa tu may khong duoc duyet (L3, dai 100290-100299)
# Dung chung cho siem (tap kiem tra AN) va defender (tap phat trien). Hai noi tu random doc lap.
#
#   gen17.py --set dev|hidden --out FILE [--seed N]     sinh tap
#   gen17.py --check FILE                                kiem bat bien (unit test)
# ============================================================================
import argparse, json, random, sys
from datetime import datetime, timedelta

HOST = "target"
ADMIN_APPROVED = ["172.20.0.41", "172.20.0.42"]     # khop admin-hosts.csv (status=approved)
ADMIN_RETIRED = ["172.20.0.49"]                     # khop admin-hosts.csv (status=retired)
APPROVED_SUDO = [                                   # khop sudo-da-duyet.csv
    ("deploy", "/usr/bin/systemctl restart nginx"),
    ("deploy", "/usr/bin/systemctl restart cron"),
    ("adminops", "/usr/bin/apt update"),
    ("adminops", "/usr/bin/tail -n 200 /var/log/syslog"),
]
GTFO_DEV = ["/usr/bin/awk", "/usr/bin/vim", "/usr/bin/find", "/usr/bin/nano"]
GTFO_HIDDEN_EXTRA = ["/usr/bin/less", "/usr/bin/vi", "/usr/bin/perl", "/usr/bin/python3", "/usr/bin/env"]
EDITORS = ["/usr/bin/vim", "/usr/bin/nano", "/usr/bin/less", "/usr/bin/vi"]
GTFO_CMD = {
    "/usr/bin/awk": "/usr/bin/awk BEGIN {system(\"/bin/sh\")}",
    "/usr/bin/find": "/usr/bin/find . -exec /bin/sh ; -quit",
    "/usr/bin/vim": "/usr/bin/vim -c :!/bin/sh",
    "/usr/bin/vi": "/usr/bin/vi /etc/hosts",
    "/usr/bin/nano": "/usr/bin/nano /etc/hosts",
    "/usr/bin/less": "/usr/bin/less /var/log/syslog",
    "/usr/bin/perl": "/usr/bin/perl -e exec \"/bin/sh\";",
    "/usr/bin/python3": "/usr/bin/python3 -c import os; os.system(\"/bin/sh\")",
    "/usr/bin/env": "/usr/bin/env /bin/sh",
}

R = random.Random()
_BASE = [datetime(2026, 11, 20, 9, 0, 0)]


def ts(t):
    # dinh dang syslog: "Nov  5 09:00:01" (ngay can le 2 ky tu)
    return "%s %2d %s" % (t.strftime("%b"), t.day, t.strftime("%H:%M:%S"))


def pid():
    return R.randint(1200, 65000)


def port():
    return R.randint(32768, 60999)


def emp():
    return "emp%04d" % R.randint(1000, 9999)


def emps(n):
    s = set()
    while len(s) < n:
        s.add(emp())
    return list(s)


def ip_internal():
    return "172.20.0.%d" % R.choice(list(range(50, 99)))


def ip_external():
    return "%d.%d.%d.%d" % (R.choice([45, 91, 103, 185, 203]), R.randint(1, 254), R.randint(1, 254), R.randint(1, 254))


def fp_key():
    abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return "".join(R.choice(abc) for _ in range(43))


def l_fail(t, user, ip):
    return "%s %s sshd[%d]: Failed password for %s from %s port %d ssh2" % (ts(t), HOST, pid(), user, ip, port())


def l_ok_pw(t, user, ip):
    return "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (ts(t), HOST, pid(), user, ip, port())


def l_ok_key(t, user, ip):
    return "%s %s sshd[%d]: Accepted publickey for %s from %s port %d ssh2: ED25519 SHA256:%s" % (
        ts(t), HOST, pid(), user, ip, port(), fp_key())


def l_sudo(t, user, cmd):
    return "%s %s sudo: %8s : TTY=pts/%d ; PWD=/home/%s ; USER=root ; COMMAND=%s" % (
        ts(t), HOST, user, R.randint(0, 4), user, cmd)


def start():
    _BASE[0] += timedelta(hours=1, minutes=R.randint(0, 50))
    return _BASE[0]


# ------------------------------------------------------------------ L1
def l1_mal(variant):
    t, ip = start(), (ip_internal() if R.random() < 0.6 else ip_external())
    if variant == "fast":
        n, gaps = R.randint(9, 12), (8, 15)
    else:
        n, gaps = R.randint(8, 13), (25, 44)
    users = emps(n)
    lines = []
    for u in users:
        lines.append(l_fail(t, u, ip))
        t += timedelta(seconds=R.randint(*gaps))
    if variant == "success":
        lines[-1] = l_ok_pw(t, users[-1], ip)
    return lines, 600


def l1_benign(variant):
    t = start()
    lines = []
    if variant == "typo":                       # 1 nguoi go nham 1-4 lan roi vao duoc
        u, ip = emp(), ip_internal()
        for _ in range(R.randint(1, 4)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(3, 20))
        lines.append(l_ok_pw(t, u, ip))
    elif variant == "jumphost":                 # may chu nhay dung chung: <=3 user go nham roi rac
        ip = ip_internal()
        for u in emps(R.randint(2, 3)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(5, 30))
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(60, 180))
        for u in emps(R.randint(2, 4)):
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(20, 90))
    elif variant == "distributed":              # nhieu nguoi go nham, MOI NGUOI 1 IP khac nhau
        for u in emps(R.randint(6, 9)):
            ip = ip_internal()
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(10, 60))
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(5, 30))
    elif variant == "stale":                    # tac vu tu dong dung mat khau CU: 1 user, 6-8 lan, cung IP
        u, ip = R.choice(["svc-backup", "svc-report", "svc-monitor"]), ip_internal()
        for _ in range(R.randint(6, 8)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(50, 90))
    else:                                       # "repeat": 1 user quen mat khau, thu 5-7 lan, khong vao duoc
        u, ip = emp(), ip_internal()
        for _ in range(R.randint(5, 7)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(20, 90))
    return lines, 600


# ------------------------------------------------------------------ L2
def l2_mal(prog, user):
    t = start()
    lines = []
    if R.random() < 0.5:
        lines.append(l_sudo(t, user, "list")); t += timedelta(seconds=R.randint(10, 60))
    lines.append(l_sudo(t, user, GTFO_CMD[prog]))
    return lines, 120


def l2_benign(variant):
    t = start()
    if variant == "approved":
        pairs = R.sample(APPROVED_SUDO, R.randint(1, 3))
        lines = []
        for u, c in pairs:
            lines.append(l_sudo(t, u, c)); t += timedelta(seconds=R.randint(5, 50))
        return lines, 120
    if variant == "list":
        return [l_sudo(t, emp(), "list")], 120
    if variant == "deploy-approved-repeat":
        u, c = APPROVED_SUDO[R.randint(0, 1)]
        return [l_sudo(t, u, c), l_sudo(t + timedelta(seconds=40), u, c)], 120
    return [l_sudo(t, "adminops", R.choice(["/usr/bin/apt update", "/usr/bin/tail -n 200 /var/log/syslog"]))], 120


# ------------------------------------------------------------------ L3
def l3_mal(variant):
    t = start()
    if variant == "internal-key":
        return [l_ok_key(t, "root", ip_internal())], 120
    if variant == "external-key":
        return [l_ok_key(t, "root", ip_external())], 120
    if variant == "password":
        ip = ip_internal()
        return [l_fail(t, "root", ip), l_ok_pw(t + timedelta(seconds=7), "root", ip)], 120
    return [l_ok_key(t, "root", R.choice(ADMIN_RETIRED))], 120          # "retired-admin"


def l3_benign(variant):
    t = start()
    if variant == "admin":
        return [l_ok_key(t, "root", R.choice(ADMIN_APPROVED))], 120
    if variant == "user-key":
        return [l_ok_key(t, emp(), ip_internal())], 120
    if variant == "deploy-key":
        return [l_ok_key(t, "deploy", R.choice(ADMIN_APPROVED + [ip_internal()]))], 120
    if variant == "root-fail":
        return [l_fail(t, "root", ip_external())], 120
    return [l_ok_pw(t, emp(), ip_internal())], 120                      # "user-pw"


# ------------------------------------------------------------------ lap tap
def build(kind):
    out = []

    def add(fam, label, variant, pair):
        lines, w = pair
        out.append({"id": "%s-%s-%02d" % (fam, "m" if label == "mal" else "b", 1 + sum(
            1 for s in out if s["family"] == fam and s["label"] == label)),
            "family": fam, "label": label, "variant": variant, "window_s": w, "lines": lines})

    # L1
    mal1 = ["slow", "success", "slow"] + (["fast"] if kind == "hidden" else [])
    for v in mal1:
        add("l1", "mal", v, l1_mal(v))
    # lanh: moi bien the bay 1 kieu luat sai (dem lan that bai thay vi dem TAI KHOAN; khong gom theo IP)
    ben1 = ["typo", "stale", "jumphost", "distributed", "distributed", "repeat"]
    for v in ben1:
        add("l1", "benign", v, l1_benign(v))

    # L2: tap an co them chuong trinh chua gap trong tap phat trien (~1/3 bien the moi)
    if kind == "dev":
        mal2 = [("/usr/bin/awk", emp()), ("/usr/bin/vim", emp()), (R.choice(["/usr/bin/nano", "/usr/bin/vim"]), "deploy")]
    else:
        progs = [R.choice(["/usr/bin/awk", "/usr/bin/find"]), R.choice(GTFO_HIDDEN_EXTRA),
                 R.choice(["/usr/bin/less", "/usr/bin/vi"])]
        mal2 = [(progs[0], emp()), (progs[1], emp()), (progs[2], emp()), (R.choice(EDITORS), "deploy")]
    for prog, user in mal2:
        add("l2", "mal", "%s:%s" % (user if user == "deploy" else "user", prog.rsplit("/", 1)[1]), l2_mal(prog, user))
    for v in ["approved", "approved", "list", "deploy-approved-repeat", "admin", "approved"]:
        add("l2", "benign", v, l2_benign(v))

    # L3
    mal3 = ["internal-key", "retired-admin", "password"] + (["external-key"] if kind == "hidden" else [])
    for v in mal3:
        add("l3", "mal", v, l3_mal(v))
    for v in ["admin", "admin", "user-key", "deploy-key", "root-fail"]:
        add("l3", "benign", v, l3_benign(v))
    return out


# ------------------------------------------------------------------ bat bien
def _parse(line):
    """Tra ve (kind, user, ip) cho dong sshd; None neu khong phai."""
    import re
    m = re.search(r"(Failed|Accepted) (password|publickey) for (\S+) from (\S+)", line)
    if not m:
        return None
    return ("fail" if m.group(1) == "Failed" else "ok"), m.group(3), m.group(4)


def check(scs):
    errs = []
    for s in scs:
        if s["family"] == "l1":
            by_ip = {}
            for ln in s["lines"]:
                p = _parse(ln)
                if p and p[0] == "fail":
                    by_ip.setdefault(p[2], set()).add(p[1])
            mx = max([len(v) for v in by_ip.values()] or [0])
            if s["label"] == "mal" and mx < 8:
                errs.append("%s: doc nhung chi %d tai khoan/IP" % (s["id"], mx))
            if s["label"] == "benign" and mx > 3:
                errs.append("%s: lanh nhung %d tai khoan khac nhau tu 1 IP" % (s["id"], mx))
            if s["variant"] in ("typo", "repeat", "stale"):
                fails = [_parse(l) for l in s["lines"] if "Failed" in l]
                if len({f[1] for f in fails}) != 1 or (s["variant"] == "typo" and len(fails) > 4) \
                        or (s["variant"] != "typo" and len(fails) < 5):
                    errs.append("%s: typo <=4 lan; repeat/stale >=5 lan; luon cung 1 user" % s["id"])
        if s["family"] == "l2" and s["label"] == "mal":
            if not any("COMMAND=" + c.split(" ")[0] in ln or ("COMMAND=" + c) in ln for ln in s["lines"] for c in GTFO_CMD):
                errs.append("%s: khong co lenh thoat shell" % s["id"])
        if s["family"] == "l3":
            roots = [_parse(l) for l in s["lines"] if _parse(l) and _parse(l)[0] == "ok" and _parse(l)[1] == "root"]
            bad = [r for r in roots if r[2] not in ADMIN_APPROVED]
            if s["label"] == "mal" and not bad:
                errs.append("%s: doc nhung khong co root dang nhap tu IP khong duyet" % s["id"])
            if s["label"] == "benign" and bad:
                errs.append("%s: lanh nhung co root tu IP khong duyet" % s["id"])
    fams = {}
    for s in scs:
        fams.setdefault((s["family"], s["label"]), 0)
        fams[(s["family"], s["label"])] += 1
    if not any(s["family"] == "l2" and s["label"] == "mal" and s["variant"].startswith("deploy:") for s in scs):
        errs.append("l2: thieu kich ban doc do chinh deploy chay chuong trinh khong duoc duyet")
    if not any(s["family"] == "l3" and s["variant"] == "retired-admin" for s in scs):
        errs.append("l3: thieu kich ban tu may quan tri da retired")
    return errs, fams


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", choices=["dev", "hidden"])
    ap.add_argument("--out")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--check")
    a = ap.parse_args()
    if a.check:
        scs = [json.loads(l) for l in open(a.check) if l.strip()]
        errs, fams = check(scs)
        print("SO_KICH_BAN " + " ".join("%s/%s=%d" % (k[0], k[1], v) for k, v in sorted(fams.items())))
        for e in errs:
            print("LOI " + e)
        sys.exit(1 if errs else 0)
    if not a.set or not a.out:
        ap.error("can --set va --out (hoac --check)")
    R.seed(a.seed if a.seed is not None else int.from_bytes(__import__("os").urandom(8), "big"))
    for _ in range(10):
        scs = build(a.set)
        errs, _f = check(scs)
        if not errs:
            break
    else:
        print("\n".join(errs)); sys.exit(2)
    with open(a.out, "w") as f:
        for s in scs:
            f.write(json.dumps(s) + "\n")
    print("OK %d kich ban -> %s" % (len(scs), a.out))


if __name__ == "__main__":
    main()
