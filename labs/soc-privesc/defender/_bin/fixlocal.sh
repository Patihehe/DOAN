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
