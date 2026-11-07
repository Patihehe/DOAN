#!/bin/bash
# Defender (tram analyst). Tao san file bai lam mau cho sinh vien dien dap an.
if [ ! -f /home/ubuntu/answers.txt ]; then
cat > /home/ubuntu/answers.txt <<'TXT'
# ===== BAI LAM - Bai 3: Baseline & bat thuong =====
# Dien dap an ngay sau dau '=' (giu nguyen C1= ...). Chi 1 gia tri (so) moi dong.
# C2, C5 dien OCTET CUOI cua IP (so cuoi). Luu file roi chay 'checkwork'.
C1=
C2=
C3=
C4=
C5=
C6=
C7=
C8=
TXT
chown ubuntu:ubuntu /home/ubuntu/answers.txt 2>/dev/null || true
chmod 644 /home/ubuntu/answers.txt 2>/dev/null || true
fi
exit 0
