#!/bin/bash
# ============================================================================
# Trinh cai dat lab soc-path-traversal (Quet thu muc & Path Traversal + Snort)
#   bash install-soc-path-traversal.sh
# Yeu cau: da chay update-designer.sh va co bien $LABTAINER_DIR.
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then
  echo "LOI: chua co \$LABTAINER_DIR. Chay ./update-designer.sh roi mo terminal moi."
  exit 1
fi
LAB="$LABTAINER_DIR/labs/soc-path-traversal"
echo ">> Tao lab soc-path-traversal tai: $LAB"

if [ ! -d "$LAB" ]; then
  mkdir -p "$LAB"
  cd "$LAB"
  new_lab_setup.py || true
  new_lab_setup.py -a attacker || true
  new_lab_setup.py -a siem || true
  new_lab_setup.py -a defender || true
fi

# Sao chep thu muc nguon vao $LABTAINER_DIR/labs/soc-path-traversal
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC="$SCRIPT_DIR/soc-path-traversal"

if [ -d "$SRC" ]; then
  cp -r "$SRC/"* "$LAB/"
  echo ">> Da sao chep ma nguon soc-path-traversal sang $LAB"
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
echo ">> HOÀN TẤT CÀI ĐẶT LAB QUÉT THƯ MỤC & PATH TRAVERSAL (soc-path-traversal)!"
echo ">> Build & Chay:"
echo "     cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-path-traversal"
