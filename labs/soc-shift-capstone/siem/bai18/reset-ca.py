#!/usr/bin/env python3
# ============================================================================
# reset-ca.py - CHI DE PHAT TRIEN/THU NGHIEM Bai 18 (khong noi trong read_first).
# Bat dau lai ca truc ma KHONG rebuild/restart lab:
#   docker exec soc-shift-capstone.siem.student python3 /home/ubuntu/bai18/reset-ca.py [--giu-luat]
# Lam gi (tren siem, root):
#   1) indexer: xoa (chay nen) ticket + moi doc tu (T0 cu - 20') den BAY GIO -> tranh ticket trung INC
#   2) dung lich-ca; xoa events.log, SHIFT_END, rules-history, rules.txt; T0 GHI DE (khong bao gio xoa)
#   3) /srv/shiftd: xoa shift.json va yeu-cau/  (defender thay t0 doi -> watcher tu lam moi phia defender)
#   4) nap lai luat KHUNG (tru khi --giu-luat) + restart manager -> bao R-B xuat hien lai
#   5) dat T0 = bay gio, chay lai lich-ca + cham lan dau
# Han che: nen 3h truoc T0 cu bi xoa mot phan; alerts.json van giu dong cua ca cu (live chi doc [T0 moi, het ca]).
# ============================================================================
import os, shutil, subprocess, sys, time

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
sys.path.insert(0, HERE)
from socq import indexer, shift  # noqa: E402

ST, PUB = "/root/.bai18", "/srv/shiftd"


def sh(c):
    print("+ " + c)
    return subprocess.run(c, shell=True).returncode


def main():
    if os.geteuid() != 0:
        raise SystemExit("can root: docker exec <siem> python3 %s" % sys.argv[0])
    st = shift.State(ST, PUB)
    old = st.t0()
    now = int(time.time())
    import seed18  # noqa: E402  (dung lai ham cai dat + flags)
    # (1) buoc CO THE LOI lam TRUOC, khi chua dung gi toi trang thai ca: indexer + luat
    ix = indexer.Indexer()
    if not ix.wait_ready(120):
        raise SystemExit("indexer chua san sang -> KHONG doi gi. Kiem tra: systemctl is-active wazuh-indexer")
    if old:
        # chi doc <= bay gio (ca moi chua ghi gi) -> chay NEN (wait_for_completion=false), khong timeout
        q = {"query": {"bool": {
            "filter": [{"range": {"timestamp": {"lte": now * 1000, "format": "epoch_millis"}}}],
            "should": [{"exists": {"field": "data.ticket"}},
                       {"range": {"timestamp": {"gte": (old - 1200) * 1000, "format": "epoch_millis"}}}],
            "minimum_should_match": 1}}}
        c, r = ix._req("POST", ix.base + "/wazuh-alerts-4.x-*/_delete_by_query?conflicts=proceed&wait_for_completion=false", q)
        print("indexer: xoa ca cu (chay nen) HTTP %s task=%s" % (c, r.get("task")))
    sh("systemctl stop lich-ca.service")
    try:
        if "--giu-luat" not in sys.argv:
            for n in seed18.LISTS:                       # list ve lai rong (bai mau co the da nap)
                open(os.path.join(seed18.OSSEC, "etc/lists", n), "w").write("lab-placeholder:\n")
            print("nap lai luat khung: %s" % seed18.install_wazuh())
    finally:
        # (2) trang thai ca: xoa + dat T0 moi NGAY (khong de lab o trang thai khong co T0)
        for n in ("events.log", "SHIFT_END", "rules-history", "rules.txt"):
            p = os.path.join(ST, n)
            if os.path.exists(p):
                os.remove(p)
        p = os.path.join(PUB, "shift.json")
        if os.path.exists(p):
            os.remove(p)
        shutil.rmtree(os.path.join(PUB, "yeu-cau"), ignore_errors=True)
        st.set_t0(int(time.time()))
        seed18.flags(T0=str(st.t0()))
        sh("systemctl start lich-ca.service")
        sh("systemctl start --no-block grade-bai18.service")
    print("T0 moi = %d (%s). Defender tu lam moi trong ~10 s." % (st.t0(), time.strftime("%H:%M:%S")))


if __name__ == "__main__":
    main()
