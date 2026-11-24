#!/bin/bash
# Chep bo cong cu dung chung (labs/_shared/soc-tools) vao mot lab, de Labtainers dong goi duoc.
# Dung:  bash labs/_shared/sync-soc-tools.sh soc-privesc
# - defender/soc-tools/ : wzapi.py, replay.py, kiem-thu-luat, thu-dong, goi-y
# - siem/<bai>/lib/     : wzapi.py, replay.py  (grader tren siem)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
LAB="$HERE/../$1"
[ -d "$LAB" ] || { echo "Khong thay lab $1"; exit 1; }
mkdir -p "$LAB/defender/soc-tools"
cp "$HERE"/soc-tools/{wzapi.py,replay.py,kiem-thu-luat,thu-dong,goi-y} "$LAB/defender/soc-tools/"
for d in "$LAB"/siem/bai*/; do [ -d "$d" ] && mkdir -p "$d/lib" && cp "$HERE"/soc-tools/{wzapi.py,replay.py} "$d/lib/"; done
echo "Da dong bo soc-tools vao $1"
