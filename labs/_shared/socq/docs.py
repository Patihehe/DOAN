#!/usr/bin/env python3
# ============================================================================
# docs.py - dung document "giong canh bao Wazuh" de ghi THANG vao indexer.
#
# Quy uoc toan lab (khop voi su kien di qua analysisd bang <localfile> - spike S-A):
#   - moi may gui log ve siem qua syslog tap trung -> agent luon la 000/siem
#   - MAY cua su kien = predecoder.hostname   (SOP ghi ro cho SV)
#   - truong ten nguoi dung cua sshd nam o data.dstuser (nhu Wazuh 4.14 that, Lab 17)
# ============================================================================
import datetime
import itertools
import time

_seq = itertools.count(1)


def iso(ts):
    """epoch -> dinh dang timestamp cua Wazuh ('2026-11-24T11:03:17.123+0000', UTC)."""
    d = datetime.datetime.fromtimestamp(ts, datetime.timezone.utc)
    return d.strftime("%Y-%m-%dT%H:%M:%S.") + "%03d+0000" % (d.microsecond // 1000)


def syslog_ts(ts):
    """epoch -> 'Nov 24 18:03:17' theo gio dia phuong cua container (nhu header syslog that)."""
    return time.strftime("%b %e %H:%M:%S", time.localtime(ts))


def index_name(ts):
    return "wazuh-alerts-4.x-" + time.strftime("%Y.%m.%d", time.gmtime(ts))


def alert(ts, host, rule_id, level, description, groups, data=None, full_log="", decoder=None,
          program=None, location=None, mitre=None, extra=None):
    """Mot document canh bao. 'data' la dict truong da giai ma (data.srcip, data.url, ...)."""
    rule = {"id": str(rule_id), "level": int(level), "description": description,
            "groups": list(groups), "firedtimes": 1, "mail": False}
    if mitre:
        rule["mitre"] = {"id": list(mitre)}
    doc = {
        "@timestamp": iso(ts),
        "timestamp": iso(ts),
        "agent": {"id": "000", "name": "siem"},
        "manager": {"name": "siem"},
        "id": "%d.%d" % (int(ts), next(_seq)),
        "rule": rule,
        "predecoder": {"hostname": host, "timestamp": syslog_ts(ts)},
        "full_log": full_log,
        "location": location or ("/var/log/soc-shift/%s.log" % host),
    }
    if program:
        doc["predecoder"]["program_name"] = program
    if decoder:
        doc["decoder"] = {"name": decoder}
    if data:
        doc["data"] = data
    if extra:
        for k, v in extra.items():
            doc[k] = v
    return doc


def fim(ts, host, rule_id, level, description, path, event="added", uname="root", groups=("ossec", "syscheck"),
        mitre=None, extra_sys=None):
    """Su kien giam sat toan ven file (FIM) - chi ghi thang vao indexer (logtest khong phat lai duoc FIM)."""
    sysc = {"path": path, "event": event, "uname_after": uname, "mode": "realtime"}
    if extra_sys:
        sysc.update(extra_sys)
    d = alert(ts, host, rule_id, level, description, list(groups) + ["syscheck_entry_%s" % event, "syscheck_file"],
              full_log="File '%s' %s" % (path, event), location="syscheck", mitre=mitre)
    d["syscheck"] = sysc
    return d


def ticket(doc, inc):
    """Bien mot canh bao thanh ticket hang doi: rule.groups + soc_queue, data.ticket = INC-xxx."""
    doc = dict(doc)
    doc["rule"] = dict(doc["rule"])
    doc["rule"]["groups"] = list(doc["rule"]["groups"]) + ["soc_queue"]
    data = dict(doc.get("data") or {})
    data["ticket"] = inc
    doc["data"] = data
    return doc


# ---------------------------------------------------------------- dong log THO (di qua analysisd)
def line_web(ts, host, srcip, method, url, status, size, agent="Mozilla/5.0"):
    """nginx access log qua syslog -> decoder web-accesslog, luat nen 31100 (spike S-A)."""
    d = time.strftime("%d/%b/%Y:%H:%M:%S %z", time.localtime(ts))
    return '%s %s nginx: %s - - [%s] "%s %s HTTP/1.1" %d %d "-" "%s"' % (
        syslog_ts(ts), host, srcip, d, method, url, status, size, agent)


def line_conn(ts, host, src, dst, dport, sport=None, proto="TCP"):
    """netfilter qua syslog -> decoder kernel, luat nen 4100 (spike S-A)."""
    sport = sport or 40000 + (int(ts * 1000) % 20000)
    return ("%s %s kernel: [%d.%03d] ACCEPT IN=eth0 OUT= MAC= SRC=%s DST=%s LEN=60 TOS=0x00 PREC=0x00 "
            "TTL=64 ID=%d DF PROTO=%s SPT=%d DPT=%d WINDOW=64240 RES=0x00 SYN URGP=0") % (
        syslog_ts(ts), host, int(ts) % 100000, int(ts * 1000) % 1000, src, dst, int(ts) % 65000 + 1, proto,
        sport, dport)
