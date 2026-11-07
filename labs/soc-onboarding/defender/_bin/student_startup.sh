#!/bin/bash
# Mo Wazuh dashboard trong Firefox tren tram defender.
# LUU Y: file nay duoc SOURCE vao shell dang nhap cua terminal -> TUYET DOI khong goi 'exit'
# (se tat terminal) va khong chay vong lap/sleep o foreground (se treo terminal). Vi vay toan bo
# cong viec duoc bon vao MOT SUBSHELL NEN ( ... ) & -> terminal tra ve ngay, van tuong tac duoc.
#
# CHONG LOI "firefox khong len / cannot open display": Labtainers bind-mount socket X that cua host
# vao /var/tmp/.X11-unix, roi LE RA tao symlink /tmp/.X11-unix/X<n>. Doi khi symlink nay khong co
# -> firefox bao "cannot open display". Ta tu bao dam bang cach tao MOT FILE symlink ben trong thu
# muc that (TUYET DOI khong bien ca /tmp/.X11-unix thanh symlink -> tranh loi doX11Link "same file").
if ! id | grep -q 'uid=0'; then
  (
    export DISPLAY="${DISPLAY:-:0}"
    dn="${DISPLAY#:}"; dn="${dn%%.*}"
    ensure_x11() {
      [ -d /tmp/.X11-unix ] || mkdir -p /tmp/.X11-unix 2>/dev/null
      if [ ! -S "/tmp/.X11-unix/X$dn" ] && [ -S "/var/tmp/.X11-unix/X$dn" ]; then
        ln -sf "/var/tmp/.X11-unix/X$dn" "/tmp/.X11-unix/X$dn" 2>/dev/null
      fi
    }
    for _ in $(seq 1 20); do
      ensure_x11
      [ -S "/tmp/.X11-unix/X$dn" ] && break
      sleep 2
    done
    ensure_x11
    ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
  ) >/dev/null 2>&1 &
fi
