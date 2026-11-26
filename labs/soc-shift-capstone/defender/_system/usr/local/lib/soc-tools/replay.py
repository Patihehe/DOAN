#!/usr/bin/env python3
# ============================================================================
# replay.py - phat lai bo kich ban log (JSONL) qua Wazuh logtest, dem TP/FP/FN theo ho luat.
# Ha tang DUNG CHUNG (Bai 16, 17, 18). Xem README.md cung thu muc.
#
# Dinh dang moi dong JSONL:
#   {"id": "l1-m-03", "family": "l1", "label": "mal"|"benign", "variant": "...",
#    "window_s": 600, "lines": ["<dong syslog 1>", "<dong syslog 2>", ...]}
#
# Quy uoc dem (theo KICH BAN, khong theo dong log):
#   - Moi kich ban = 1 phien logtest rieng (token rieng) -> luat tan suat co trang thai trong phien.
#   - Kich ban DUONG TINH neu co >= 1 dong sinh canh bao level >= MIN_LEVEL
#     voi rule.id nam trong dai ID cua ho do.
#   - mal & duong tinh = TP ; mal & am tinh = FN ; benign & duong tinh = FP.
#   - Luat im lang hoan toan: precision = 0 (quy uoc), recall = 0.
#
# Dung:
#   replay.py --set dev.jsonl --ranges l1=100270-100279,l2=100280-100289 [--mode dev|grade|json]
# ============================================================================
import argparse, json, sys

MIN_LEVEL = 10


def load_set(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                out.append(json.loads(ln))
    return out


def parse_ranges(s):
    rng = {}
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        fam, span = part.split("=")
        lo, hi = span.split("-")
        rng[fam.strip()] = (int(lo), int(hi))
    return rng


def scenario_hits(engine, sc, lo, hi, min_level=MIN_LEVEL):
    """engine(event, token) -> (token, output). Tra ve danh sach (rule_id, level) da no trong dai."""
    hits = []
    token = None
    try:
        for line in sc["lines"]:
            token, out = engine(line, token)
            rule = (out or {}).get("rule") or {}
            try:
                rid = int(rule.get("id", -1))
                lvl = int(rule.get("level", 0))
            except (TypeError, ValueError):
                continue
            if lo <= rid <= hi and lvl >= min_level:
                hits.append((rid, lvl))
    finally:
        if hasattr(engine, "close"):
            engine.close(token)
    return hits


def run(engine, scenarios, ranges):
    res = {}
    for fam, (lo, hi) in ranges.items():
        r = {"tp": 0, "fp": 0, "fn": 0, "tn": 0, "fp_ids": [], "fn_ids": [], "n_mal": 0, "n_benign": 0}
        for sc in scenarios:
            if sc.get("family") != fam:
                continue
            pos = bool(scenario_hits(engine, sc, lo, hi))
            mal = sc.get("label") == "mal"
            if mal:
                r["n_mal"] += 1
                if pos:
                    r["tp"] += 1
                else:
                    r["fn"] += 1
                    r["fn_ids"].append(sc["id"])
            else:
                r["n_benign"] += 1
                if pos:
                    r["fp"] += 1
                    r["fp_ids"].append(sc["id"])
                else:
                    r["tn"] += 1
        r["precision"] = (r["tp"] / (r["tp"] + r["fp"])) if (r["tp"] + r["fp"]) else 0.0
        r["recall"] = (r["tp"] / r["n_mal"]) if r["n_mal"] else 0.0
        res[fam] = r
    return res


class ApiEngine:
    """Bo phat lai that: goi Wazuh API /logtest."""

    def __init__(self, api):
        self.api = api

    def __call__(self, event, token):
        return self.api.logtest(event, token)

    def close(self, token):
        self.api.logtest_close(token)


def print_dev(res):
    print("%-5s %4s %4s %4s  %-9s %-6s" % ("HO", "TP", "FP", "FN", "PRECISION", "RECALL"))
    for fam, r in res.items():
        print("%-5s %4d %4d %4d  %-9.2f %-6.2f" % (fam, r["tp"], r["fp"], r["fn"], r["precision"], r["recall"]))
    for fam, r in res.items():
        if r["fp_ids"]:
            print("  [%s] kich ban BAO GIA (FP): %s" % (fam, ", ".join(r["fp_ids"])))
        if r["fn_ids"]:
            print("  [%s] kich ban BO SOT (FN): %s" % (fam, ", ".join(r["fn_ids"])))


def main():
    ap = argparse.ArgumentParser(description="Phat lai kich ban log qua Wazuh logtest")
    ap.add_argument("--set", required=True, help="file JSONL kich ban")
    ap.add_argument("--ranges", required=True, help="ho=tu-den,... vd l1=100270-100279")
    ap.add_argument("--mode", default="dev", choices=["dev", "grade", "json"])
    a = ap.parse_args()

    sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
    from wzapi import Wazuh
    res = run(ApiEngine(Wazuh()), load_set(a.set), parse_ranges(a.ranges))
    if a.mode == "dev":
        print_dev(res)
    elif a.mode == "json":
        print(json.dumps(res))
    else:
        for fam, r in res.items():
            print("%s_TP=%d %s_FP=%d %s_FN=%d" % (fam.upper(), r["tp"], fam.upper(), r["fp"], fam.upper(), r["fn"]))


if __name__ == "__main__":
    main()
