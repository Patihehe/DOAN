#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
PW="$1"

# Tao user analyst cho sinh vien SSH sang xu ly su co (mat khau: analyst)
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null

# Bat dich vu Nginx Web Server (hoac Python Web server neu nginx khong co)
echo "$PW" | sudo -S systemctl enable nginx 2>/dev/null || true
echo "$PW" | sudo -S systemctl start nginx 2>/dev/null || true

# Backup neu nginx khong khoi chay -> dung Python3 HTTP Server port 80
if ! pgrep -x "nginx" >/dev/null; then
  echo "$PW" | sudo -S bash -c 'nohup python3 -m http.server 80 >/dev/null 2>&1 &'
fi

exit 0
