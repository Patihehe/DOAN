#!/bin/bash
# Defender: tram sinh vien. Ghi san cac dia chi muc tieu (khong lo cach khai thac - xem read_first).
cat > /home/ubuntu/muc-tieu.txt <<'TXT'
=== DIA CHI ===
Dashboard SIEM (Wazuh):   https://172.20.0.20
He A (VA tai day):        ssh analyst@172.20.0.10   (mat khau: analyst) ; ma nguon /var/www/html
He B (KHAI THAC lay flag): http://172.20.0.40        (chi HTTP)
Nop flag he B:            http://172.20.0.40/submit.php?flag=FLAG-xxxxxx
TXT
chmod 644 /home/ubuntu/muc-tieu.txt 2>/dev/null || true

# X11/Firefox: KHONG dung vao /tmp/.X11-unix. Labtainers tu lo (mkdir thu muc that + symlink X0 ben trong).
# Neu bien /tmp/.X11-unix thanh symlink ca thu muc -> lenh 'ln -fs .../X0 /tmp/.X11-unix/X0' cua Labtainers
# thay 2 ve la CUNG 1 FILE -> loi "are the same file" -> doX11Link fail -> tear down lab. Giong soc-ssh-defense.

exit 0
