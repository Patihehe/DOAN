#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap tan cong ngam,
# tach hoan toan khoi tien trinh khoi tao (setsid + &) de chay lien tuc.
setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
