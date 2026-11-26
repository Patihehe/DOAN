#!/usr/bin/env python3
# ============================================================================
# test-grading18.py - kiem thu P5 NGOAI lab (S7): sinh prestop gia cua siem + defender cho nhieu "bai lam",
# cham bang (1) bo danh gia goals mo phong ngu nghia Labtainers (GROUP/FILE_REGEX, matchany integer_equal,
# boolean and/or/and_not/or_not) tren results.config/goals.config DA SINH, va (2) score-bai18.py.
#   cd labs/_shared && python3 ../soc-shift-capstone/tools/test-grading18.py
# Mo phong KHONG thay the checkwork that: chi bat loi cu phap/ten/logic cua file sinh ra.
# ============================================================================
import importlib.util, os, re, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "_shared"))
from socq import ca  # noqa: E402

spec = importlib.util.spec_from_file_location("score18", os.path.join(HERE, "score-bai18.py"))
score18 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(score18)


def canon(v):
    v = sorted({int(x) for x in v})
    return int("1" + "".join("%05d" % x for x in v)) if v else 0


def crc(t):
    return zlib.crc32((t or "").strip().lower().encode())


# ------------------------------------------------------------------ prestop gia
def siem_out(s, w, rules, live, ended=True):
    o = ["SIEM18_MARKER", "SHIFT_END=%s" % ("Y" if ended else "N")]
    if not ended:
        return "\n".join(o + ["SHIFT_RUNNING"]) + "\n"
    tk = sorted((e["at"], e["inc"]) for e in s["events"] if e["kind"] == "ticket")
    for k, (_, inc) in enumerate(tk, 1):
        a = s["answers"][inc]
        o += ["GT_INC_%d=%s REL_%d=%d" % (k, inc[4:], k, 1000 + k),
              "GT_V_%d=%d GT_P_%d=%d GT_E_%d=%d GT_ISP1_%d=%d" % (k, a["V"], k, a["P"], k, a["E"], k, a["isp1"])]
    sc = s["sc"]
    o += ["GT_N=%d" % len(tk), "GT_SC_TICKETS=%s" % ",".join(t[4:] for t in sc["TICKETS"]),
          "GT_SC_HOST=%s GT_SC_GIAI_DOAN=%d GT_SC_ASSET=%d GT_SC_IOC_C2=%d" % (sc["HOST"], sc["GIAI_DOAN"], sc["ASSET_LEVEL"], sc["IOC_C2"]),
          "GT_SC_MITRE=%s GT_SC_DE_XUAT=%s" % (",".join(sc["MITRE"]), ",".join(map(str, sc["DE_XUAT"]))),
          "GT_SC_TK_C=%d" % canon(t[4:] for t in sc["TICKETS"])]
    o += ["GT_SC_T%d=%s" % (i, t[4:]) for i, t in enumerate(sc["TICKETS"], 1)]
    o += ["GT_SC_HOST_C=%d GT_SC_HOSTIP_C=%d" % (crc(sc["HOST"]), crc(w.ip(sc["HOST"]))),
          "GT_SC_STAGE=%d" % {"A": 1, "B": 2, "C": 3}[sc["STAGE"]],
          "GT_SC_MITRE_C=%d GT_SC_DE_XUAT_C=%d" % (canon(sc["MITRE"]), canon(sc["DE_XUAT"]))]
    o += rules + live
    return "\n".join(o) + "\n"


def def_out(s, w, ans, sc_fields, lt_fields, frozen=True, extra=()):
    o = ["DEFENDER18_MARKER", "SHIFT_FROZEN" if frozen else "SHIFT_RUNNING"]
    tk = sorted((e["at"], e["inc"]) for e in s["events"] if e["kind"] == "ticket")
    for k, (_, inc) in enumerate(tk, 1):
        line = "INC_%d=%s" % (k, inc[4:])
        if inc in ans:
            v, p, e, lat = ans[inc]
            line += " ANS_V_%d=%s ANS_P_%d=%s ANS_E_%d=%s FIRST_%d=%d LAT_%d=%d LATOK_%d=%d" % (
                k, v, k, p, k, e, k, 2000, k, lat, k, 1 if lat <= 600 else 0)
        o.append(line)
    o += ["ANS_N=%d" % len(tk), "SCALE=1.0"]
    tks, host, gd = sc_fields
    o += ["ANS_SC_TICKETS=%s" % ",".join(map(str, sorted(tks))), "ANS_SC_TK_C=%d" % canon(tks),
          "ANS_SC_HOST=%s" % host, "ANS_SC_HOST_C=%d" % crc(host), "ANS_SC_GIAI_DOAN=%s" % gd]
    for k, v in lt_fields.items():
        o.append("LT_%s=%s" % (k, v))
        if k == "HOST":
            o.append("LT_HOST_C=%d" % crc(v))
        elif k in ("MITRE", "DE_XUAT"):
            o.append("LT_%s_C=%d" % (k, canon(v.split(",") if v else [])))
    o += ["BAN_GIAO_FILLED=6", "KS_TRUOC=3 KS_SAU=4", "KIEM_THU_RUNS=4", "GOI_Y_USES=1"] + list(extra)
    return "\n".join(o) + "\n"


# ------------------------------------------------------------------ mo phong Labtainers
def load_results(p):
    res = {}
    for ln in open(p):
        if not ln.strip() or ln.startswith("#"):
            continue
        name, rest = [x.strip() for x in ln.split("=", 1)]
        parts = [x.strip() for x in rest.split(" : ")]
        cont = parts[0].split(":")[0]
        if parts[1] == "FILE_REGEX":
            res[name] = (cont, "FILE_REGEX", parts[2])
        elif parts[1] == "GROUP":
            assert parts[3] == "REGEX", ln
            res[name] = (cont, "GROUP", int(parts[2]), parts[4])
        else:
            raise SystemExit("loai result la: " + ln)
    return res


def eval_results(res, texts):
    val = {}
    for name, spec_ in res.items():
        txt = texts[spec_[0]]
        if spec_[1] == "FILE_REGEX":
            val[name] = any(re.search(spec_[2], ln) for ln in txt.splitlines())
        else:
            for ln in txt.splitlines():
                m = re.search(spec_[3], ln)
                if m:
                    val[name] = m.group(spec_[2])
                    break
    return val


def eval_goals(p, val):
    goals = {}
    for ln in open(p):
        if not ln.strip() or ln.startswith("#"):
            continue
        name, rest = [x.strip() for x in ln.split("=", 1)]
        parts = [x.strip() for x in rest.split(" : ")]
        if parts[0] == "matchany":
            assert parts[1] == "integer_equal", ln
            lhs = val.get(parts[2])
            ref = parts[3]
            rhs = ref[7:] if ref.startswith("answer=") else val.get(ref[7:]) if ref.startswith("result.") else None
            if not ref.startswith(("answer=", "result.")):
                raise SystemExit("answertag la: " + ln)
            if ref.startswith("result.") and ref[7:] not in RES_NAMES:
                raise SystemExit("result khong ton tai: " + ln)
            try:
                goals[name] = lhs is not None and rhs is not None and int(lhs) == int(rhs)
            except ValueError:
                goals[name] = False
        elif parts[0] == "boolean":
            expr = parts[1]
            toks = expr.replace("(", " ( ").replace(")", " ) ").split()
            py = []
            for t in toks:
                if t in ("(", ")", "and", "or"):
                    py.append(t)
                elif t == "and_not":
                    py.append("and not")
                elif t == "or_not":
                    py.append("or not")
                else:
                    if t in goals:
                        py.append(str(goals[t]))
                    elif t in RES_NAMES:
                        py.append(str(bool(val.get(t))))
                    else:
                        raise SystemExit("ten la trong boolean: %s (%s)" % (t, ln))
            goals[name] = eval(" ".join(py))
        else:
            raise SystemExit("loai goal la: " + ln)
    return goals


# ------------------------------------------------------------------ bai lam gia
def main():
    cfg = os.path.join(HERE, "..", "instr_config")
    global RES_NAMES
    res = load_results(os.path.join(cfg, "results.config"))
    RES_NAMES = set(res)
    s = ca.build(1234, 1795600000)
    w, sc = s["world"], s["sc"]
    tk = sorted((e["at"], e["inc"]) for e in s["events"] if e["kind"] == "ticket")
    perfect = {inc: (s["answers"][inc]["V"], s["answers"][inc]["P"], s["answers"][inc]["E"], 240) for _, inc in tk}
    sc_ok = ({int(t[4:]) for t in sc["TICKETS"]}, sc["HOST"], sc["GIAI_DOAN"])
    lt_ok = {"TICKET": sc["TICKETS"][0][4:], "HOST": w.ip(sc["HOST"]), "ASSET_LEVEL": sc["ASSET_LEVEL"], "STAGE": 1,
             "MITRE": ",".join(sc["MITRE"]), "IOC_C2": sc["IOC_C2"], "DE_XUAT": ",".join(map(str, sc["DE_XUAT"]))}
    rules_ok = ["RULES_VALID=Y", "RA_P100=100 RA_R100=100", "RB_P100=100 RB_R100=100", "RB_NOT_BLIND", "RA_LOADED"]
    live_ok = ["STORM_PEAK=24", "RB_CONTAIN_MIN=12", "C3_SEEN", "RB_FIX_REL=11", "RA_DEPLOY_REL=9", "GATE_RA_DEPLOYED",
               "C5_SEEN", "LICH_CA_RESTARTS=0"]
    p1 = [inc for _, inc in tk if s["answers"][inc]["isp1"]]
    c6 = p1[-1]
    missed_c6 = {k: v for k, v in perfect.items() if k != c6}
    c2p2 = dict(perfect)
    c2p2[p1[1]] = (1, 2) + perfect[p1[1]][2:]
    cases = [
        ("T1 khong lam gi", siem_out(s, w, ["RULES_VALID=Y", "RA_P100=0 RA_R100=0", "RB_P100=67 RB_R100=100", "RB_NOT_BLIND"], ["STORM_PEAK=24", "LICH_CA_RESTARTS=0"]),
         def_out(s, w, {}, (set(), "", ""), {k: "" for k in lt_ok}), {"bai18_gates": False, "gate_no_missed_p1": False, "gate_ra_deployed": False}, (0, 25)),
        ("T2 giai mau day du", siem_out(s, w, rules_ok, live_ok), def_out(s, w, perfect, sc_ok, lt_ok),
         {"bai18_gates": True, "sc1_host": True, "lt_host": True, "lt_mitre": True, "c5_seen": True, "storm_contained": True}, (95, 100)),
        ("T3 bo sot C6", siem_out(s, w, rules_ok, live_ok), def_out(s, w, missed_c6, sc_ok, lt_ok),
         {"gate_no_missed_p1": False, "gate_storm_not_blind": True, "bai18_gates": False}, (80, 98)),
        ("T4 C2 ghi P2", siem_out(s, w, rules_ok, live_ok), def_out(s, w, c2p2, sc_ok, lt_ok),
         {"gate_no_missed_p1": False}, (85, 99.5)),
        ("T5 tat luat R-B", siem_out(s, w, ["RULES_VALID=Y", "RA_P100=100 RA_R100=100", "RB_P100=0 RB_R100=0"], ["STORM_PEAK=24", "RB_CONTAIN_MIN=3", "GATE_RA_DEPLOYED", "RA_DEPLOY_REL=9"]),
         def_out(s, w, perfect, sc_ok, lt_ok), {"gate_storm_not_blind": False, "bai18_gates": False}, (60, 90)),
        ("T6 giua ca (checkwork som)", siem_out(s, w, [], [], ended=False), def_out(s, w, perfect, sc_ok, lt_ok, frozen=False),
         {"v_1": False, "gate_no_missed_p1": False, "gate_storm_not_blind": False, "sc1_tickets": False}, (0, 1)),
        ("T7 LIVE_GAP (stoplab giua bao)", siem_out(s, w, rules_ok, ["STORM_PEAK=1", "RB_CONTAIN_MIN=2", "LIVE_GAP", "RB_FIX_REL=1", "GATE_RA_DEPLOYED", "RA_DEPLOY_REL=9", "C3_SEEN"]),
         def_out(s, w, perfect, sc_ok, lt_ok), {"bai18_gates": True}, (95, 100)),
    ]
    goals_p = os.path.join(cfg, "goals.config")
    bad = 0
    for name, st, df, expect, (lo, hi) in cases:
        val = eval_results(res, {"siem": st, "defender": df})
        g = eval_goals(goals_p, val)
        sc_row = score18.score(st, df)
        errs = ["%s=%s (can %s)" % (k, g.get(k), v) for k, v in expect.items() if g.get(k) != v]
        if not (lo <= sc_row["tong"] <= hi):
            errs.append("tong=%s ngoai [%s,%s]" % (sc_row["tong"], lo, hi))
        gates_score = (sc_row["gate_no_missed_p1"], sc_row["gate_storm_not_blind"], sc_row["gate_ra_deployed"])
        gates_goal = tuple("Y" if g[k] else "N" for k in ("gate_no_missed_p1", "gate_storm_not_blind", "gate_ra_deployed"))
        if gates_score != gates_goal:
            errs.append("cong score %s != goals %s" % (gates_score, gates_goal))
        bad += bool(errs)
        print("%-32s tong=%5s dat=%s cong=%s %s" % (name, sc_row["tong"], sc_row["dat"], "".join(gates_goal),
                                                   ("LOI: " + "; ".join(errs)) if errs else "OK"))
    print("%d ca, %d loi" % (len(cases), bad))
    sys.exit(1 if bad else 0)


RES_NAMES = set()
if __name__ == "__main__":
    main()
