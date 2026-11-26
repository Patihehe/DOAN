#!/usr/bin/env python3
# ============================================================================
# shift.py - lich ca truc 90' va trang thai ca (dung chung siem: lich-ca.py / grade18; defender doc shift.json).
#
# Moc tinh bang GIAY tu T0. Lech ngau nhien +-120 s theo SV, GIU thu tu nhan qua
# (C1 < C2 < C3 < R-A ; C3 < C4 < bao < C5 < C6). Va cham co chu dich KHONG duoc gian ra (kich ban 5.2).
# shift.json (doc boi defender qua shiftd) CHI co: t0, end, cac moc DA PHAT (id + gio). Khong co dap an.
# ============================================================================
import json
import os
import random
import time

SHIFT_LEN = 90 * 60

# moc goc (giay) - kich ban muc 5.1
BASE = {"C1": 8 * 60, "C2": 18 * 60, "C3": 30 * 60, "R-A": 32 * 60, "C4": 45 * 60,
        "R-B": 48 * 60, "C5": 50 * 60, "C5_END": 65 * 60, "C6": 72 * 60}
WAVES = [(0, 0), (25 * 60, 40 * 60), (55 * 60, 70 * 60)]      # dot 1 phat ngay tai T0
REMIND = [60 * 60, 80 * 60, 90 * 60]


def jitter(rng, s, j=120):
    return max(0, int(s + rng.randint(-j, j)))


def make(rng, queue, scale=1.0):
    """queue: list cac dot (list plan) tu cases.plan_queue. -> (events, inc_map)
       events: list {id, kind, at} da sap xep; inc_map: id ticket (Q<i>/C<k>) -> 'INC-2xx'."""
    at = {k: jitter(rng, v) for k, v in BASE.items()}
    # giu thu tu nhan qua sau khi lech
    order = ["C1", "C2", "C3", "R-A", "C4", "R-B", "C5", "C6"]
    for a, b in zip(order, order[1:]):
        if at[b] <= at[a] + 60:
            at[b] = at[a] + 60 + rng.randint(0, 60)
    at["C5_END"] = max(at["C5_END"], at["C5"] + 10 * 60)
    ev = []
    qi = 0
    for (lo, hi), grp in zip(WAVES, queue):
        for p in grp:
            t = 0 if hi == 0 else rng.randint(lo, hi)
            ev.append({"id": "Q%d" % qi, "kind": "ticket", "at": t, "pattern": p["pattern"]})
            qi += 1
    for k in ("C1", "C2", "C4", "C6"):
        ev.append({"id": k, "kind": "ticket", "at": at[k], "pattern": k})
    ev.append({"id": "C3", "kind": "c3_start", "at": at["C3"]})
    ev.append({"id": "R-A", "kind": "request", "at": at["R-A"]})
    ev.append({"id": "R-B", "kind": "storm_start", "at": at["R-B"]})
    ev.append({"id": "C5", "kind": "c5_start", "at": at["C5"]})
    ev.append({"id": "C5_END", "kind": "c5_end", "at": at["C5_END"]})
    for r in REMIND:
        ev.append({"id": "NHAC_%d" % (r // 60), "kind": "remind", "at": r})
    ev.append({"id": "END", "kind": "end", "at": SHIFT_LEN})
    for e in ev:
        e["at"] = int(e["at"] * scale)
    ev.sort(key=lambda e: (e["at"], e["id"]))
    # ticket: so INC tang theo thu tu xuat hien, khoang cach ngau nhien 1-6; 1 ticket ton ca chieu co so thap hon
    tickets = [e for e in ev if e["kind"] == "ticket"]
    n = rng.randint(201, 230)
    inc = {}
    backlog = rng.choice([e for e in tickets if e["at"] == 0 and e["id"].startswith("Q")])
    inc[backlog["id"]] = "INC-%d" % (n - rng.randint(8, 20))
    backlog["backlog"] = True
    for e in tickets:
        if e["id"] in inc:
            continue
        inc[e["id"]] = "INC-%d" % n
        n += rng.randint(1, 6)
    for e in tickets:
        e["inc"] = inc[e["id"]]
    return ev, inc


class State:
    """Trang thai ca tren siem: T0, nhat ky phat (bu khi khoi dong lai), shift.json cho shiftd."""

    def __init__(self, d, public_dir):
        self.d, self.pub = d, public_dir
        os.makedirs(d, exist_ok=True)
        os.makedirs(public_dir, exist_ok=True)
        self.log = os.path.join(d, "events.log")

    def t0(self):
        p = os.path.join(self.d, "T0")
        return int(open(p).read().split()[0]) if os.path.exists(p) else None

    def set_t0(self, t0):
        _atomic(os.path.join(self.d, "T0"), "%d\n" % t0)

    def done(self):
        if not os.path.exists(self.log):
            return {}
        out = {}
        for line in open(self.log):
            p = line.split()
            if len(p) >= 2:
                out[p[0]] = int(p[1])
        return out

    def mark(self, eid, when=None):
        with open(self.log, "a") as f:
            f.write("%s %d\n" % (eid, int(when or time.time())))
            f.flush()
            os.fsync(f.fileno())

    def publish(self, events, extra=None):
        """Ghi shift.json (KHONG dap an): t0, end, moc da phat, ticket da phat (INC + gio)."""
        t0 = self.t0()
        dn = self.done()
        pub = {"t0": t0, "end": (t0 + max(e["at"] for e in events if e["kind"] == "end")) if t0 else None,
               "now": int(time.time()), "released": {}, "tickets": {}}
        for e in events:
            if e["id"] in dn:
                if e["kind"] == "ticket":
                    pub["tickets"][e["inc"]] = dn[e["id"]]
                elif e["kind"] in ("request", "storm_start", "end", "remind"):
                    pub["released"][e["id"]] = dn[e["id"]]
        if extra:
            pub.update(extra)
        _atomic(os.path.join(self.pub, "shift.json"), json.dumps(pub, sort_keys=True))
        return pub


def _atomic(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def due(events, t0, done, now=None):
    """Su kien da toi gio nhung chua phat (bu sau khi lab khoi dong lai)."""
    now = now or time.time()
    return [e for e in events if e["id"] not in done and t0 + e["at"] <= now]
