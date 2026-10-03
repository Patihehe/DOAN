#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong C2 listener ngam,
# tach hoan toan khoi tien trinh khoi tao (setsid + &) de chay lien tuc.
setsid python3 /home/ubuntu/listen.py >/home/ubuntu/c2.log 2>&1 < /dev/null &
exit 0
