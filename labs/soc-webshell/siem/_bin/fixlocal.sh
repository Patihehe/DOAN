#!/bin/bash
# soc-wazuh da cai san Wazuh. Quyen cac user Wazuh duoc khoi phuc o /entrypoint.sh (PID 1, TRUOC systemd),
# nen o day KHONG chown gi (chown /var/lib luc dang chay se hong node.lock cua OpenSearch).
# systemd tu khoi dong indexer/manager/filebeat/dashboard luc boot. (Da bake anh chung -> khong goi wazuh-setup.)
exit 0
