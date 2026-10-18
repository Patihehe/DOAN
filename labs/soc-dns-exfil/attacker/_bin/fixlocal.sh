#!/bin/bash
# Chay LAN DAU tren container attacker (an). Khoi dong Rogue DNS C2 Listener.
PW="$1"
echo "$PW" | sudo -S setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
exit 0
