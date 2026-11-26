#!/usr/bin/env python3
# ============================================================================
# seed18.py - khoi tao siem cho Bai 18. Chay BOI SYSTEMD (seed-bai18.service), root, MOT lan (marker).
#
#  1) seed ca nhan hoa (lan dau) -> /root/.bai18/{seed,t_ref}; dung lai toan bo ca bang socq.ca.build
#  2) Wazuh: request_timeout 60, <localfile> /var/log/soc-shift/*.log, luat san xuat 100310,
#     luat khung cua SV (R-B 100342/100340 - gay bao khi den gio), analysisd -t, restart (3 lan)
#  3) user API soc-tool (cong cu tren defender)
#  4) indexer: ctx-* + index pattern; nen log 2 gio truoc ca
#  5) tap AN R-A/R-B (/root/.bai18/hidden.jsonl); tap DEV (/root/.bai18/dev-*.jsonl, lich-ca giao khi den gio)
#  6) T0 = luc moi thu san sang (sau MOI lan restart cua seed) -> lich-ca bat dau ca
# Thu tu quan trong (bai hoc Lab 17): T0 dat SAU restart cuoi cung cua seed.
# ============================================================================
import calendar, glob, json, os, random, re, subprocess, sys, time

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
from wzapi import Wazuh, WazuhError  # noqa: E402
from socq import ca, chain, docs, families, indexer, shift  # noqa: E402

ST = "/root/.bai18"
PUB = "/srv/shiftd"
OSSEC = "/var/ossec"
LOGDIR = "/var/log/soc-shift"
MARK = os.path.join(ST, "seeded")
# cac co seed ghi (thu tu) - chi de bao tien do cho defender
BUOC = ("PLAN", "WAZUH", "API_USER", "CTX", "RENDER", "NEN", "HIDDEN")
LOG = os.path.join(ST, "seed.log")
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"
LF_MARK = "<!-- bai18-localfile -->"
LISTS = ["sao-luu-hosts", "sao-luu-ports"]       # CDB list cho ngoai le R-B (SV dien qua kiem-thu-luat)


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def wui_creds():
    for p in glob.glob("/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"):
        txt = open(p).read()
        u = re.search(r"username:\s*['\"]?([^'\"\n]+)", txt)
        pw = re.search(r"password:\s*['\"]?([^'\"\n]+)", txt)
        if u and pw:
            return u.group(1).strip(), pw.group(1).strip()
    return None, None


def wait_api(user, pw, tries=72):
    for _ in range(tries):
        try:
            api = Wazuh("https://127.0.0.1:55000", user, pw)
            api.login()
            return api
        except WazuhError:
            time.sleep(5)
    return None


def api_timeout():
    p = OSSEC + "/api/configuration/api.yaml"
    try:
        txt = open(p).read()
    except OSError:
        return
    if re.search(r"^\s*request_timeout:", txt, re.M):
        txt = re.sub(r"^(\s*request_timeout:).*$", r"\1 60", txt, flags=re.M)
    elif re.search(r"^intervals:\s*$", txt, re.M):
        txt = re.sub(r"^intervals:\s*$", "intervals:\n  request_timeout: 60", txt, count=1, flags=re.M)
    else:
        txt = txt.rstrip("\n") + "\n\nintervals:\n  request_timeout: 60\n"
    open(p, "w").write(txt)


def restart_manager():
    for i in range(3):
        cmd = "systemctl restart wazuh-manager" if i == 0 else \
              "systemctl reset-failed wazuh-manager; %s/bin/wazuh-control restart" % OSSEC
        r = sh(cmd)
        st = sh(OSSEC + "/bin/wazuh-control status").stdout
        log("restart lan %d rc=%s" % (i + 1, r.returncode))
        if "wazuh-apid is running" in st and "wazuh-analysisd is running" in st and "wazuh-logcollector is running" in st:
            return True
        time.sleep(20)
    return False


def install_wazuh():
    os.makedirs(LOGDIR, exist_ok=True)
    for h in ("web-shop", "net"):
        open(os.path.join(LOGDIR, "%s.log" % h), "a").close()
    api_timeout()
    conf = open(OSSEC + "/etc/ossec.conf").read()
    if LF_MARK not in conf:
        conf = conf.rstrip("\n") + ("\n<ossec_config>\n  %s\n  <localfile>\n    <log_format>syslog</log_format>\n"
                                    "    <location>%s/*.log</location>\n  </localfile>\n</ossec_config>\n") % (LF_MARK, LOGDIR)
        open(OSSEC + "/etc/ossec.conf", "w").write(conf)
    for n in LISTS:                                  # list rong (1 khoa gia) + khai bao trong <ruleset>
        p = os.path.join(OSSEC, "etc/lists", n)
        if not os.path.exists(p):
            open(p, "w").write("lab-placeholder:\n")
        if "etc/lists/%s<" % n not in conf:
            conf = conf.replace("<ruleset>", "<ruleset>\n    <list>etc/lists/%s</list>" % n, 1)
    open(OSSEC + "/etc/ossec.conf", "w").write(conf)
    sh("chown wazuh:wazuh %s/etc/lists/sao-luu-*" % OSSEC)
    for src, dst in (("bai18_prod_rules.xml", "bai18_prod_rules.xml"), ("local_rules_khung.xml", "local_rules.xml")):
        open(os.path.join(OSSEC, "etc/rules", dst), "w").write(open(os.path.join(HERE, src)).read())
    sh("chown wazuh:wazuh %s/etc/rules/*.xml; chmod 660 %s/etc/rules/*.xml" % (OSSEC, OSSEC))
    t = sh(OSSEC + "/bin/wazuh-analysisd -t")
    log("analysisd -t rc=%s %s" % (t.returncode, (t.stdout + t.stderr).strip()[-300:]))
    if t.returncode != 0:
        return False
    return restart_manager()


def create_tool_user(api):
    r = api._req("GET", "/security/users", params={"search": TOOL_USER})
    items = (r.get("data") or {}).get("affected_items") or []
    uid = next((it["id"] for it in items if it.get("username") == TOOL_USER), None)
    if uid is None:
        r = api._req("POST", "/security/users", body={"username": TOOL_USER, "password": TOOL_PASS})
        uid = r["data"]["affected_items"][0]["id"]
    else:
        api._req("PUT", "/security/users/%s" % uid, body={"password": TOOL_PASS})
    try:
        api._req("POST", "/security/users/%s/roles" % uid, params={"role_ids": "1"})
    except WazuhError as e:
        log("gan role: %s" % e)
    log("user API %s id=%s" % (TOOL_USER, uid))


def background(s, t_end, rng):
    """Nen ~2 gio truoc ca: web, ssh thanh cong trong noi bo, dns ngan, netmon toi dich noi bo (khong ticket)."""
    w = s["world"]
    out = []
    t = t_end - 2 * 3600
    hosts = [n for n in w.hosts if n not in ("siem",)]
    while t < t_end:
        t += rng.uniform(4, 9)
        r = rng.random()
        h = rng.choice(hosts)
        if r < 0.45:
            line = chain.lines_web_noise(t, w, rng, 1)[0]
            m = re.search(r'nginx: (\S+) .*"GET (\S+) HTTP/1.1" (\d+)', line)
            out.append(docs.alert(t, "web-shop", "100150", 3, "Web access log", ["web", "accesslog"],
                                  data={"srcip": m.group(1), "url": m.group(2), "id": m.group(3)},
                                  full_log=line, decoder="web-accesslog", program="nginx"))
        elif r < 0.7:
            st = rng.choice(w.staff)
            src = "%s.%d" % (w.subnet_ws, rng.randint(11, 249))
            line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
                docs.syslog_ts(t), h, rng.randint(1000, 60000), st["user"], src, rng.randint(30000, 60000))
            out.append(docs.alert(t, h, "5715", 3, "sshd: authentication success.", ["syslog", "sshd", "authentication_success"],
                                  data={"srcip": src, "dstuser": st["user"]}, full_log=line, decoder="sshd", program="sshd"))
        elif r < 0.9:
            q = rng.choice(["www.google.com", "api.zalo.me", "update.microsoft.com", "mail.congtyx.vn", "erp.congtyx.vn"])
            line = "%s dns-01 dnsmasq[700]: query[A] %s from %s" % (docs.syslog_ts(t), q, w.ip(h))
            out.append(docs.alert(t, "dns-01", "100120", 3, "DNS query", ["dns"], data={"srcip": w.ip(h), "query": q},
                                  full_log=line, decoder="dnsmasq", program="dnsmasq"))
        else:
            dst = w.ip(rng.choice(["dns-01", "siem", "db-core", "file-01"]))
            line = "%s %s netmon: conn dst=%s port=%d proc=%s" % (docs.syslog_ts(t), h, dst, 443, "/usr/bin/curl")
            out.append(docs.alert(t, h, "100140", 3, "netmon: ket noi", ["netmon"],
                                  data={"srcip": w.ip(h), "dstip": dst, "dstport": "443", "process": {"name": "/usr/bin/curl"}},
                                  full_log=line, decoder="netmon", program="netmon"))
    return [(docs.index_name(calendar.timegm(time.strptime(d['@timestamp'][:19], '%Y-%m-%dT%H:%M:%S'))), d) for d in out]


def flags(**kv):
    st = {}
    if os.path.exists(MARK):
        for line in open(MARK):
            if "=" in line:
                k, v = line.strip().split("=", 1)
                st[k] = v
    st.update({k: v for k, v in kv.items()})
    open(MARK + ".tmp", "w").write("".join("%s=%s\n" % kv for kv in sorted(st.items())))
    os.replace(MARK + ".tmp", MARK)
    # tien do cho defender (trang-thai / watcher): chi TEN buoc da xong, khong co gia tri
    try:
        os.makedirs(PUB, exist_ok=True)
        open(os.path.join(PUB, "chuan-bi.json.tmp"), "w").write(json.dumps(
            {"xong": sorted(k for k in st if k != "T0"), "tong": len(BUOC), "t": int(time.time())}))
        os.replace(os.path.join(PUB, "chuan-bi.json.tmp"), os.path.join(PUB, "chuan-bi.json"))
    except OSError:
        pass


def main():
    os.makedirs(ST, exist_ok=True)
    os.chmod(ST, 0o700)
    os.makedirs(PUB, exist_ok=True)
    if os.path.exists(MARK) and "T0=" in open(MARK).read():
        log("da seed truoc do -> bo qua")
        return
    log("bat dau seed")
    # 1) seed ca nhan hoa (giu nguyen qua cac lan chay lai)
    if not os.path.exists(os.path.join(ST, "seed")):
        open(os.path.join(ST, "seed"), "w").write("%d\n" % random.SystemRandom().randint(1, 2 ** 31))
        open(os.path.join(ST, "t_ref"), "w").write("%d\n" % int(time.time()))
    seed = int(open(os.path.join(ST, "seed")).read())
    t_ref = int(open(os.path.join(ST, "t_ref")).read())
    s = ca.build(seed, t_ref)
    json.dump({"answers": s["answers"], "sc": s["sc"], "events": s["events"]}, open(os.path.join(ST, "plan.json"), "w"), indent=1)
    flags(PLAN="OK")
    # 2) Wazuh (cho API dashboard len truoc khi sua cau hinh - tranh restart chong luc boot)
    u, pw = wui_creds()
    if u:
        wait_api(u, pw)
    ok = install_wazuh()
    flags(WAZUH="OK" if ok else "FAIL")
    # 3) user API
    api = wait_api(u, pw) if u else None
    try:
        create_tool_user(api)
        flags(API_USER="OK")
    except Exception as e:  # noqa: BLE001
        log("user API: %s" % e)
        flags(API_USER="FAIL")
    # 4) indexer
    ix = indexer.Indexer()
    ix.wait_ready()
    try:
        for idx in ("ctx-assets", "ctx-changes", "ctx-hr"):
            ix.ensure_index(idx, indexer.CTX_MAPPING)
        n = ix.bulk(s["ctx"].as_docs(), refresh=True)
        ix.wait_dashboard()
        ix.index_pattern("ctx-star", "ctx-*")
        flags(CTX="OK n=%d" % n)
    except Exception as e:  # noqa: BLE001
        log("ctx: %s" % e)
        flags(CTX="FAIL")
    # tu kiem: render MOI ticket + bang chung vao index nhap cung mau template wazuh-alerts-* -> bat xung dot
    # kieu truong (vd data.process la object trong template) NGAY luc seed thay vi luc phat giua ca
    try:
        from socq import cases as _cases
        tmp = "wazuh-alerts-4.x-bai18selftest"
        items = []
        for eid, p in s["plans"].items():
            rr = ca.event_rng(seed, eid, "selftest")
            tk, ev = (chain.render(eid, p, t_ref, s["world"], rr) if eid.startswith("C") else _cases.render(p, t_ref, s["world"], rr))
            items += [(tmp, d) for d in ev[:20]] + [(tmp, docs.ticket(tk, "INC-000"))]
        ix.bulk(items)
        ix.delete_index(tmp)
        flags(RENDER="OK n=%d" % len(items))
    except Exception as e:  # noqa: BLE001
        log("tu kiem render: %s" % e)
        flags(RENDER="FAIL")
        ix.delete_index("wazuh-alerts-4.x-bai18selftest")
    try:
        n = ix.bulk(background(s, int(time.time()), random.Random("%s:nen" % seed)))
        flags(NEN="OK n=%d" % n)
    except Exception as e:  # noqa: BLE001
        log("nen: %s" % e)
        flags(NEN="FAIL")
    # 5) tap an + tap dev (cung the gioi)
    for hidden, name in ((True, "hidden.jsonl"), (False, None)):
        fam = families.build(s["world"], seed, hidden)
        if hidden:
            with open(os.path.join(ST, name), "w") as f:
                for sc in fam["ra"] + fam["rb"]:
                    f.write(json.dumps(sc) + "\n")
        else:
            for k in ("ra", "rb"):
                with open(os.path.join(ST, "dev-%s.jsonl" % k), "w") as f:
                    for sc in fam[k]:
                        f.write(json.dumps(sc) + "\n")
    flags(HIDDEN="OK")
    # 6) T0: sau MOI lan restart cua seed; dashboard da len
    st = shift.State(ST, PUB)
    if not st.t0():
        st.set_t0(int(time.time()))
    st.publish(s["events"])
    flags(T0=str(st.t0()))
    log("xong, T0=%s" % st.t0())
    sh("systemctl start --no-block grade-bai18.service")   # cham lan dau (khong chan lich-ca)


if __name__ == "__main__":
    main()
