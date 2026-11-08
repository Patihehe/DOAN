#!/bin/bash
# Mo Wazuh dashboard trong Firefox tren tram defender.
# LUU Y: file nay duoc SOURCE vao shell dang nhap -> TUYET DOI khong goi 'exit' (tat terminal)
# va khong chay vong lap/sleep o foreground (treo terminal). Toan bo bon vao MOT SUBSHELL NEN ( ) &.
#
# CHONG LOI "firefox khong len / cannot open display": tu tao MOT FILE symlink
# /tmp/.X11-unix/X<n> -> /var/tmp/.X11-unix/X<n> (CHI tao FILE symlink khi THIEU, TUYET DOI
# khong bien ca thu muc /tmp/.X11-unix thanh symlink -> tranh loi doX11Link "same file").
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
