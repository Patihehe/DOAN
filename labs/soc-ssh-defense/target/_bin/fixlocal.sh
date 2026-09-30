#!/bin/bash
# Chay LAN DAU tren target, quyen user 'ubuntu'. $1 = mat khau sudo.
PW="$1"

# 'alice' mat khau MANH -> attacker chi tao "Failed password" (nhieu, gay nhieu).
echo "$PW" | sudo -S useradd -m -s /bin/bash alice 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "alice:Al1ce_Str0ng_Pw_2026" | chpasswd'

# Nan nhan YEU 'empEMPID' (EMPID ca nhan hoa) -> attacker DO TRUNG -> "Accepted password".
echo "$PW" | sudo -S useradd -m -s /bin/bash empEMPID 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "empEMPID:Password123" | chpasswd'

# 'analyst' cho DEFENDER SSH sang xu ly su co (mat khau: analyst).
echo "$PW" | sudo -S useradd -m -s /bin/bash analyst 2>/dev/null
echo "$PW" | sudo -S bash -c 'echo "analyst:analyst" | chpasswd'
echo "$PW" | sudo -S usermod -aG sudo analyst 2>/dev/null

# Bat password authentication cho sshd (de ghi Failed/Accepted vao auth.log)
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
echo "$PW" | sudo -S service ssh restart 2>/dev/null \
  || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null \
  || echo "$PW" | sudo -S pkill -HUP sshd 2>/dev/null || true

exit 0
