#!/usr/bin/env python3
# ============================================================================
# ca.py - dung TOAN BO mot ca truc tu 1 seed (tai lap duoc): the gioi, ngu canh, hang doi, chuoi, lich, dap an.
# siem chi luu SEED (/root/.bai18/seed) va T0; moi tien trinh (seed18, lich-ca, grade18) goi build(seed, t_ref).
#   t_ref = moc thoi gian neo ngu canh (CHG/LV/OC) - lay = gio seed lan dau, LUU lai de build lai y het.
# ============================================================================
import random

from . import cases, chain, ctx as ctxmod, shift, world as worldmod


def build(seed, t_ref, scale=1.0):
    rng = random.Random(seed)
    w = worldmod.World(random.Random(rng.random()))
    cx = ctxmod.Ctx(w, t_ref)
    cx.base()
    queue = cases.plan_queue(w, cx, random.Random(rng.random()))
    ch = chain.plan(w, random.Random(rng.random()))
    events, inc = shift.make(random.Random(rng.random()), queue, scale=scale)
    plans = {}
    i = 0
    for grp in queue:
        for p in grp:
            plans["Q%d" % i] = p
            i += 1
    for k in ("C1", "C2", "C4", "C6"):
        plans[k] = ch[k]
    answers = {}
    for eid, p in plans.items():
        answers[inc[eid]] = {"V": p["V"], "P": p["P"], "E": p["E"], "pattern": p["pattern"], "src": eid,
                             "isp1": 1 if (p["V"] == 1 and p["P"] == 1) else 0}
    sc = dict(ch["SC"])
    sc["TICKETS"] = sorted(inc[k] for k in ("C1", "C2", "C4", "C6"))
    return {"seed": seed, "t_ref": t_ref, "world": w, "ctx": cx, "plans": plans, "events": events, "inc": inc,
            "answers": answers, "sc": sc}


def event_rng(seed, eid, k=0):
    """rng rieng cho moi lan render (de bu/phat lai cho ra cung noi dung)."""
    return random.Random("%s:%s:%s" % (seed, eid, k))
