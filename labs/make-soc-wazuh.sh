#!/bin/bash
# ============================================================================
# Tao image nen soc-wazuh (Wazuh cai san, SACH, world-readable) tu container
# siem cua soc-ssh-defense DANG CHAY, roi day len local registry.
#
# Dung:  bash make-soc-wazuh.sh <mat_khau_admin_wazuh>
#   (lay mat khau: tren siem chay  sudo cat /root/wazuh-admin-credentials.txt)
# ============================================================================
set -e
PASS="$1"
if [ -z "$PASS" ]; then echo "Usage: bash make-soc-wazuh.sh <admin_password>"; exit 1; fi
C=soc-ssh-defense.siem.student

if ! docker ps --format '{{.Names}}' | grep -q "^$C$"; then
  echo "LOI: container $C khong chay."
  echo "Hay chay 'labtainer soc-ssh-defense' va doi Wazuh len (indexer active) truoc."
  exit 1
fi

echo ">> 1) Ngung nguon su kien (agent target + attacker) de don sach"
docker exec soc-ssh-defense.target.student systemctl stop wazuh-agent 2>/dev/null || true
docker exec soc-ssh-defense.attacker.student pkill -f attack.sh 2>/dev/null || true
sleep 8

echo ">> 2) Don du lieu lab (alerts, index, agent keys) - giu security index/mat khau"
docker exec "$C" bash -c 'find /var/ossec/logs/alerts -type f -delete 2>/dev/null; : > /var/ossec/logs/ossec.log 2>/dev/null' || true
docker exec "$C" bash -c "curl -s -k -u admin:'$PASS' -X DELETE 'https://localhost:9200/wazuh-alerts-*,wazuh-archives-*,wazuh-monitoring-*,wazuh-statistics-*' >/dev/null 2>&1" || true
docker exec "$C" bash -c 'rm -f /var/ossec/queue/rids/* /var/ossec/queue/agents-timestamp 2>/dev/null; : > /var/ossec/etc/client.keys 2>/dev/null' || true

echo ">> 3) World-readable cac thu muc CHI-DOC cua Wazuh (de doc duoc du bi doi owner)"
docker exec "$C" bash -c 'chmod -R o+rX /usr/share/wazuh-indexer /usr/share/wazuh-dashboard /etc/wazuh-indexer /etc/wazuh-dashboard 2>/dev/null' || true

echo ">> 4) Tat sach cac service Wazuh truoc khi chup (data nhat quan)"
docker exec "$C" bash -c 'systemctl stop wazuh-dashboard filebeat wazuh-manager wazuh-indexer 2>/dev/null' || true
sleep 5

echo ">> 4.5) LAM GON anh nen (khong anh huong chat luong lab):"
echo "        - /root/wz: goi .deb Wazuh pre-bake + chung chi (Wazuh da cai xong -> la rac ~1-2GB)"
echo "        - cache apt, log, tmp, doc/man"
docker exec "$C" bash -c '
  rm -rf /root/wz /root/wazuh-install-files* /root/*.tar /root/*.tar.gz 2>/dev/null
  apt-get clean 2>/dev/null
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb 2>/dev/null
  rm -rf /tmp/* /var/tmp/* 2>/dev/null
  rm -rf /usr/share/doc/* /usr/share/man/* 2>/dev/null
  find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null
' || true

echo ">> 5) Commit thanh soc-wazuh:latest"
docker commit "$C" soc-wazuh:latest

echo ">> 6) Bao dam local registry chay + push"
docker start registry 2>/dev/null || docker run -d -p 5000:5000 --restart=always --name registry registry:2
sleep 3
docker tag soc-wazuh:latest localhost:5000/soc-wazuh:latest
docker push localhost:5000/soc-wazuh:latest

echo ""
echo ">> XONG. soc-wazuh da san sang:"
docker images | grep soc-wazuh
echo ">> Tiep theo: bash apply-shared-siem.sh  roi  rebuild soc-ssh-defense"
