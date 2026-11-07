#!/bin/bash
# Defender (tram analyst). Tao san file bai lam mau cho sinh vien dien dap an.
# Khong dung vao /tmp/.X11-unix (Labtainers tu lo symlink X0; dung vao se gay loi "same file").
if [ ! -f /home/ubuntu/answers.txt ]; then
cat > /home/ubuntu/answers.txt <<'TXT'
# ===== BAI LAM - Bai 1: Lam quen Wazuh =====
# Dien dap an ngay sau dau '=' (giu nguyen dinh dang C1= ... ). Chi 1 gia tri moi dong.
# Luu file lai sau khi dien (Ctrl+O neu dung nano), roi chay 'checkwork'.
C1=
C2=user
C3=203.0.113.
C4=
C5=
C6=
C7=
C8=172.20.0.
TXT
chown ubuntu:ubuntu /home/ubuntu/answers.txt 2>/dev/null || true
chmod 644 /home/ubuntu/answers.txt 2>/dev/null || true
fi
exit 0
