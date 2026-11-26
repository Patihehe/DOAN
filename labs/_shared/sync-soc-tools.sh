#!/bin/bash
# Chep bo cong cu dung chung (labs/_shared/soc-tools) vao mot lab, de Labtainers dong goi duoc.
# Dung:  bash labs/_shared/sync-soc-tools.sh soc-privesc
#        bash labs/_shared/sync-soc-tools.sh soc-shift-capstone --socq --system
#  (mac dinh)  defender/soc-tools/  : wzapi.py, replay.py, kiem-thu-luat, thu-dong, goi-y  (fixlocal cai bang sudo - Bai 17)
#  --system    defender/_system/usr/local/{bin,lib/soc-tools}  (Labtainers cai bang root LUC BUILD; SV khong co root - Bai 18)
#  --socq      siem/<bai>/lib/socq/ : thu vien socq (Bai 18)
#  luon        siem/<bai>/lib/      : wzapi.py, replay.py  (grader tren siem)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
LAB="$HERE/../$1"
[ -d "$LAB" ] || { echo "Khong thay lab $1"; exit 1; }
shift
SOCQ=0; SYS=0
for a in "$@"; do case "$a" in --socq) SOCQ=1;; --system) SYS=1;; esac; done
if [ $SYS = 1 ]; then
  B="$LAB/defender/_system/usr/local"
  mkdir -p "$B/bin" "$B/lib/soc-tools"
  cp "$HERE"/soc-tools/{kiem-thu-luat,thu-dong,goi-y} "$B/bin/"
  cp "$HERE"/soc-tools/{wzapi.py,replay.py} "$B/lib/soc-tools/"
  chmod 755 "$B"/bin/*
  rm -rf "$LAB/defender/soc-tools"
else
  mkdir -p "$LAB/defender/soc-tools"
  cp "$HERE"/soc-tools/{wzapi.py,replay.py,kiem-thu-luat,thu-dong,goi-y} "$LAB/defender/soc-tools/"
fi
for d in "$LAB"/siem/bai*/; do [ -d "$d" ] && mkdir -p "$d/lib" && cp "$HERE"/soc-tools/{wzapi.py,replay.py} "$d/lib/"; done
if [ $SOCQ = 1 ]; then
  for d in "$LAB"/siem/bai*/; do
    [ -d "$d" ] || continue
    rm -rf "$d/lib/socq" && mkdir -p "$d/lib/socq"
    cp "$HERE"/socq/*.py "$d/lib/socq/"
  done
fi
echo "Da dong bo soc-tools vao $(basename "$LAB") $*"
