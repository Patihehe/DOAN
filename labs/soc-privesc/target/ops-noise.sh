#!/bin/bash
# ops-healthcheck (Bai 17) - NHIEU LANH dinh ky tren target (cron moi 3 phut, quyen root).
# Muc dich: timeline khong "sach" mot cach gia tao + nen bao gia cho 3 luat lap lo hong.
#  - Nhan vien go nham mat khau tu may noi bo khac (IP 172.20.0.6x - khong co container that,
#    nen dong log duoc ghi qua logger voi tag sshd[...] -> Wazuh giai ma nhu sshd that).
#  - deploy dung quyen sudo DA DUYET (that).
#  - Quan tri vien dang nhap root bang key tu may chu quan tri DA DUYET (172.20.0.41/42).
#  - Admin tao 1 tai khoan thuong (1 lan duy nhat).
# KHONG dung IP ke tan cong (172.20.0.5) -> khong lam nhieu dap an timeline.
P() { echo $((RANDOM % 50000 + 1200)); }
PORT() { echo $((RANDOM % 28000 + 32768)); }
ip_staff() { echo "172.20.0.$((60 + RANDOM % 9))"; }
staff_user() { getent passwd | awk -F: '$1 ~ /^emp[0-9]+$/ {print $1}' | shuf -n1; }
auth() { logger -p auth.info -t "sshd[$(P)]" "$1"; }

case $((RANDOM % 4)) in
  0)  U=$(staff_user); IP=$(ip_staff)
      [ -n "$U" ] || exit 0
      for i in $(seq 1 $((1 + RANDOM % 3))); do
        auth "Failed password for $U from $IP port $(PORT) ssh2"; sleep $((2 + RANDOM % 8))
      done
      auth "Accepted password for $U from $IP port $(PORT) ssh2" ;;
  1)  su deploy -s /bin/bash -c "sudo -n $(command -v systemctl) restart nginx" >/dev/null 2>&1 ;;
  2)  ADM="172.20.0.4$((1 + RANDOM % 2))"
      auth "Accepted publickey for root from $ADM port $(PORT) ssh2: ED25519 SHA256:$(head -c 32 /dev/urandom | base64 | tr -d '=\n' | head -c 43)" ;;
  3)  if [ ! -f /var/lib/ops-intern.done ]; then
        useradd -m -s /bin/bash "intern$((100 + RANDOM % 900))" 2>/dev/null; touch /var/lib/ops-intern.done
      else
        U=$(staff_user); [ -n "$U" ] && auth "Accepted password for $U from $(ip_staff) port $(PORT) ssh2"
      fi ;;
esac
exit 0
