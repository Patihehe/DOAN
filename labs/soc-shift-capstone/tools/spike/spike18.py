#!/usr/bin/env python3
# ============================================================================
# spike18.py - spike P1 cua Lab 18, chay TREN siem (root) cua mot lab dang chay
# dung anh soc-wazuh (vd soc-privesc). Can wzapi.py dat cung thu muc.
#
#   python3 spike18.py sa            S-A (1): logtest 3 dinh dang log (khong doi cau hinh)
#   python3 spike18.py sa-live       S-A (2): <localfile> that tren manager -> alerts.json (restart 1 lan)
#   python3 spike18.py sb            S-B   : the luat nao API chap nhan + luat mau R-A/R-B chay that
#   python3 spike18.py sc            S-C   : indexer bulk/search, user chi-doc, index pattern dashboard
#   python3 spike18.py cleanup       go moi thay doi cua spike (localfile, luat, index, user)
#
# Moi lenh in BANG KET QUA de dan vao docs/bai18-trien-khai.md. Ket qua trung gian: /root/.spike18.json
# ============================================================================
import base64, json, os, re, ssl, subprocess, sys, time, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wzapi import Wazuh, WazuhError  # noqa: E402

OSSEC = "/var/ossec"
STATE = "/root/.spike18.json"
LOGDIR = "/var/log/soc-shift"
LOGF = LOGDIR + "/spike.log"
MARK = "<!-- spike18-localfile -->"
_CTX = ssl.create_default_context(); _CTX.check_hostname = False; _CTX.verify_mode = ssl.CERT_NONE


def state(upd=None):
    st = {}
    if os.path.exists(STATE):
        st = json.load(open(STATE))
    if upd:
        st.update(upd); json.dump(st, open(STATE, "w"), indent=1)
    return st


def ts():
    return time.strftime("%b %e %H:%M:%S")          # syslog: ngay 1 chu so dem bang dau cach


def lines_now(tag="SPK"):
    t = ts(); d = time.strftime("%d/%b/%Y:%H:%M:%S %z")
    return {
        "web_syslog": "%s web-shop nginx: 203.0.113.7 - - [%s] \"GET /uploads/av%s.phtml?q=id HTTP/1.1\" 200 512 \"-\" \"curl/8.0\"" % (t, d, tag),
        "web_raw":    "203.0.113.7 - - [%s] \"GET /uploads/av%s.phtml?q=id HTTP/1.1\" 200 512 \"-\" \"curl/8.0\"" % (d, tag),
        "netfilter":  "%s web-shop kernel: [12345.678] ACCEPT IN=eth0 OUT= MAC= SRC=10.10.20.5 DST=10.10.30.11 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=1 DF PROTO=TCP SPT=40000 DPT=445 WINDOW=64240 RES=0x00 SYN URGP=0 %s" % (t, tag),
        "named":      "%s dns-01 named[812]: client @0x7f00 10.10.20.5#53211 (%s.x7q.exfil-cdn.net): query: %s.x7q.exfil-cdn.net IN TXT +E(0) (10.10.10.53)" % (t, tag.lower(), tag.lower()),
    }


def api():
    w = Wazuh("https://127.0.0.1:55000")
    w.login()
    return w


def flat(d, p=""):
    out = {}
    for k, v in (d or {}).items():
        if isinstance(v, dict):
            out.update(flat(v, p + k + "."))
        else:
            out[p + k] = v
    return out


# ------------------------------------------------------------------ S-A (1)
def do_sa():
    w = api(); res = {}
    print("== S-A (1): wazuh-logtest qua API, KHONG doi cau hinh\n")
    for name, line in lines_now().items():
        tok, out = w.logtest(line, None, location=LOGF)
        w.logtest_close(tok)
        dec = (out.get("decoder") or {}).get("name"); par = (out.get("decoder") or {}).get("parent")
        pre = out.get("predecoder") or {}
        rule = out.get("rule") or {}
        fields = {k: v for k, v in flat(out.get("data")).items()}
        for k in ("srcip", "dstip", "dstport", "srcport", "url", "id", "protocol", "action"):
            if k in out:
                fields[k] = out[k]
        res[name] = {"decoder": dec, "parent": par, "hostname": pre.get("hostname"), "program": pre.get("program_name"),
                     "rule": rule.get("id"), "level": rule.get("level"), "groups": rule.get("groups"), "fields": fields}
        print("[%s]\n  decoder : %s (parent %s)   predecoder.hostname=%s program=%s" % (name, dec, par, pre.get("hostname"), pre.get("program_name")))
        print("  truong  : %s" % json.dumps(fields, ensure_ascii=False)[:300])
        print("  luat    : %s lv%s groups=%s\n" % (rule.get("id"), rule.get("level"), rule.get("groups")))
    state({"sa": res})
    print("Can xem: web_* co 'url' va 'srcip' khong; netfilter co 'srcip','dstip','dstport'; named co ten mien o truong nao.")


# ------------------------------------------------------------------ S-A (2)
def conf_add_localfile():
    p = OSSEC + "/etc/ossec.conf"; c = open(p).read()
    if MARK in c:
        return False
    blk = ("\n<ossec_config>\n  %s\n  <localfile>\n    <log_format>syslog</log_format>\n"
           "    <location>%s/*.log</location>\n  </localfile>\n</ossec_config>\n") % (MARK, LOGDIR)
    open(p, "a").write(blk)
    return True


def conf_del_localfile():
    p = OSSEC + "/etc/ossec.conf"; c = open(p).read()
    c2 = re.sub(r"\n<ossec_config>\n  " + re.escape(MARK) + r".*?</ossec_config>\n", "\n", c, flags=re.S)
    if c2 != c:
        open(p, "w").write(c2); return True
    return False


def restart():
    subprocess.run([OSSEC + "/bin/wazuh-control", "restart"], capture_output=True)
    for _ in range(60):
        st = subprocess.run([OSSEC + "/bin/wazuh-control", "status"], capture_output=True, text=True).stdout
        if "wazuh-analysisd is running" in st and "wazuh-logcollector is running" in st:
            return True
        time.sleep(5)
    return False


def do_sa_live():
    print("== S-A (2): <localfile> %s/*.log tren manager" % LOGDIR)
    os.makedirs(LOGDIR, exist_ok=True); open(LOGF, "a").close()
    # Tu nap 3 luat thu level 3 (khong phu thuoc 'sb'): luat nen 31100/4100/12100 deu level 0 -> khong ghi alerts.json
    w = api(); st = state()
    if "orig_rules" not in st:
        state({"orig_rules": w.get_rule_file("local_rules.xml")})
    probe = ('<group name="spike18,">\n'
             '  <rule id="100336" level="3">\n    <if_sid>31100</if_sid>\n    <url>SPK</url>\n    <description>spike web</description>\n  </rule>\n'
             '  <rule id="100337" level="3">\n    <if_sid>4100</if_sid>\n    <match>SPK</match>\n    <description>spike fw</description>\n  </rule>\n'
             '  <rule id="100338" level="3">\n    <if_sid>12100</if_sid>\n    <match>spk</match>\n    <description>spike dns</description>\n  </rule>\n'
             '</group>\n')
    e = put_try(w, probe)
    print("  nap 3 luat thu (100336-100338):", "OK" if e is None else "TU CHOI " + e)
    conf_add_localfile()
    t = subprocess.run([OSSEC + "/bin/wazuh-analysisd", "-t"], capture_output=True, text=True)
    print("  analysisd -t rc=%s" % t.returncode)
    print("  restart manager ...", "OK" if restart() else "CHUA LEN")
    time.sleep(15)            # logcollector bat dau doc file
    tag = "SPK%d" % (int(time.time()) % 100000)
    ls = lines_now(tag)
    alerts = OSSEC + "/logs/alerts/alerts.json"
    pos = os.path.getsize(alerts)
    t0 = time.time()
    with open(LOGF, "a") as f:
        for name in ("web_syslog", "netfilter", "named"):
            f.write(ls[name] + "\n")
    print("  da ghi 3 dong (tag %s) luc %s, doi canh bao toi da 60s ..." % (tag, time.strftime("%H:%M:%S")))
    found = {}
    while time.time() - t0 < 60 and len(found) < 3:
        time.sleep(2)
        with open(alerts) as f:
            f.seek(pos)
            for l in f:
                if tag.lower() not in l.lower():
                    continue
                a = json.loads(l)
                full = a.get("full_log", "")
                name = "web_syslog" if "nginx" in full else "netfilter" if "kernel" in full else "named"
                if name not in found:
                    found[name] = (round(time.time() - t0, 1), a)
    res = {}
    for name in ("web_syslog", "netfilter", "named"):
        if name not in found:
            print("  [%-10s] KHONG thay canh bao trong 60s (co the luat nen level 0 -> khong ghi alerts.json; xem S-A (1))" % name)
            res[name] = None; continue
        dt, a = found[name]
        info = {"giay": dt, "agent": a.get("agent", {}).get("name"), "hostname": (a.get("predecoder") or {}).get("hostname"),
                "location": a.get("location"), "rule": a["rule"]["id"], "level": a["rule"]["level"],
                "srcip": (a.get("data") or {}).get("srcip"), "dstip": (a.get("data") or {}).get("dstip"),
                "dstport": (a.get("data") or {}).get("dstport"), "url": (a.get("data") or {}).get("url")}
        res[name] = info
        print("  [%-10s] %4ss  agent=%s hostname=%s rule=%s lv%s srcip=%s dstip=%s dstport=%s url=%s" % (
            name, dt, info["agent"], info["hostname"], info["rule"], info["level"], info["srcip"], info["dstip"], info["dstport"], info["url"]))
    state({"sa_live": res})
    print("\nDat khi: canh bao <=10s, hostname=web-shop/dns-01 (khong phai siem), co srcip/dstip/dstport/url.")
    print("Luu y: luat nen level < 3 khong ghi alerts.json -> dong do van DI QUA analysisd (luat SV van no duoc).")


# ------------------------------------------------------------------ S-B
TAG_TESTS = [
    ("url pcre2",            '<if_group>web</if_group>\n    <url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>'),
    ("url (osregex)",        '<if_group>web</if_group>\n    <url>^/uploads/</url>'),
    ("field url",            '<if_group>web</if_group>\n    <field name="url">^/uploads/</field>'),
    ("id (status)",          '<if_group>web</if_group>\n    <id>^200$</id>'),
    ("dstport",              '<if_group>firewall</if_group>\n    <dstport>^445$</dstport>'),
    ("field dstport",        '<if_group>firewall</if_group>\n    <field name="dstport">^445$</field>'),
    ("dstip",                '<if_group>firewall</if_group>\n    <dstip>10.10.30.0/24</dstip>'),
    ("srcip",                '<if_group>firewall</if_group>\n    <srcip>10.10.20.5</srcip>'),
    ("list srcip address",   '<if_group>firewall</if_group>\n    <list field="srcip" lookup="address_match_key">etc/lists/spike18-hosts</list>'),
    ("list dstport key",     '<if_group>firewall</if_group>\n    <list field="dstport" lookup="match_key">etc/lists/spike18-ports</list>'),
]
FREQ_TESTS = [
    ("same_srcip",           "<same_srcip />"),
    ("different_dstip",      "<different_dstip />"),
    ("different_dstport",    "<different_dstport />"),
    ("different_field dstip", "<different_field>dstip</different_field>"),
]


def put_try(w, xml):
    r = w._req("PUT", "/rules/files/local_rules.xml", raw=xml, ctype="application/octet-stream", params={"overwrite": "true"})
    f = ((r.get("data") or {}).get("failed_items") or [])
    return None if not f else "%s %s" % (f[0]["error"].get("code"), f[0]["error"].get("message"))


def wrap(body, extra=""):
    return '<group name="spike18,">\n  <rule id="100339" level="10"%s>\n    %s\n    <description>spike</description>\n  </rule>\n</group>\n' % (extra, body)


def do_sb():
    w = api(); st = state()
    orig = w.get_rule_file("local_rules.xml")
    if "orig_rules" not in st:
        state({"orig_rules": orig})
    for n, c in (("spike18-hosts", "10.10.20.5:\n"), ("spike18-ports", "9102:\n")):
        w.put_list_file(n, c)
    print("== S-B (1): the nao Wazuh API chap nhan (khong restart)")
    ok = {}
    for name, body in TAG_TESTS:
        e = put_try(w, wrap(body)); ok[name] = e is None
        print("   %-24s %s" % (name, "OK" if e is None else "TU CHOI " + e))
    sa = st.get("sa", {})
    fw_sid = (sa.get("netfilter") or {}).get("rule") or "4100"
    for name, tag in FREQ_TESTS:
        e = put_try(w, wrap("<if_matched_sid>%s</if_matched_sid>\n    %s" % (fw_sid, tag), ' frequency="8" timeframe="120"'))
        ok[name] = e is None
        print("   %-24s %s" % (name, "OK" if e is None else "TU CHOI " + e))
    state({"sb_tags": ok})

    # ---- (2) luat mau chay THAT (can khai bao list trong ossec.conf + restart) ----
    web_sid = (sa.get("web_syslog") or {}).get("rule") or (sa.get("web_raw") or {}).get("rule")
    print("\n== S-B (2): luat mau R-A / R-B tren Wazuh that (luat nen: web=%s, firewall=%s)" % (web_sid, fw_sid))
    if not web_sid:
        print("   Chua co ket qua S-A -> chay 'sa' truoc."); return
    ra_url = '<url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>' if ok.get("url pcre2") else '<url>^/uploads/\\S+.ph\\w+?</url>'
    diff = "<different_dstip />" if ok.get("different_dstip") else ("<different_field>dstip</different_field>" if ok.get("different_field dstip") else "")
    port_ok = ok.get("list dstport key") or ok.get("dstport")
    exc_port = ('<list field="dstport" lookup="match_key">etc/lists/spike18-ports</list>' if ok.get("list dstport key")
                else "<dstport>^9102$</dstport>")
    xml = ('<group name="spike18,">\n'
           '  <rule id="100330" level="12">\n    <if_sid>%s</if_sid>\n    %s\n    <description>R-A mau</description>\n'
           '    <mitre><id>T1505.003</id></mitre>\n  </rule>\n'
           '  <rule id="100341" level="0">\n    <if_sid>%s</if_sid>\n'
           '    <list field="srcip" lookup="address_match_key">etc/lists/spike18-hosts</list>\n    %s\n'
           '    <description>ngoai le sao luu</description>\n  </rule>\n'
           '  <rule id="100340" level="10" frequency="8" timeframe="120">\n    <if_matched_sid>%s</if_matched_sid>\n'
           '    <same_srcip />\n    %s\n    <description>R-B mau: 1 may toi nhieu dich</description>\n'
           '    <mitre><id>T1046</id></mitre>\n  </rule>\n</group>\n') % (web_sid, ra_url, fw_sid, exc_port, fw_sid, diff)
    print(xml)
    e = put_try(w, xml)
    if e:
        print("   TU CHOI ca bo: " + e); return
    c = open(OSSEC + "/etc/ossec.conf").read()
    if "etc/lists/spike18-hosts" not in c:
        c = c.replace("<ruleset>", "<ruleset>\n    <list>etc/lists/spike18-hosts</list>\n    <list>etc/lists/spike18-ports</list>", 1)
        open(OSSEC + "/etc/ossec.conf", "w").write(c)
    okv, msg = w.validate(); print("   validate:", okv, msg[:150])
    if not okv:
        return
    print("   restart ...", "OK" if w.restart() else "CHUA LEN")

    def run(lines):
        tok = None; ids = []
        for l in lines:
            tok, out = w.logtest(l, tok, location=LOGF)
            ids.append((out.get("rule") or {}).get("id"))
        w.logtest_close(tok)
        return ids
    t = ts(); d = time.strftime("%d/%b/%Y:%H:%M:%S %z")
    web = lambda u: "%s web-shop nginx: 203.0.113.7 - - [%s] \"GET %s HTTP/1.1\" 200 88 \"-\" \"curl/8.0\"" % (t, d, u)
    fw = lambda s, dst, p: "%s web-shop kernel: [1.0] ACCEPT IN=eth0 OUT= SRC=%s DST=%s LEN=60 PROTO=TCP SPT=40000 DPT=%d SYN URGP=0" % (t, s, dst, p)
    cases = [
        ("R-A webshell tham so la",     [web("/uploads/av.phtml?zq=whoami")], "100330"),
        ("R-A anh binh thuong",         [web("/uploads/logo.png")], None),
        ("R-A script khong query",      [web("/uploads/av.phtml")], None),
        ("R-B quet 10 dich tu web-shop", [fw("10.10.20.9", "10.10.30.%d" % i, 445) for i in range(1, 13)], "100340"),
        ("R-B sao luu dung cong 9102",  [fw("10.10.20.5", "10.10.30.%d" % i, 9102) for i in range(1, 13)], None),
        ("R-B sao luu SAI cong (22)",   [fw("10.10.20.5", "10.10.30.%d" % i, 22) for i in range(1, 13)], "100340"),
        ("R-B 1 dich nhieu lan",        [fw("10.10.20.9", "10.10.30.1", 445) for i in range(12)], None),
    ]
    print("\n   %-30s %-10s %s" % ("kich ban", "mong doi", "luat no (tung dong)"))
    res = {}
    for name, ls, exp in cases:
        ids = run(ls)
        hit = exp in ids if exp else not any(i in ("100330", "100340") for i in ids)
        res[name] = hit
        print("   %-30s %-10s %s %s" % (name, exp or "khong", "DUNG" if hit else "SAI ", ids))
    state({"sb_func": res, "sb_xml": xml})
    print("\nDat khi: moi dong DUNG. Neu 'different_dstip' bi tu choi, R-B mau chay khong co dieu kien 'khac dich' ->"
          " kich ban '1 dich nhieu lan' se SAI: can cach khac (xem bao cao).")


# ------------------------------------------------------------------ S-B2: vi sao R-B tan suat khong no?
def rb_variant(mid_level, diff, exc_parent):
    """mid_level=None: dem thang tren 4100 (level 0). Con lai: them luat trung gian 100342 (su kien ket noi)."""
    diff_tag = {"dstip": "<different_dstip />", "field": "<different_field>dstip</different_field>", None: ""}[diff]
    exc = ('  <rule id="100341" level="0">\n    <if_sid>%s</if_sid>\n'
           '    <list field="srcip" lookup="address_match_key">etc/lists/spike18-hosts</list>\n'
           '    <list field="dstport" lookup="match_key">etc/lists/spike18-ports</list>\n'
           '    <description>ngoai le sao luu</description>\n  </rule>\n')
    if mid_level is None:
        return ('<group name="spike18,">\n' + exc % "4100" +
                '  <rule id="100340" level="10" frequency="8" timeframe="120">\n    <if_matched_sid>4100</if_matched_sid>\n'
                '    <same_srcip />\n    %s\n    <description>R-B</description>\n    <mitre><id>T1046</id></mitre>\n  </rule>\n</group>\n') % diff_tag
    return ('<group name="spike18,">\n'
            '  <rule id="100342" level="%d">\n    <if_sid>4100</if_sid>\n'
            '    <description>su kien ket noi</description>\n  </rule>\n' % mid_level
            + exc % ("100342" if exc_parent == "mid" else "4100") +
            '  <rule id="100340" level="10" frequency="8" timeframe="120">\n    <if_matched_sid>100342</if_matched_sid>\n'
            '    <same_srcip />\n    %s\n    <description>R-B</description>\n    <mitre><id>T1046</id></mitre>\n  </rule>\n</group>\n') % diff_tag


def do_sb2():
    w = api(); st = state()
    if "orig_rules" not in st:
        state({"orig_rules": w.get_rule_file("local_rules.xml")})
    for n, c in (("spike18-hosts", "10.10.20.5:\n"), ("spike18-ports", "9102:\n")):
        w.put_list_file(n, c)
    c = open(OSSEC + "/etc/ossec.conf").read()
    if "etc/lists/spike18-hosts" not in c:
        c = c.replace("<ruleset>", "<ruleset>\n    <list>etc/lists/spike18-hosts</list>\n    <list>etc/lists/spike18-ports</list>", 1)
        open(OSSEC + "/etc/ossec.conf", "w").write(c)
    t = ts()
    fw = lambda s, dst, p: "%s web-shop kernel: [1.0] ACCEPT IN=eth0 OUT= SRC=%s DST=%s LEN=60 PROTO=TCP SPT=40000 DPT=%d SYN URGP=0" % (t, s, dst, p)
    cases = [
        ("quet 12 dich",       [fw("10.10.20.9", "10.10.30.%d" % i, 445) for i in range(1, 13)], True),
        ("1 dich x12",         [fw("10.10.20.9", "10.10.30.1", 445) for _ in range(12)], False),
        ("sao luu dung cong",  [fw("10.10.20.5", "10.10.30.%d" % i, 9102) for i in range(1, 13)], False),
        ("sao luu sai cong",   [fw("10.10.20.5", "10.10.30.%d" % i, 22) for i in range(1, 13)], True),
    ]
    V = [
        ("V1 dem tren 4100 (lv0), khong 'khac dich'", (None, None, "4100")),
        ("V2 trung gian lv3, different_dstip",        (3, "dstip", "mid")),
        ("V3 trung gian lv3, khong 'khac dich'",      (3, None, "mid")),
        ("V4 trung gian lv3, different_field dstip",  (3, "field", "mid")),
        ("V5 trung gian lv1, different_dstip",        (1, "dstip", "mid")),
    ]
    print("== S-B2: R-B tan suat - moi bien the: nap -> restart -> logtest 4 kich ban (12 dong/kich ban)\n")
    out = {}
    for name, args in V:
        xml = rb_variant(*args)
        e = put_try(w, xml)
        if e:
            print("%-44s TU CHOI %s" % (name, e)); continue
        okv, msg = w.validate()
        if not okv:
            print("%-44s KHONG HOP LE %s" % (name, msg[:100])); continue
        w.restart()
        row = []
        for cname, ls, exp in cases:
            tok = None; ids = []
            for l in ls:
                tok, o = w.logtest(l, tok, location=LOGF)
                ids.append((o.get("rule") or {}).get("id"))
            w.logtest_close(tok)
            fired = "100340" in ids
            row.append("%s:%s%s" % (cname, "NO" if fired else "-", "" if fired == exp else "(SAI)"))
            out.setdefault(name, {})[cname] = {"fired": fired, "first": ids.index("100340") + 1 if fired else None,
                                                "last_ids": ids[-3:]}
        print("%-44s %s" % (name, "  ".join(row)))
        for cname, r in out[name].items():
            if r["fired"]:
                print("      %-18s no o dong thu %s" % (cname, r["first"]))
    state({"sb2": out})
    print("\nMong doi: 'quet 12 dich' NO, '1 dich x12' -, 'sao luu dung cong' -, 'sao luu sai cong' NO (khong co (SAI)).")


# ------------------------------------------------------------------ S-C
def admin_pw():
    t = open("/root/wazuh-admin-credentials.txt").read()
    return re.search(r"indexer_password:\s*'([^']+)'", t).group(1)


def ix(method, path, body=None, user="admin", pw=None, base="https://127.0.0.1:9200", nd=False, hdr=None):
    pw = pw or admin_pw()
    data = None
    if body is not None:
        data = (body if isinstance(body, str) else json.dumps(body)).encode()
    req = urllib.request.Request(base + path, data=data, method=method)
    req.add_header("Authorization", "Basic " + base64.b64encode(("%s:%s" % (user, pw)).encode()).decode())
    req.add_header("Content-Type", "application/x-ndjson" if nd else "application/json")
    for k, v in (hdr or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, context=_CTX, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, (e.read().decode()[:300])
    except Exception as e:  # noqa: BLE001
        return 0, str(e)[:300]


def do_sc():
    print("== S-C: indexer + user chi-doc + index pattern")
    res = {}
    c, h = ix("GET", "/_cluster/health"); res["health"] = (c, h.get("status") if isinstance(h, dict) else h)
    print("   cluster health          :", res["health"])
    idx = "wazuh-alerts-4.x-" + time.strftime("%Y.%m.%d")
    now = time.strftime("%Y-%m-%dT%H:%M:%S.000+0000", time.gmtime())
    doc = {"@timestamp": now, "timestamp": now, "agent": {"id": "000", "name": "siem"},
           "manager": {"name": "siem"}, "rule": {"id": "100399", "level": 12, "description": "SPIKE18 ticket thu",
           "groups": ["soc_queue"]}, "data": {"ticket": "SPIKE-1", "srcip": "203.0.113.7"},
           "predecoder": {"hostname": "web-shop"}, "location": "spike18", "full_log": "spike18"}
    bulk = json.dumps({"index": {"_index": idx}}) + "\n" + json.dumps(doc) + "\n"
    c, r = ix("POST", "/_bulk?refresh=true", bulk, nd=True)
    errs = r.get("errors") if isinstance(r, dict) else r
    res["bulk"] = (c, errs); print("   bulk vao %s : HTTP %s errors=%s" % (idx, c, errs))
    c, r = ix("POST", "/wazuh-alerts-*/_search", {"query": {"term": {"data.ticket": "SPIKE-1"}}})
    hits = r.get("hits", {}).get("total", {}).get("value") if isinstance(r, dict) else r
    res["search"] = hits; print("   tim lai data.ticket     :", hits, "(mo Discover, tim data.ticket:SPIKE-1)")
    for i in ("soc-shift-spike", "soc-shift-gt-spike"):
        ix("PUT", "/" + i); ix("POST", "/%s/_doc?refresh=true" % i, {"t0": int(time.time()), "note": i})
    role = {"cluster_permissions": ["cluster_composite_ops_ro"],
            "index_permissions": [{"index_patterns": ["wazuh-alerts-*", "ctx-*", "soc-shift-spike"],
                                   "allowed_actions": ["read", "indices:admin/mappings/get"]}]}
    c1, _ = ix("PUT", "/_plugins/_security/api/roles/spike18_ro", role)
    c2, r2 = ix("PUT", "/_plugins/_security/api/internalusers/spike18_analyst", {"password": "Spike.Analyst.2026!", "backend_roles": []})
    c3, _ = ix("PUT", "/_plugins/_security/api/rolesmapping/spike18_ro", {"users": ["spike18_analyst"]})
    res["users"] = (c1, c2, c3); print("   tao role/user/mapping   : HTTP %s %s %s %s" % (c1, c2, c3, "" if c2 in (200, 201) else r2))
    time.sleep(2)
    for target, base in (("indexer :9200", "https://172.20.0.20:9200"),):
        ca, _ = ix("POST", "/soc-shift-spike/_search", {}, user="spike18_analyst", pw="Spike.Analyst.2026!", base=base)
        cb, _ = ix("POST", "/soc-shift-gt-spike/_search", {}, user="spike18_analyst", pw="Spike.Analyst.2026!", base=base)
        res["ro_" + target] = (ca, cb)
        print("   analyst doc soc-shift (%s): %s   doc soc-shift-gt: %s (mong doi 200 / 403)" % (target, ca, cb))
    c, r = ix("POST", "/api/saved_objects/index-pattern/spike18-ctx", {"attributes": {"title": "ctx-spike*", "timeFieldName": "@timestamp"}},
              base="https://127.0.0.1", hdr={"osd-xsrf": "true"})
    res["index_pattern"] = c; print("   tao index pattern (dashboard API): HTTP %s %s" % (c, "" if c in (200, 409) else str(r)[:150]))
    state({"sc": res})
    print("\nTu DEFENDER kiem them (doi IP neu khac):")
    print("   curl -sk -u 'spike18_analyst:Spike.Analyst.2026!' https://172.20.0.20:9200/soc-shift-spike/_search | head -c 300")


# ------------------------------------------------------------------ cleanup
def do_cleanup():
    st = state()
    if conf_del_localfile():
        print("   go <localfile> spike")
    c = open(OSSEC + "/etc/ossec.conf").read()
    c2 = c.replace("\n    <list>etc/lists/spike18-hosts</list>\n    <list>etc/lists/spike18-ports</list>", "")
    if c2 != c:
        open(OSSEC + "/etc/ossec.conf", "w").write(c2); print("   go khai bao list spike")
    if "orig_rules" in st:
        try:
            w = api(); w.put_rule_file("local_rules.xml", st["orig_rules"]); print("   tra lai local_rules.xml")
        except WazuhError as e:
            print("   KHONG tra lai duoc local_rules.xml:", e)
    for n in ("spike18-hosts", "spike18-ports"):
        p = OSSEC + "/etc/lists/" + n
        if os.path.exists(p):
            os.remove(p)
    for p in ("/soc-shift-spike", "/soc-shift-gt-spike", "/_plugins/_security/api/internalusers/spike18_analyst",
              "/_plugins/_security/api/rolesmapping/spike18_ro", "/_plugins/_security/api/roles/spike18_ro"):
        ix("DELETE", p)
    ix("POST", "/wazuh-alerts-*/_delete_by_query?refresh=true", {"query": {"term": {"data.ticket": "SPIKE-1"}}})
    ix("DELETE", "/api/saved_objects/index-pattern/spike18-ctx", base="https://127.0.0.1", hdr={"osd-xsrf": "true"})
    print("   xoa index/user/doc spike; restart manager ...", "OK" if restart() else "CHUA LEN")
    if os.path.exists(STATE):
        os.rename(STATE, STATE + ".done")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    fn = {"sa": do_sa, "sa-live": do_sa_live, "sb": do_sb, "sb2": do_sb2, "sc": do_sc, "cleanup": do_cleanup}.get(cmd)
    if not fn:
        print("Dung: python3 spike18.py sa | sa-live | sb | sb2 | sc | cleanup"); sys.exit(1)
    fn()
