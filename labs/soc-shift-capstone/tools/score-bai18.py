#!/usr/bin/env python3
# ============================================================================
# score-bai18.py - DIEM TONG 100 cua Bai 18 (kich ban muc 9.2) + 3 cong (9.1) + so lieu do an.
# Chay NGOAI lab (may giang vien), doc thang prestop.stdout cua siem + defender:
#   python3 score-bai18.py <thu muc / file .lab / file .zip / 2 file prestop>...  [--csv out.csv] [-v]
#   - thu muc: moi file *.lab (hoac *.zip) ben trong = 1 sinh vien (thu muc labtainer_xfer/... cua gradelab)
#   - 2 file text: 1 sinh vien (file nao co SIEM18_MARKER / DEFENDER18_MARKER tu nhan ra)
# Khong phu thuoc Labtainers: chi can python3. Doc ban prestop MOI NHAT co marker cua moi container.
# Quy uoc (lo trinh P5, chot voi nhom):
#   - ticket khong co dong -> MTTA = 90' khi tinh trung vi; V/P/E = sai
#   - nhieu dong cung ticket -> V/P/E lay dong CUOI truoc dong bang, MTTA lay dong DAU (watcher)
#   - R-A "trien khai" = lan nap thanh cong dau tien co luat canh bao dai R-A (siem: RA_DEPLOY_REL)
#   - siem tat giua ca (LIVE_GAP: khong do duoc bao) -> khoanh vung R-B tinh theo lan sua R-B dau tien
#     (RB_FIX_REL) va C5 tinh theo recall R-B tap an; ghi chu LIVE_GAP trong cot ghi_chu
# ============================================================================
import csv, io, os, re, statistics, sys, zipfile

KV = re.compile(r"\b([A-Z][A-Z0-9_]*)=(\S*)")
FLAG = re.compile(r"^\s*([A-Z][A-Z0-9_]+)\s*$")


def parse(text):
    kv, flags = {}, set()
    for ln in text.splitlines():
        for k, v in KV.findall(ln):
            kv.setdefault(k, v)                     # lan dau xuat hien (giong GROUP REGEX cua Labtainers)
        m = FLAG.match(ln)
        if m:
            flags.add(m.group(1))
    return kv, flags


# ------------------------------------------------------------------ doc bai nop
def _texts_from_zip(zf, depth=0):
    for n in zf.namelist():
        if n.endswith("/"):
            continue
        data = zf.read(n)
        if n.lower().endswith((".zip", ".lab", ".tar.zip")) and depth < 3:
            try:
                yield from _texts_from_zip(zipfile.ZipFile(io.BytesIO(data)), depth + 1)
            except zipfile.BadZipFile:
                pass
        elif "prestop.stdout" in n:
            yield n, data.decode("utf-8", "replace")


def collect(paths):
    """-> {sinh_vien: {'siem': text, 'defender': text}} (ban moi nhat theo ten file .<timestamp>)."""
    subs = {}

    def add(student, name, text):
        role = "siem" if "SIEM18_MARKER" in text else "defender" if "DEFENDER18_MARKER" in text else None
        if not role:
            return
        cur = subs.setdefault(student, {}).get(role)
        if cur is None or name > cur[0]:
            subs[student][role] = (name, text)

    loose = []
    for p in paths:
        if os.path.isdir(p):
            for n in sorted(os.listdir(p)):
                q = os.path.join(p, n)
                if n.lower().endswith((".lab", ".zip")) and zipfile.is_zipfile(q):
                    st = n.split(".")[0]
                    for name, t in _texts_from_zip(zipfile.ZipFile(q)):
                        add(st, name, t)
        elif zipfile.is_zipfile(p):
            st = os.path.basename(p).split(".")[0]
            for name, t in _texts_from_zip(zipfile.ZipFile(p)):
                add(st, name, t)
        else:
            loose.append(p)
    for p in loose:
        add("sv", p, open(p, encoding="utf-8", errors="replace").read())
    return {s: {r: v[1] for r, v in d.items()} for s, d in subs.items()}


# ------------------------------------------------------------------ cham
def step(minutes, full, half, lim_full, lim_half):
    if minutes is None:
        return 0.0
    return full if minutes <= lim_full else half if minutes <= lim_half else 0.0


def num(d, k):
    try:
        return int(d[k])
    except (KeyError, ValueError):
        return None


def nset(s):
    return {int(x) for x in re.findall(r"\d+", s or "")}


def score(siem_txt, def_txt):
    g, gf = parse(siem_txt)
    a, af = parse(def_txt)
    note = []
    r = {}
    if "SHIFT_RUNNING" in gf or g.get("SHIFT_END") != "Y":
        note.append("siem: ca chua ket thuc")
    if "SHIFT_FROZEN" not in af:
        note.append("defender: phieu chua dong bang")
    scale = float(a.get("SCALE") or 1.0)
    n = num(g, "GT_N") or 0
    # ---- hang doi
    ok_v = ok_e = ok_p = n_tp = 0
    p1_mtta, normal_mtta, p1_all_ok, p1_tp = [], [], True, 0
    for k in range(1, n + 1):
        gv, gp, ge, isp1 = (num(g, "GT_%s_%d" % (x, k)) for x in ("V", "P", "E", "ISP1"))
        av, ap, ae = (num(a, "ANS_%s_%d" % (x, k)) for x in ("V", "P", "E"))
        if a.get("INC_%d" % k) not in (None, g.get("GT_INC_%d" % k)):
            note.append("lech thu tu slot %d (INC %s/%s)" % (k, a.get("INC_%d" % k), g.get("GT_INC_%d" % k)))
        ok_v += av == gv
        ok_e += ae == ge
        if gv == 1:
            n_tp += 1
            ok_p += ap == gp
        lat = num(a, "LAT_%d" % k)
        mins = lat / 60.0 / scale if lat is not None else None
        if isp1:
            p1_mtta.append(mins)
            if not (av == 1 and ap == 1):
                p1_all_ok = False
            p1_tp += av == 1
        else:
            normal_mtta.append(mins if mins is not None else 90.0)
    r["verdict"] = 15.0 * ok_v / n if n else 0
    r["bang_chung"] = 10.0 * ok_e / n if n else 0
    r["uu_tien_tp"] = 5.0 * ok_p / n_tp if n_tp else 0
    # ---- SC1
    gt_tk, ans_tk = nset(g.get("GT_SC_TICKETS")), nset(a.get("ANS_SC_TICKETS"))
    diff = len(gt_tk ^ ans_tk)
    sc = 3.0 if gt_tk and diff == 0 else 1.0 if gt_tk and diff == 1 else 0.0
    host_ok = num(a, "ANS_SC_HOST_C") in (num(g, "GT_SC_HOST_C"), num(g, "GT_SC_HOSTIP_C")) and num(a, "ANS_SC_HOST_C") not in (None, 0)
    sc += 1.0 * host_ok
    sc += 1.0 * (num(a, "ANS_SC_GIAI_DOAN") == num(g, "GT_SC_GIAI_DOAN") is not None)
    r["gom_su_co"] = sc
    lt = [num(a, "LT_TICKET") in gt_tk,
          num(a, "LT_HOST_C") in (num(g, "GT_SC_HOST_C"), num(g, "GT_SC_HOSTIP_C")) and num(a, "LT_HOST_C") not in (None, 0),
          num(a, "LT_ASSET_LEVEL") == num(g, "GT_SC_ASSET"),
          num(a, "LT_STAGE") == num(g, "GT_SC_STAGE"),
          nset(a.get("LT_MITRE")) == nset(g.get("GT_SC_MITRE")) != set(),
          num(a, "LT_IOC_C2") == num(g, "GT_SC_IOC_C2"),
          nset(a.get("LT_DE_XUAT")) == nset(g.get("GT_SC_DE_XUAT")) != set()]
    r["leo_thang"] = 5.0 * sum(1 for x in lt if x) / 7
    # ---- thoi gian
    r["mtta_p1"] = sum(step(m, 3.0, 1.5, 10, 15) for m in p1_mtta)
    med = statistics.median(normal_mtta) if normal_mtta else 90.0
    r["mtta_thuong"] = max(0.0, min(8.0, 8.0 * (15 - med) / 10))
    r["ra_thoi_gian"] = step(num(g, "RA_DEPLOY_REL"), 5.0, 2.0, 20, 30)
    gap = "LIVE_GAP" in gf
    if gap:
        note.append("LIVE_GAP: siem tat giua ca, khoanh vung/C5 tinh du phong")
        r["rb_khoanh_vung"] = step(num(g, "RB_FIX_REL"), 5.0, 2.0, 20, 30)
    else:
        r["rb_khoanh_vung"] = step(num(g, "RB_CONTAIN_MIN"), 5.0, 2.0, 20, 30)
    if "RB_NOT_BLIND" not in gf:
        r["rb_khoanh_vung"] = 0.0          # "dap" bao bang cach lam mu luat khong phai khoanh vung
    # ---- chat luong luat (tap an)
    valid = g.get("RULES_VALID") == "Y"
    pr = lambda f: ((num(g, f + "_P100") or 0) + (num(g, f + "_R100") or 0)) / 200.0 if valid else 0.0  # noqa: E731
    r["ra_tap_an"] = 15.0 * pr("RA")
    r["rb_tap_an"] = 10.0 * pr("RB")
    if "C5_SEEN" in gf:
        r["c5"] = 5.0
    elif gap and (num(g, "RB_R100") or 0) >= 90:
        r["c5"] = 5.0
    else:
        r["c5"] = 0.0
    total = sum(r.values())
    gates = {"gate_no_missed_p1": p1_all_ok and "SHIFT_FROZEN" in af and n > 0,
             "gate_storm_not_blind": "RB_NOT_BLIND" in gf,
             "gate_ra_deployed": "GATE_RA_DEPLOYED" in gf}
    out = {k: round(v, 2) for k, v in r.items()}
    out.update({"tong": round(total, 1), **{k: "Y" if v else "N" for k, v in gates.items()}})
    out["dat"] = "Y" if all(gates.values()) and total >= 60 else "N"
    # so lieu do an + phu
    out["TRIAGE_TIME_MEDIAN"] = round(med, 1)
    out["VERDICT_ACCURACY"] = round(ok_v / n, 3) if n else 0
    out["ATTACKS_DETECTED"] = "%d/%d" % (p1_tp + ("C5_SEEN" in gf), len(p1_mtta) + 1)
    out["mtta_p1_phut"] = ";".join("-" if m is None else "%.1f" % m for m in p1_mtta)
    for k in ("KS_TRUOC", "KS_SAU", "GOI_Y_USES", "KIEM_THU_RUNS", "LICH_CA_RESTARTS"):
        out[k] = (a.get(k) if k in a else g.get(k, "")) or ""
    out["ghi_chu"] = " | ".join(note)
    return out


COLS = ["sinh_vien", "tong", "dat", "gate_no_missed_p1", "gate_storm_not_blind", "gate_ra_deployed",
        "verdict", "bang_chung", "uu_tien_tp", "gom_su_co", "leo_thang",
        "mtta_p1", "mtta_thuong", "ra_thoi_gian", "rb_khoanh_vung", "ra_tap_an", "rb_tap_an", "c5",
        "TRIAGE_TIME_MEDIAN", "VERDICT_ACCURACY", "ATTACKS_DETECTED", "mtta_p1_phut",
        "KS_TRUOC", "KS_SAU", "GOI_Y_USES", "KIEM_THU_RUNS", "LICH_CA_RESTARTS", "ghi_chu"]


def main(argv):
    args = [x for x in argv if not x.startswith("-")]
    csv_out = None
    if "--csv" in argv:
        csv_out = argv[argv.index("--csv") + 1]
        args.remove(csv_out)
    if not args:
        raise SystemExit(__doc__ or "dung: score-bai18.py <thu muc|.lab|2 file prestop> [--csv out.csv] [-v]")
    rows = []
    for st, d in sorted(collect(args).items()):
        if "siem" not in d or "defender" not in d:
            rows.append({"sinh_vien": st, "ghi_chu": "thieu prestop %s" % ("siem" if "siem" not in d else "defender")})
            continue
        row = {"sinh_vien": st, **score(d["siem"], d["defender"])}
        rows.append(row)
    w = csv.DictWriter(open(csv_out, "w", newline="") if csv_out else sys.stdout, fieldnames=COLS, extrasaction="ignore")
    w.writeheader()
    for row in rows:
        w.writerow(row)
    if "-v" in argv:
        for row in rows:
            print("\n== %s" % row["sinh_vien"], file=sys.stderr)
            for c in COLS[1:]:
                print("  %-22s %s" % (c, row.get(c, "")), file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
