#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong vong lap leo quyen ngam.
setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
