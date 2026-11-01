#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong Ransomware C2 Listener port 8080.
setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
