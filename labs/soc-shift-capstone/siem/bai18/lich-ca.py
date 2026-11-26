#!/usr/bin/env python3
# ============================================================================
# lich-ca.py - bo lap lich ca truc Bai 18 (systemd lich-ca.service, root, Restart=always).
# Doc seed + t_ref + T0 tu /root/.bai18, dung lai ca bang socq.ca.build, roi phat theo T0:
#   - su kien MOT LAN (ticket, yeu cau R-A, bao R-B, nhac gio, het ca): nhat ky events.log -> bu khi khoi dong lai
#   - LUONG lien tuc (moi TICK giay): web hop le, lenh webshell (sau C3), bao (sau R-B), quet C5 (C5..C5_END)
#     -> ghi dong log vao /var/log/soc-shift/*.log (manager doc bang <localfile>, luat SV no truc tiep)
#     -> luong KHONG bu khi khoi dong lai (chi chay tiep tu tick hien tai)
#   - shift.json (khong dap an) cho shiftd/defender moi vong lap
# Che do nhanh (phat trien): echo 0.1667 > /root/.bai18/scale  (1 ca = 15'). XOA truoc khi phat hanh.
# ============================================================================
import json, os, subprocess, random, shutil, sys, time

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
from socq import ca, cases, chain, docs, indexer, shift  # noqa: E402

ST = "/root/.bai18"
PUB = "/srv/shiftd"
LOGDIR = "/var/log/soc-shift"
TICK = 10
# Bao: ~26 dong/10s tu 2-3 may sao luu -> ~20-30 canh bao 100340/phut voi luat khung (kich ban: 150-300 / 10 phut).
# Lan chay nhanh dau tien voi 6 dong/tick chi ra 4-7 canh bao/phut (qua nhe, khong thanh "bao").
STORM_PER_TICK = 26
SCAN_PER_TICK = 3
LOG = os.path.join(ST, "lich-ca.log")

YC_RA = """YÊU CẦU LUẬT KHẨN — R-A (từ IR, {gio})

Kẻ tấn công đang gọi lệnh qua webshell trên web-shop; tên tham số đổi liên tục nên luật
webshell hiện tại (chỉ bắt "cmd=") không nổ.

Cần: luật bắt MỌI lệnh gọi qua script trong thư mục upload ({up}), KHÔNG phụ thuộc tên tham số.
Dải ID: 100330–100339. Level ≥ 10, có <mitre>. Không báo động giả trên script đã duyệt
(xem danh mục dịch vụ trong ctx-*).
Hạn: {han} phút kể từ giờ trên. Triển khai bản "đủ tốt" trước, tinh chỉnh sau.

Tập phát triển có nhãn: dev.jsonl (cùng thư mục). Kiểm thử: kiem-thu-luat (và thu-dong "<dòng log>")
"""
YC_RB = """BÃO CẢNH BÁO — R-B ({gio})

Trưởng ca: "Dashboard đang ngập luật 100340 (một máy kết nối tới nhiều máy nội bộ).
Xử lý đi, nhưng ĐỪNG ĐỂ MÙ."

Luật nằm trong ~/luat/local_rules.xml (100342 + 100340), dải 100340–100349.
SOP 7: CẤM tắt luật hoặc hạ xuống dưới mức cảnh báo. Ngoại lệ phải có căn cứ (phiếu thay đổi trong ctx-*).
Hạn khoanh vùng: {han} phút kể từ giờ trên.

Tập phát triển có nhãn: dev.jsonl (cùng thư mục). Kiểm thử: kiem-thu-luat (và thu-dong "<dòng log>")
"""


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def append(name, lines):
    if not lines:
        return
    with open(os.path.join(LOGDIR, name), "a") as f:
        f.write("\n".join(lines) + "\n")


def canh_bao(ex):
    """Loi indexer ma SV can biet (dia day -> index chi doc): /srv/shiftd/canh-bao.json cho trang-thai."""
    p = os.path.join(PUB, "canh-bao.json")
    msg = str(ex or "")
    if ex is None:
        if os.path.exists(p):
            os.remove(p)
        return
    if "flood-stage" in msg or "read_only" in msg or "disk usage" in msg:
        open(p, "w").write(json.dumps({"loi": "DIA_DAY", "t": int(time.time())}))


def release_request(key, dev, text):
    d = os.path.join(PUB, "yeu-cau", key)
    os.makedirs(d, exist_ok=True)
    shutil.copy(os.path.join(ST, dev), os.path.join(d, "dev.jsonl"))
    open(os.path.join(d, "yeu-cau.txt"), "w").write(text)


def main():
    while not (os.path.exists(os.path.join(ST, "T0")) and os.path.exists(os.path.join(ST, "seed"))):
        time.sleep(5)
    seed = int(open(os.path.join(ST, "seed")).read())
    t_ref = int(open(os.path.join(ST, "t_ref")).read())
    # che do nhanh: /root/.bai18/scale (tao TRUOC khi seed xong) hoac file 'scale' trong thu muc lab bai18/
    # (chi khi phat trien - XOA truoc khi phat hanh)
    sc_file = next((p for p in (os.path.join(ST, "scale"), os.path.join(HERE, "scale")) if os.path.exists(p)), None)
    scale = float(open(sc_file).read()) if sc_file else 1.0
    s = ca.build(seed, t_ref, scale=scale)
    s["scale"] = scale
    w, events = s["world"], s["events"]
    # plan.json theo DUNG lich dang chay (che do nhanh doi moc) - grade18 doc file nay
    json.dump({"answers": s["answers"], "sc": s["sc"], "events": events, "scale": scale},
              open(os.path.join(ST, "plan.json"), "w"), indent=1)
    st = shift.State(ST, PUB)
    t0 = st.t0()
    at = {e["id"]: e["at"] for e in events}
    end = t0 + at["END"]
    ix = indexer.Indexer()
    # lich lenh webshell (sau C3, moi 3-5 phut) - co dinh theo seed
    r = random.Random("%s:c3" % seed)
    c3 = []
    t = at["C3"]
    while t < at["END"]:
        c3.append(t)
        t += int(r.randint(180, 300) * scale)
    log("bat dau: T0=%d scale=%s, %d su kien, %d lan lenh webshell" % (t0, scale, len(events), len(c3)))
    last_tick = None
    while True:
        now = time.time()
        if st.t0() != t0:          # reset-ca (phat trien) doi/xoa T0 -> thoat; systemd chay lai, doc T0 moi
            log("T0 doi (%s -> %s) -> khoi dong lai" % (t0, st.t0()))
            return
        done = st.done()
        # ---- su kien mot lan (bu neu qua gio)
        for e in shift.due(events, t0, done, now):
            try:
                handle(e, s, st, ix, t0, now, seed)
                st.mark(e["id"])
                canh_bao(None)
                log("phat %s (%s) tre %ds" % (e["id"], e.get("inc", e["kind"]), now - t0 - e["at"]))
            except Exception as ex:  # noqa: BLE001
                log("LOI phat %s: %r" % (e["id"], ex))
                canh_bao(ex)
        # ---- luong lien tuc
        if t0 <= now < end:
            tick = int((now - t0) // TICK)
            if tick != last_tick:
                last_tick = tick
                rel = now - t0
                rng = random.Random("%s:tick:%d" % (seed, tick))
                web = chain.lines_web_noise(now, w, rng, 3)
                if any(c <= rel < c + TICK for c in c3):
                    web += chain.lines_webshell_cmd(now, w, rng)
                append("web-shop.log", web)
                net = []
                if rel >= at["R-B"]:
                    net += chain.lines_storm(now, w, rng, STORM_PER_TICK)
                if at["C5"] <= rel < at["C5_END"]:
                    net += chain.lines_scan(now, w, rng, SCAN_PER_TICK)
                append("net.log", net)
        st.publish(events, {"scale": scale})
        if now >= end + 60 and "END" in st.done():
            # het ca: chi giu shift.json cap nhat (defender doc 'end'); ngu dai
            time.sleep(30)
        else:
            time.sleep(2)


def handle(e, s, st, ix, t0, now, seed):
    w = s["world"]
    han = max(1, int(round(20 * s.get("scale", 1.0))))     # han yeu cau (phut) theo scale
    k = e["kind"]
    if k == "ticket":
        p = s["plans"][e["id"]]
        rng = ca.event_rng(seed, e["id"])
        ts = now
        if e.get("backlog"):
            ts = t0 - rng.randint(90, 150) * 60           # ticket ton tu ca chieu
        if e["id"].startswith("C"):
            tk, ev = chain.render(e["id"], p, ts, w, rng)
        else:
            tk, ev = cases.render(p, ts, w, rng)
        tk = docs.ticket(tk, e["inc"])
        ix.bulk([(docs.index_name(ts), d) for d in ev] + [(docs.index_name(ts), tk)], refresh=True)
    elif k == "request":
        release_request("R-A", "dev-ra.jsonl", YC_RA.format(gio=time.strftime("%H:%M"), up=w.upload_dir, han=han))
    elif k == "storm_start":
        release_request("R-B", "dev-rb.jsonl", YC_RB.format(gio=time.strftime("%H:%M"), han=han))
    elif k == "end":
        open(os.path.join(ST, "SHIFT_END"), "w").write("%d\n" % int(now))
        # cham + luu ban in sau het ca (prestop du phong neu prestop qua 30s)
        subprocess.run(["systemctl", "start", "--no-block", "grade-bai18.service"])


if __name__ == "__main__":
    main()
