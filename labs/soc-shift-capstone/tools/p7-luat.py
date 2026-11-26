#!/usr/bin/env python3
# ============================================================================
# p7-luat.py - P7 nhom A (CHI phat trien): cham TAP AN cho cac bien the luat T5-T10 (lo trinh P7),
# khong can chay ca. Chay ROOT tren siem:
#   docker cp labs/soc-shift-capstone/tools/p7-luat.py <siem>:/home/ubuntu/bai18/
#   docker exec <siem> python3 /home/ubuntu/bai18/p7-luat.py
# Moi bien the: ghi local_rules.xml (tu giai mau cua SV nay) -> analysisd -t -> restart -> grade18 rules.
# Cuoi cung NAP LAI giai mau. Lam SAU khi ca da het (lich su nap luat bi ghi them), roi reset-ca.
# ============================================================================
import os, re, subprocess, sys, time

sys.path.insert(0, "/home/ubuntu/bai18")
sys.path.insert(0, "/home/ubuntu/bai18/lib")
import grade18 as g  # noqa: E402
import socq.ca as ca  # noqa: E402

ST = g.ST


def world():
    s = ca.build(int(open(os.path.join(ST, "seed")).read()), int(open(os.path.join(ST, "t_ref")).read()))
    return s["world"], s["ctx"]


def mau_xml(w, cx):
    return g.MAU_XML % {"script": (w.upload_dir + w.approved_script).replace(".", "\\."), "svc": cx.svc_upload, "chg": cx.chg_backup}


def sub_rule(xml, rid, new):
    """Thay ca khoi <rule id="rid" ...>...</rule> (new='' -> xoa)."""
    return re.sub(r'\s*<rule id="%s".*?</rule>' % rid, ("\n  " + new) if new else "", xml, flags=re.S)


def variants(w, cx):
    m = mau_xml(w, cx)
    net = w.ip("web-shop").rsplit(".", 1)[0] + ".0/24"
    ex = lambda cond: ('<rule id="100341" level="0">\n    <if_sid>100342</if_sid>\n    %s\n'  # noqa: E731
                       '    <description>ngoai le (bien the P7)</description>\n  </rule>' % cond)
    return [
        ("T9  giai mau (ngoai le may sao luu VA cong)", m, {"RB_NOT_BLIND": True, "RA_R100": 100, "RB_R100": 100}),
        ("T5a ha 100340 xuong level 3", m.replace('id="100340" level="10"', 'id="100340" level="3"'), {"RB_NOT_BLIND": False}),
        ("T5b xoa luat 100340", sub_rule(m, "100340", ""), {"RB_NOT_BLIND": False}),
        ("T6  nguong tan suat x10", m.replace('frequency="8"', 'frequency="80"'), {"RB_NOT_BLIND": False}),
        ("T7  loai tru ca dai noi bo %s" % net, sub_rule(m, "100341", ex("<srcip>%s</srcip>" % net)), {"RB_NOT_BLIND": False}),
        ("T8  loai tru theo cong 22", sub_rule(m, "100341", ex("<dstport>22</dstport>")), {"RB_NOT_BLIND": False}),
        ("T10 R-A chi bat cmd=", m.replace('<url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>',
                                            '<url type="pcre2">[?&amp;]cmd=</url>'), {"RA_R100_MAX": 89}),
    ]


def load(xml):
    open(g.RULES, "w").write(xml)
    subprocess.run("chown wazuh:wazuh %s" % g.RULES, shell=True)
    t = subprocess.run(["/var/ossec/bin/wazuh-analysisd", "-t"], capture_output=True, text=True)
    if t.returncode != 0:
        return "analysisd -t LOI: " + (t.stdout + t.stderr).strip()[-200:]
    subprocess.run("/var/ossec/bin/wazuh-control restart >/dev/null 2>&1", shell=True)
    return None


def main():
    if os.geteuid() != 0:
        raise SystemExit("can root")
    w, cx = world()
    g.do_mau(True)                     # lists giai mau (sao-luu-hosts/ports) cho moi bien the
    subprocess.run("systemctl stop grade-bai18.path", shell=True)   # khong cham chong khi doi file luat
    bad = 0
    try:
        for name, xml, exp in variants(w, cx):
            t0 = time.time()
            err = load(xml)
            if err:
                print("%-48s %s" % (name, err))
                bad += 1
                continue
            g.do_rules(0)
            txt = open(os.path.join(ST, "rules.txt")).read()
            kv = dict(re.findall(r"\b([A-Z0-9_]+)=(\S+)", txt))
            got = {"RB_NOT_BLIND": "RB_NOT_BLIND" in txt}
            errs = []
            for k, v in exp.items():
                if k == "RA_R100_MAX":
                    if int(kv.get("RA_R100", 0)) > v:
                        errs.append("RA_R100=%s (can <= %d)" % (kv.get("RA_R100"), v))
                elif k == "RB_NOT_BLIND":
                    if got[k] != v:
                        errs.append("RB_NOT_BLIND=%s (can %s)" % (got[k], v))
                elif int(kv.get(k, -1)) != v:
                    errs.append("%s=%s (can %s)" % (k, kv.get(k), v))
            bad += bool(errs)
            print("%-48s RA P/R=%s/%s RB P/R=%s/%s %s  (%ds) %s" % (
                name, kv.get("RA_P100"), kv.get("RA_R100"), kv.get("RB_P100"), kv.get("RB_R100"),
                "NOT_BLIND" if got["RB_NOT_BLIND"] else "MU", time.time() - t0, ("LOI: " + "; ".join(errs)) if errs else "OK"))
            sys.stdout.flush()
    finally:
        g.do_mau(True)                 # tra lai giai mau
        subprocess.run("systemctl start grade-bai18.path", shell=True)
    print("%d loi" % bad)


if __name__ == "__main__":
    main()
