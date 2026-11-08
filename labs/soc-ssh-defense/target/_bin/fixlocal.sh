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

# Tao san KHUNG phieu dieu tra cho analyst (SV chi dien SO sau moi dau '=').
# Chi tao neu chua co -> khong de len dap an SV neu fixlocal chay lai.
echo "$PW" | sudo -S bash -c '[ -f /home/analyst/dieu-tra.txt ] || { printf "# Phieu dieu tra - dien SO sau moi dau \"=\" (xem goi y trong read_first)\nC1=\nC2=\nC3=\nC4=\nC5=\n" > /home/analyst/dieu-tra.txt; chown analyst:analyst /home/analyst/dieu-tra.txt; chmod 644 /home/analyst/dieu-tra.txt; }'

# Bat password authentication cho sshd (de ghi Failed/Accepted vao auth.log)
echo "$PW" | sudo -S sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
echo "$PW" | sudo -S service ssh restart 2>/dev/null \
  || echo "$PW" | sudo -S systemctl restart ssh 2>/dev/null \
  || echo "$PW" | sudo -S pkill -HUP sshd 2>/dev/null || true

exit 0
