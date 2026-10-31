#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh all-in-one o CHE DO NEN (~10-15 phut).
# $1 = mat khau sudo. Chi cai neu chua co (/var/ossec).
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
