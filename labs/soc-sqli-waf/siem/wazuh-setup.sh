#!/bin/bash
# Chay boi root o lan boot dau (goi tu fixlocal.sh). Cai Wazuh OFFLINE tu goi da bake san.
# Khong can internet. Tien do ghi vao /var/log/wazuh-install.log
cd /root/wz 2>/dev/null || cd /root
echo "[wazuh-setup] Cai Wazuh OFFLINE, bat dau luc $(date)" > /var/log/wazuh-install.log
bash wazuh-install.sh -a -o >> /var/log/wazuh-install.log 2>&1
echo "[wazuh-setup] Hoan tat luc $(date)" >> /var/log/wazuh-install.log
# Trich mat khau admin ra file de tien tra cuu
tar -O -xf /root/wz/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt 2>/dev/null \
  | grep -A1 "'admin'" > /root/wazuh-admin-credentials.txt 2>/dev/null
