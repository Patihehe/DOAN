#!/bin/bash
# ============================================================================
# Trinh cai dat lab soc-ddos (SYN Flood Rate Limiting) len VM Labtainers.
#   bash install-soc-ddos.sh
# Yeu cau: da chay update-designer.sh va co bien $LABTAINER_DIR.
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then
  echo "LOI: chua co \$LABTAINER_DIR. Chay ./update-designer.sh roi mo terminal moi."
  exit 1
fi
LAB="$LABTAINER_DIR/labs/soc-ddos"
echo ">> Tao lab soc-ddos tai: $LAB"

if [ ! -d "$LAB" ]; then
  mkdir -p "$LAB"
  cd "$LAB"
  new_lab_setup.py || true
  new_lab_setup.py -a attacker || true
  new_lab_setup.py -a siem || true
  new_lab_setup.py -a defender || true
fi

# Sao chep thu muc nguon vao $LABTAINER_DIR/labs/soc-ddos
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC="$SCRIPT_DIR/soc-ddos"

if [ -d "$SRC" ]; then
  cp -r "$SRC/"* "$LAB/"
  echo ">> Da sao chep ma nguon soc-ddos sang $LAB"
fi

# Phan quyen va chuan hoa LF
chmod +x "$LAB/target/_bin/fixlocal.sh" 2>/dev/null || true
chmod +x "$LAB/target/_bin/prestop" 2>/dev/null || true
chmod +x "$LAB/attacker/_bin/fixlocal.sh" 2>/dev/null || true
chmod +x "$LAB/attacker/attack.sh" 2>/dev/null || true
chmod +x "$LAB/siem/_bin/fixlocal.sh" 2>/dev/null || true
chmod +x "$LAB/siem/_bin/prestop" 2>/dev/null || true
chmod +x "$LAB/siem/wazuh-setup.sh" 2>/dev/null || true
chmod +x "$LAB/defender/_bin/student_startup.sh" 2>/dev/null || true

find "$LAB" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null || true

echo ""
echo ">> HOÀN TẤT CÀI ĐẶT LAB SYN FLOOD (soc-ddos)!"
echo ">> Build & Chay:"
echo "     cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-ddos"
