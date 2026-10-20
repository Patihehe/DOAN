#!/bin/bash
# ============================================================================
# Don dung luong Docker cho VM Labtainers.
# Chay tren VM:  bash optimize-disk.sh
#
# LUU Y: 'docker images' (cot SIZE) CONG TRUNG layer dung chung -> nhin rat lon.
#        Con so THAT xem bang:  docker system df   (va  docker system df -v)
#
# Phan 1: ZERO-RISK, tu chay (chi xoa image rac khong ai dung).
# Phan 2: TUY CHON - chi IN ra lenh + canh bao, KHONG tu chay (ban tu quyet).
# ============================================================================
set -e

echo "=== Con so THAT (truoc khi don) ==="
docker system df
echo ""

echo ">> [AUTO] Xoa image rac (dangling, khong tag, khong con ai tham chieu)"
docker image prune -f
echo ""

echo "=== Con so THAT (sau khi don phan zero-risk) ==="
docker system df

cat <<'EOF'

############################################################################
### TUY CHON - can can nhac, KHONG tu chay. Copy lenh ra chay neu muon.  ###
############################################################################

# --- (A) Container da dung: THU HOI NHIEU NHAT (~hang chuc GB) ---
#   CANH BAO: xoa het trang thai lab dang luu -> lab tao MOI khi chay lai.
#   Chi chay khi KHONG con bai lab nao can giu tien do:
#       docker container prune -f

# --- (B) Anh nen cua lab KHAC khong dung (chi chay 5 lab SOC) (~8GB) ---
#   CANH BAO: muon dung lai lab Labtainers goc nao can base nay -> phai TAI LAI (can mang).
#   GIU LAI: base2 network2 network.ssh2 grader registry soc-wazuh (dang dung).
#       docker rmi labtainers/labtainer.wireshark2 labtainers/labtainer.wireshark \
#                  labtainers/labtainer.netmon labtainers/labtainer.tap \
#                  labtainers/labtainer.java labtainers/labtainer.lamp \
#                  labtainers/labtainer.firefox labtainers/labtainer.centos 2>/dev/null
#   (docker tu bo qua image nao con bi tham chieu -> an toan)

# --- (C) Build cache + image '.tmp' (tiet kiem it) ---
#   CANH BAO: xoa roi thi lan 'rebuild' sau phai build LAI TU DAU (can mang de tai goi).
#   Chi lam khi chac se khong rebuild som / mang on dinh:
#       docker builder prune -f
#       docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '\.student\.tmp$' \
#         | xargs -r -n1 docker rmi

EOF
