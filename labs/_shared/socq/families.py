#!/usr/bin/env python3
# ============================================================================
# families.py - bo sinh kich ban (dinh dang replay.py) cho 2 viec ky nghe phat hien cua Bai 18:
#   R-A (100330-100339): moi lenh goi qua script trong thu muc upload, KHONG phu thuoc ten tham so
#   R-B (100340-100349): 1 may ket noi toi nhieu dich noi bo - giu recall, them ngoai le co can cu (CHG)
# Moi kich ban = 1 phien logtest. Tap dev (giao SV khi yeu cau xuat hien) va tap AN (chi tren siem)
# deu sinh tu CUNG the gioi cua SV -> IP may sao luu, cong agent, script da duyet khop voi ctx-*.
# Tap an BAT BUOC co cac kich ban danh vao loi dien hinh (kich ban 5.2 / P7: T5-T8, T10).
# ============================================================================
import random

from . import chain, docs

RANGES = "ra=100330-100339,rb=100340-100349"
UP_EXT = ["php", "phtml", "phar"]


def _web(ts, w, src, url, status=200):
    return docs.line_web(ts, "web-shop", src, "GET", url, status, 1200)


# ---------------------------------------------------------------- R-A
def ra_scenarios(w, rng, hidden):
    out = []
    t = 1795500000
    params = list(w.cmd_params) + (["zz", "q", "id2", "r"] if hidden else [])
    names = [w.webshell] + (["img_%d.php" % rng.randint(10, 99), "cache_%d.phar" % rng.randint(10, 99),
                             "2026/11/logo_%d.phtml" % rng.randint(10, 99)] if hidden else ["thumb_%d.php" % rng.randint(10, 99)])
    k = 0
    for name in names:                                 # DOC: lenh qua webshell, ten tham so doi
        for _ in range(2 if hidden else 1):
            k += 1
            lines = [_web(t + j, w, w.attacker_ip if not hidden else "%d.%d.%d.%d" % (rng.choice([45, 91, 185]), rng.randint(1, 254), rng.randint(1, 254), rng.randint(11, 249)),
                          "%s%s?%s=%s" % (w.upload_dir, name, rng.choice(params), rng.choice(["id", "ls+-la", "uname+-a", "whoami"])))
                     for j in range(rng.randint(1, 3))]
            out.append({"id": "ra-m-%02d" % k, "family": "ra", "label": "mal", "variant": name.rsplit(".", 1)[1], "lines": lines})
    ben = [
        ("anh", ["%savatar_%d.png" % (w.upload_dir, rng.randint(1000, 9999)) for _ in range(3)]),
        ("anh-cache-buster", ["%savatar_%d.jpg?v=%d" % (w.upload_dir, rng.randint(1000, 9999), rng.randint(1, 9)) for _ in range(2)]),
        ("script-da-duyet", ["%s%s?w=128&h=128&f=avatar_%d.png" % (w.upload_dir, w.approved_script, rng.randint(1000, 9999)) for _ in range(3)]),
        ("php-ngoai-upload", ["/product.php?id=%d" % rng.randint(1, 900), "/search.php?q=ao+khoac"]),
        ("script-khong-query", ["%s%s" % (w.upload_dir, w.webshell)]),
    ]
    if hidden:
        ben += [("script-da-duyet-2", ["%s%s?w=64&h=64&f=x_%d.webp&crop=1" % (w.upload_dir, w.approved_script, rng.randint(1, 999))]),
                ("anh-trong-thu-muc-con", ["%s2026/11/banner_%d.png?x=1" % (w.upload_dir, rng.randint(1, 99))]),
                ("trang-admin", ["/admin/index.php?tab=orders", "/profile/upload_avatar.php?step=2"])]
    for i, (v, urls) in enumerate(ben, 1):
        src = "%d.%d.%d.%d" % (rng.choice([14, 27, 113, 171]), rng.randint(1, 254), rng.randint(1, 254), rng.randint(1, 254))
        out.append({"id": "ra-b-%02d" % i, "family": "ra", "label": "benign", "variant": v,
                    "lines": [_web(t + j, w, src, u) for j, u in enumerate(urls)]})
    return out


# ---------------------------------------------------------------- R-B
def _conns(t, host, src, dsts, ports, rng):
    return [docs.line_conn(t + j * 0.5, host, src, d, rng.choice(ports)) for j, d in enumerate(dsts)]


def rb_scenarios(w, rng, hidden):
    t = 1795500000
    internal = [h["ip"] for n, h in w.hosts.items() if n not in ("siem",)]
    srv = [n for n in w.hosts if not n.startswith(("ws-", "bk-")) and n not in ("siem", "web-shop", "dns-01")]
    out = []

    def add(label, variant, lines):
        out.append({"id": "rb-%s-%02d" % ("m" if label == "mal" else "b", sum(1 for x in out if x["label"] == label) + 1),
                    "family": "rb", "label": label, "variant": variant, "lines": lines})

    n = lambda: rng.randint(10, 14)
    ws = w.ip("web-shop")
    # --- DOC
    add("mal", "quet-tu-web-shop", _conns(t, "web-shop", ws, rng.sample(internal, n()), chain.SCAN_PORTS, rng))
    h = rng.choice(srv)
    add("mal", "quet-ssh", _conns(t, h, w.ip(h), rng.sample(internal, n()), [22], rng))
    bk = rng.choice(w.backup_hosts)
    add("mal", "may-sao-luu-sai-cong", _conns(t, bk, w.ip(bk), rng.sample(internal, n()), [22, 445, 3389], rng))
    if hidden:
        h2 = rng.choice([x for x in srv if x != h])
        add("mal", "may-ngoai-CHG-dung-cong-agent", _conns(t, h2, w.ip(h2), rng.sample(internal, n()), [w.backup_port], rng))
        add("mal", "quet-ssh-tu-web-shop", _conns(t, "web-shop", ws, rng.sample(internal, n()), [22], rng))
        wsx = rng.choice([x for x in w.hosts if x.startswith("ws-")])
        add("mal", "quet-tu-may-tram", _conns(t, wsx, w.ip(wsx), rng.sample(internal, n()), [445, 139, 3389], rng))
    # --- LANH
    for bk in (w.backup_hosts if hidden else w.backup_hosts[:1]):
        add("benign", "sao-luu-CHG", _conns(t, bk, w.ip(bk), rng.sample(internal, rng.randint(12, 18)), [w.backup_port], rng))
    add("benign", "ung-dung-toi-db", _conns(t, "erp-01", w.ip("erp-01"), [w.ip("db-core")] * 15, [3306], rng))
    add("benign", "it-dich", _conns(t, "jump-01", w.ip("jump-01"), rng.sample(internal, 5), [22], rng))
    if hidden:
        wsx = rng.choice([x for x in w.hosts if x.startswith("ws-")])
        add("benign", "may-tram-toi-dns", _conns(t, wsx, w.ip(wsx), [w.ip("dns-01")] * 20, [53], rng))
        add("benign", "it-dich-2", _conns(t, "mail-01", w.ip("mail-01"), rng.sample(internal, 6), [25, 993], rng))
    return out


def build(w, seed, hidden):
    rng = random.Random("%s:fam:%s" % (seed, "an" if hidden else "dev"))
    return {"ra": ra_scenarios(w, rng, hidden), "rb": rb_scenarios(w, rng, hidden)}
