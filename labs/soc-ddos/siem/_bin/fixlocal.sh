#!/bin/bash
# Lan khoi dong dau tren siem: tu cai Wazuh hoac khoi dong service tu image soc-wazuh.
# setup Wazuh if it is not installed yet
PW="$1"
if [ ! -d /var/ossec ]; then
  echo "$PW" | sudo -S nohup bash /home/ubuntu/wazuh-setup.sh >/dev/null 2>&1 &
fi
exit 0
