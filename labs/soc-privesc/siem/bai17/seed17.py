#!/usr/bin/env python3
# ============================================================================
# seed17.py - khoi tao siem cho Bai 17. Chay BOI SYSTEMD (seed-bai17.service) luc boot, quyen root.
# (Tren anh chung soc-wazuh, hook fixlocal/parameter cua Labtainers BI BO QUA -> moi viec o day.)
#
#   1) Cai bo luat "nguyen trang" bo sung: luat san xuat 100300, decoder con sudo.program,
#      khai bao 3 CDB list (rong) trong ossec.conf -> restart manager.
#   2) Tao user API 'soc-tool' (cong cu kiem-thu-luat / thu-dong tren defender dung).
#   3) Sinh TAP KIEM TRA AN (self-random) -> /root/.bai17/hidden.jsonl, kiem bat bien.
#   4) Tu kiem decoder (logtest 1 dong sudo) -> DECODER_OK / DECODER_FAIL.
#   5) Ghi marker /root/.bai17/seeded (prestop doc). Chay lai: bo qua neu da co marker.
# ============================================================================
import glob, json, os, re, shutil, subprocess, sys, time

HERE = "/home/ubuntu/bai17"
sys.path.insert(0, os.path.join(HERE, "lib"))
from wzapi import Wazuh, WazuhError  # noqa: E402

ST = "/root/.bai17"
MARK = os.path.join(ST, "seeded")
OSSEC = "/var/ossec"
LISTS = ["gtfo-shell", "sudo-approved", "admin-hosts"]
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"
LOG = os.path.join(ST, "seed.log")


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def wui_creds():
    """Tai khoan API ma dashboard dang dung (anh chung khong con file mat khau cai dat)."""
    for p in glob.glob("/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"):
        txt = open(p).read()
        u = re.search(r"username:\s*['\"]?([^'\"\n]+)", txt)
        pw = re.search(r"password:\s*['\"]?([^'\"\n]+)", txt)
        if u and pw:
            return u.group(1).strip(), pw.group(1).strip()
    return None, None


SUDO_DEC = "0320-sudo_decoders.xml"
CMD_RE = re.compile(r'<regex offset="after_regex">COMMAND=\(\\\.\+\)</regex>(\s*)<order>command</order>')
CMD_NEW = r'<regex type="pcre2" offset="after_regex">COMMAND=((\\S+).*)</regex>\1<order>command, sudo.program</order>'


def override_sudo_decoder():
    """Wazuh 4.14: decoder sudo goc la chuoi decoder anh em noi tiep (offset after_regex), decoder
    cuoi COMMAND=(\\.+) an het dong -> decoder anh em them o file khac khong duoc chay.
    Cach chuan cua Wazuh: chep file goc sang etc/decoders, sua, va decoder_exclude file goc.
    Sua: tach COMMAND bang pcre2 2 nhom -> command (giu nguyen nhu cu) + sudo.program (duong dan)."""
    src = OSSEC + "/ruleset/decoders/" + SUDO_DEC
    txt = open(src).read()
    new, n = CMD_RE.subn(CMD_NEW, txt)
    log("decoder sudo: sua %d cho COMMAND" % n)
    if n == 0:
        return False
    hdr = "<!-- Bai 17: ban sua cua %s - them truong sudo.program (duong dan chuong trinh, khong kem tham so) -->\n" % SUDO_DEC
    open(OSSEC + "/etc/decoders/" + SUDO_DEC, "w").write(hdr + new)
    return True


def install_ruleset():
    shutil.copy(os.path.join(HERE, "bai17_prod_rules.xml"), OSSEC + "/etc/rules/bai17_prod_rules.xml")
    if os.path.exists(OSSEC + "/etc/decoders/bai17_decoders.xml"):
        os.remove(OSSEC + "/etc/decoders/bai17_decoders.xml")   # ban cu (decoder anh em) khong chay
    dec_ok = override_sudo_decoder()
    for n in LISTS:
        p = OSSEC + "/etc/lists/" + n
        if not os.path.exists(p):
            open(p, "w").write("lab-placeholder:\n")
    conf = open(OSSEC + "/etc/ossec.conf").read()
    add = "".join("    <list>etc/lists/%s</list>\n" % n for n in LISTS if "etc/lists/%s<" % n not in conf)
    excl = "<decoder_exclude>ruleset/decoders/%s</decoder_exclude>" % SUDO_DEC
    if dec_ok and excl not in conf:
        add += "    %s\n" % excl
    if add:
        conf = conf.replace("<ruleset>", "<ruleset>\n" + add.rstrip("\n"), 1)
        open(OSSEC + "/etc/ossec.conf", "w").write(conf)
    sh("chown -R wazuh:wazuh %s/etc/rules %s/etc/decoders %s/etc/lists 2>/dev/null" % (OSSEC, OSSEC, OSSEC))
    sh("chmod 660 %s/etc/rules/*.xml %s/etc/decoders/*.xml 2>/dev/null" % (OSSEC, OSSEC))
    api_timeout()
    t = sh(OSSEC + "/bin/wazuh-analysisd -t")
    log("kiem tra cau hinh analysisd rc=%s %s" % (t.returncode, (t.stdout + t.stderr).strip()[-300:]))
    if t.returncode != 0:
        # cau hinh hong -> go phan minh them, khong de manager chet
        # go ban sua decoder + decoder_exclude -> quay ve decoder goc
        if os.path.exists(OSSEC + "/etc/decoders/" + SUDO_DEC):
            os.remove(OSSEC + "/etc/decoders/" + SUDO_DEC)
        c = open(OSSEC + "/etc/ossec.conf").read()
        c = re.sub(r"\s*<decoder_exclude>ruleset/decoders/%s</decoder_exclude>" % re.escape(SUDO_DEC), "", c)
        open(OSSEC + "/etc/ossec.conf", "w").write(c)
        log("analysisd -t loi -> da go ban sua decoder sudo, thu lai")
        t = sh(OSSEC + "/bin/wazuh-analysisd -t")
        log("kiem tra lan 2 rc=%s %s" % (t.returncode, (t.stdout + t.stderr).strip()[-300:]))
    restart_manager()


def api_timeout():
    """Mac dinh API cat yeu cau sau 10s (loi 3021). Tren VM tai nang, kiem tra cau hinh/logtest
    hay vuot 10s -> nang len 60s. Co hieu luc sau lan restart manager ngay sau day."""
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
    log("api.yaml: request_timeout=60")


def restart_manager():
    """VM tai nang luc boot (indexer + dashboard cung khoi dong) -> systemd hay timeout.
    Thu toi da 3 lan; lan sau dung wazuh-control truc tiep, khong qua gioi han cua systemd."""
    for i in range(3):
        cmd = "systemctl restart wazuh-manager" if i == 0 else \
              "systemctl reset-failed wazuh-manager; %s/bin/wazuh-control restart" % OSSEC
        r = sh(cmd)
        st = sh(OSSEC + "/bin/wazuh-control status").stdout
        log("restart lan %d rc=%s %s" % (i + 1, r.returncode, r.stderr.strip()[:150]))
        if "wazuh-apid is running" in st and "wazuh-analysisd is running" in st:
            return True
        time.sleep(20)
    log("manager van chua chay du:\n" + st)
    return False


def wait_api(user, pw, tries=60):
    for _ in range(tries):
        try:
            api = Wazuh("https://127.0.0.1:55000", user, pw)
            api.login()
            return api
        except WazuhError:
            time.sleep(5)
    return None


def create_tool_user(api):
    r = api._req("GET", "/security/users", params={"search": TOOL_USER})
    items = (r.get("data") or {}).get("affected_items") or []
    uid = next((it["id"] for it in items if it.get("username") == TOOL_USER), None)
    if uid is None:
        r = api._req("POST", "/security/users", body={"username": TOOL_USER, "password": TOOL_PASS})
        uid = r["data"]["affected_items"][0]["id"]
    else:
        api._req("PUT", "/security/users/%s" % uid, body={"password": TOOL_PASS})
    # vai tro administrator (id 1): du quyen ruleset + logtest + restart. Tap kiem tra an nam o
    # he thong file siem (khong qua API) nen khong lo qua tai khoan nay.
    try:
        api._req("POST", "/security/users/%s/roles" % uid, params={"role_ids": "1"})
    except WazuhError as e:
        log("gan role: %s" % e)
    log("user API %s id=%s" % (TOOL_USER, uid))


def decoder_selftest(api):
    line = "Nov 20 10:00:00 target sudo:  emp1234 : TTY=pts/0 ; PWD=/home/emp1234 ; USER=root ; COMMAND=/usr/bin/awk BEGIN {x}"
    tok, out = api.logtest(line)
    api.logtest_close(tok)
    data = out.get("data") or {}
    prog = (data.get("sudo") or {}).get("program") if isinstance(data.get("sudo"), dict) else data.get("sudo.program")
    has_user = bool(out.get("srcuser") or data.get("srcuser"))
    log("selftest decoder: program=%r srcuser=%r" % (prog, has_user))
    return prog == "/usr/bin/awk" and has_user


def main():
    os.makedirs(ST, exist_ok=True)
    os.chmod(ST, 0o700)
    if os.path.exists(MARK):
        return
    log("bat dau seed")
    u, pw = wui_creds()
    log("tai khoan dashboard: %s" % (u or "KHONG TIM THAY wazuh.yml"))
    # cho manager khoi dong xong lan dau truoc khi sua cau hinh (tranh restart chong len luc boot)
    if u and wait_api(u, pw, tries=60) is None:
        log("API chua len sau 5 phut tu luc boot")
    install_ruleset()
    api = wait_api(u, pw, tries=72) if u else None
    if api is None:
        log("KHONG dang nhap duoc API bang tai khoan dashboard")
        open(MARK, "w").write("SEED=PARTIAL\nAPI_USER=FAIL\n")
        return
    create_tool_user(api)
    tool = wait_api(TOOL_USER, TOOL_PASS, tries=12)

    hid = os.path.join(ST, "hidden.jsonl")
    r = sh("python3 %s/gen17.py --set hidden --out %s && python3 %s/gen17.py --check %s" % (HERE, hid, HERE, hid))
    log("sinh tap an: rc=%s %s" % (r.returncode, (r.stdout + r.stderr).strip()[:300]))

    # ngay sau restart, logtest hay tra 500 "Timeout executing API request" (analysisd chua nap xong)
    dec_ok = False
    for i in range(8):
        try:
            dec_ok = decoder_selftest(tool or api)
            break
        except WazuhError as e:
            log("selftest lan %d loi: %s" % (i + 1, str(e)[:160]))
            time.sleep(15)
    open(MARK, "w").write("SEED=OK\nAPI_USER=%s\nHIDDEN=%s\nDECODER=%s\n" % (
        "OK" if tool else "FAIL", "OK" if r.returncode == 0 else "FAIL", "OK" if dec_ok else "FAIL"))
    log("xong")


if __name__ == "__main__":
    main()
