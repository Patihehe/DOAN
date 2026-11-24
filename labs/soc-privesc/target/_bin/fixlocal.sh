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
