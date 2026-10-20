#!/bin/bash
# ============================================================================
# Ap image nen chung soc-wazuh cho TAT CA lab co container siem (Wazuh) da trien khai
# trong $LABTAINER_DIR/labs. Goi apply-shared-siem.sh cho tung lab (idempotent).
#
# Dieu kien: da chay make-soc-wazuh.sh (co soc-wazuh:latest trong registry) va cac lab
#            da duoc trien khai (chay install-<lab>.sh) len $LABTAINER_DIR/labs.
#
# Dung:  bash apply-shared-siem-all.sh
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co \$LABTAINER_DIR"; exit 1; fi
HERE="$(cd "$(dirname "$0")" && pwd)"

LABS=()
for d in "$LABTAINER_DIR"/labs/*/; do
  lab="$(basename "$d")"
  [ -f "$d/dockerfiles/Dockerfile.$lab.siem.student" ] || continue   # chi lab co siem
  LABS+=("$lab")
done

if [ "${#LABS[@]}" -eq 0 ]; then
  echo "Khong tim thay lab nao co container siem trong $LABTAINER_DIR/labs."
  echo "Hay chay install-<lab>.sh de trien khai lab truoc."
  exit 1
fi

echo ">> Se ap image chung cho cac lab: ${LABS[*]}"
for lab in "${LABS[@]}"; do
  echo ""
  echo "======== $lab ========"
  bash "$HERE/apply-shared-siem.sh" "$lab"
done

echo ""
echo ">> DA AP XONG. Giờ REBUILD tung lab (siem gio FROM soc-wazuh -> build nhanh, tiet kiem dung luong):"
echo "   cd \$LABTAINER_DIR/scripts/labtainer-student"
for lab in "${LABS[@]}"; do echo "   rebuild $lab"; done
echo ""
echo ">> Sau rebuild, kiem tren siem:  systemctl is-active wazuh-indexer wazuh-manager wazuh-dashboard"
echo ">> va agent tren dashboard phai Active (entrypoint tu don rids/client.keys moi boot)."
