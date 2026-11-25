#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-alert-triage (Triage hang doi canh bao) tren VM Labtainers.
# Chay tren VM:  bash install-soc-alert-triage.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-alert-triage
# (siem = anh chung soc-wazuh -> can co localhost:5000/soc-wazuh. V1 buoc 1: kiem tra seeding dashboard.)
# (File nay SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-alert-triage
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB"
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_TRI_9x2k__'
SOC Lab - Triage hàng đợi cảnh báo (lần báo giá): phân loại TP/BTP/FP + xếp ưu tiên + xử lý P1 chen ngang.
Sau ca đêm, Wazuh còn ~12 ticket chưa xử lý - lẫn giữa hoạt động hợp lệ (quét lỗ hổng, pentest theo phiếu,
deploy, kỹ sư on-call) là những dấu hiệu đầu tiên của một nhóm APT. Analyst phải: đọc SOP, điều tra
đối chiếu ngữ cảnh doanh nghiệp (tài sản/phiếu thay đổi/nghỉ phép/lịch trực), kết luận từng ticket
(1=TP thật, 2=BTP thật-nhưng-được-phép, 3=FP báo giả), xếp ưu tiên theo ma trận, và xử lý 1 ticket P1
chen ngang (INC-113 - tiến trình ngụy trang beacon C2). Chấm: độ chính xác phân loại, không bỏ sót TP,
không leo thang nhầm FP, đúng bằng chứng (đã pivot thật).
__EOF_TRI_9x2k__
cat > "$LAB/config/parameter.config" <<'__EOF_TRI_9x2k__'
# parameter.config - ca nhan hoa IOC (chong chep). Token nam trong raw-log tren defender;
# grader doc lai chinh raw-log de lay dap an bang chung E (khong can dong bo 2 may).
# ATKOCT: octet cuoi IP ke tan cong ngoai (203.0.113.ATKOCT) - bang chung cho INC-101/103/105/109.
# C2AOCT: octet cuoi IP C2 cua INC-107 (198.51.100.C2AOCT).
# C2DOCT: octet cuoi IP C2 cua INC-113 (192.0.2.C2DOCT).
ATKOCT : RAND_REPLACE : defender:.local/bin/fixlocal.sh : ATKOCT : 100 : 240
C2AOCT : RAND_REPLACE : defender:.local/bin/fixlocal.sh : C2AOCT : 100 : 240
C2DOCT : RAND_REPLACE : defender:.local/bin/fixlocal.sh : C2DOCT : 100 : 240
__EOF_TRI_9x2k__
cat > "$LAB/config/start.config" <<'__EOF_TRI_9x2k__'
# start.config - Lab soc-alert-triage (Triage hang doi canh bao lan bao gia)
# 2 container: siem (Wazuh - sinh hang doi alert, AN voi SV) + defender (tram analyst: Firefox + phieu).

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-alert-triage_student_master_seed
	GRADE_CONTAINER defender

# Mang ao SOC
NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- SIEM: Wazuh All-in-One. Tu sinh hang doi ~12 alert + 1 P1 chen ngang. AN (khong terminal) ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST defender:172.20.0.30
	TERMINALS 0

# --- DEFENDER: Tram Analyst (Firefox xem dashboard + viet phieu triage). Noi lam bai + cham ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	X11 YES
	TERMINALS 1
__EOF_TRI_9x2k__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/fixlocal.sh" <<'__EOF_TRI_9x2k__'
#!/bin/bash
# Chay LAN DAU tren defender (tram analyst), quyen 'ubuntu'. $1 = mat khau sudo.
# Tao: raw-log tung host (co IOC ngau nhien ATKOCT/C2AOCT/C2DOCT), ngu canh doanh nghiep (SVC/CHG/OC/LV),
# SOP, va cac phieu lam bai. Grader (prestop) doc lai raw-log de lay dap an bang chung E.
H="$HOME"
mkdir -p "$H/raw-logs"

# ===================== RAW LOGS (dieu tra pivot) =====================
# IP ke tan cong ngoai: 203.0.113.ATKOCT (dung o INC-101/103/105/109)
# IP C2 cua INC-107: 198.51.100.C2AOCT ; IP C2 cua INC-113: 192.0.2.C2DOCT
cat > "$H/raw-logs/web01.log" <<'EOF'
# ===== web01 (Medium) - auth + web access + file =====
Nov 18 02:05:03 web01 sshd[1900]: Failed password for admin from 10.10.0.10 port 40001 ssh2
Nov 18 02:05:07 web01 sshd[1902]: Failed password for root from 10.10.0.10 port 40010 ssh2
Nov 18 02:05:14 web01 sshd[1905]: Failed password for test from 10.10.0.10 port 40025 ssh2
Nov 18 02:41:03 web01 sshd[2201]: Failed password for root from 203.0.113.ATKOCT port 51002 ssh2
Nov 18 02:41:05 web01 sshd[2203]: Failed password for root from 203.0.113.ATKOCT port 51009 ssh2
Nov 18 02:41:09 web01 sshd[2205]: Failed password for deploy from 203.0.113.ATKOCT port 51020 ssh2
Nov 18 02:41:12 web01 sshd[2207]: Failed password for deploy from 203.0.113.ATKOCT port 51031 ssh2
Nov 18 02:41:22 web01 sshd[2209]: Accepted password for deploy from 203.0.113.ATKOCT port 51050 ssh2
Nov 18 01:42:10 web01 apache: 203.0.113.44 - - "GET /search?q=1'OR'1'='1 HTTP/1.1" 200 512
Nov 18 01:42:40 web01 apache: 203.0.113.44 - - "GET /item?id=2;SELECT HTTP/1.1" 200 480
Nov 18 02:33:40 web01 apache: 203.0.113.ATKOCT - - "GET /products?id=1'UNION SELECT user,pass FROM accounts-- HTTP/1.1" 200 148302
Nov 18 02:50:03 web01 apache: 203.0.113.ATKOCT - - "POST /uploads/shell.php HTTP/1.1" 200 12
Nov 18 02:50:20 web01 apache: 203.0.113.ATKOCT - - "GET /uploads/shell.php?cmd=id HTTP/1.1" 200 45
Nov 18 02:12:05 web01 apache: 10.10.0.30 - - "PUT /app/release-v5.2.war HTTP/1.1" 201 0
Nov 18 02:50:03 web01 audit: NEW FILE /var/www/html/uploads/shell.php owner=www-data
Nov 18 02:12:06 web01 audit: NEW FILE /var/www/app/release-v5.2.war owner=ci-deploy
Nov 18 03:00:01 web01 logrotate: rotated and compressed 240 files under /var/log and /var/www/logs
EOF

cat > "$H/raw-logs/app02.log" <<'EOF'
# ===== app02 (Low) - dns + process =====
Nov 18 02:20:01 app02 dnsmasq: query[A] aGVsbG8gd29ybGQgc2VjcmV0IGRhdGEx.exfil.badguy-c2.net from 10.0.2.15 to 198.51.100.C2AOCT
Nov 18 02:20:31 app02 dnsmasq: query[A] c2VjcmV0IGZpbGUgY2h1bmsgMg.exfil.badguy-c2.net from 10.0.2.15 to 198.51.100.C2AOCT
Nov 18 02:21:02 app02 dnsmasq: query[A] bW9yZSBzdG9sZW4gZGF0YSBoZXJl.exfil.badguy-c2.net from 10.0.2.15 to 198.51.100.C2AOCT
Nov 18 02:25:03 app02 dnsmasq: query[A] 9f8a7b6c5d4e3f2a1b0c.lookup.av-cloud-security.example from 10.0.2.15 to 10.10.0.2
Nov 18 02:25:44 app02 dnsmasq: query[A] 1122334455667788aabb.lookup.av-cloud-security.example from 10.0.2.15 to 10.10.0.2
Nov 18 02:30:00 app02 proc: pid=5120 comm=sysmon-helper exe=/opt/monitoring/sysmon-helper args="--collect --interval 60"
EOF

cat > "$H/raw-logs/db-core.log" <<'EOF'
# ===== db-core (High) - auth + process/network =====
Nov 18 02:44:10 db-core sshd[3301]: Accepted password for ketoan01 from 203.0.113.ATKOCT port 52001 ssh2
Nov 18 02:44:12 db-core audit: USER ketoan01 shell /bin/bash from 203.0.113.ATKOCT
Nov 18 02:52:30 db-core audit: PROCESS comm=[kworker/u4:2] pid=4102 exe=/tmp/.k ppid=3301
Nov 18 02:52:31 db-core netflow: /tmp/.k pid=4102 -> 192.0.2.C2DOCT:443 (repeat every 30s)
Nov 18 02:53:01 db-core netflow: /tmp/.k pid=4102 -> 192.0.2.C2DOCT:443 (repeat every 30s)
EOF

cat > "$H/raw-logs/vpn-gw.log" <<'EOF'
# ===== vpn-gw (Medium) - vpn auth =====
Nov 18 02:15:00 vpn-gw openvpn: user le.tran connected from 10.10.0.55 (duration start)
Nov 18 02:15:02 vpn-gw openvpn: user le.tran assigned 10.8.0.14
EOF

# ===================== NGU CANH DOANH NGHIEP =====================
cat > "$H/ctx-assets.txt" <<'EOF'
=== DANH MỤC TÀI SẢN (mức: Cao/TB/Thấp) ===
web01    = TB    (web server bán hàng)
app02    = Thấp  (ứng dụng nội bộ)
db-core  = Cao   (CSDL lõi - dữ liệu khách hàng)
vpn-gw   = TB    (cổng VPN)

=== DỊCH VỤ ĐÃ DUYỆT (SVC) - hoạt động hợp lệ có thể làm luật nổ (báo giả) ===
SVC-4001 : Máy quét lỗ hổng nội bộ. Nguồn IP 10.10.0.10. Khung quét đã duyệt 02:00-04:00 hàng ngày.
SVC-4002 : Dịch vụ AV tra cứu hash đám mây. Truy vấn tên miền *.av-cloud-security.example.
SVC-4003 : Agent giám sát, tiến trình /opt/monitoring/sysmon-helper (tên giống mẫu implant -> dễ báo nhầm).
SVC-4004 : Xoay vòng log hàng đêm (03:00), đổi/nén file dưới /var/log và /var/www/logs.
EOF

cat > "$H/ctx-changes.txt" <<'EOF'
=== PHIẾU THAY ĐỔI (CHG) ===
CHG-7731 : Thuê pentest. Mục tiêu web01. Nguồn IP 203.0.113.44. Khung 01:00-03:00. (Cho phép SQLi/scan từ IP này trên web01)
CHG-7742 : Deploy mã nguồn lên web01. Bởi CI host 10.10.0.30. Khung 02:00-02:30. (Cho phép file mới trên web01)
CHG-7750 : Bảo trì db-core. Khung 00:30-01:00. TRẠNG THÁI: ĐÃ HOÀN TẤT. (!! Kết thúc 01:00 - KHÔNG phủ sự kiện sau 01:00)
EOF

cat > "$H/ctx-oncall.txt" <<'EOF'
=== LỊCH TRỰC ON-CALL (OC) ===
OC-9051 : Kỹ sư trực đêm nay le.tran. IP quen 10.10.0.55. (Cho phép đăng nhập ngoài giờ từ IP này)
EOF

cat > "$H/ctx-leave.txt" <<'EOF'
=== HỒ SƠ NGHỈ PHÉP (LV) ===
ketoan01 (Phòng Tài chính) : ĐANG NGHỈ PHÉP 17-21/11. (Tài khoản này KHÔNG nên đăng nhập trong tuần này)
EOF

# ===================== SOP =====================
cat > "$H/SOP-triage.txt" <<'EOF'
================= SOP TRIAGE (quy trình phân loại cảnh báo) =================
BA KẾT LUẬN:
  1 = TP  (sự cố thật): hoạt động luật nhắm tới CÓ THẬT và KHÔNG được phép -> leo thang.
  2 = BTP (thật nhưng được phép): có thật NHƯNG có phiếu CHG/OC khớp ĐỦ -> đóng, ghi số phiếu.
  3 = FP  (báo giả): hoạt động luật nhắm tới KHÔNG xảy ra; luật nổ nhầm trên dịch vụ hợp lệ khác -> đóng, ghi SVC.

QUY TẮC KHỚP NGỮ CẢNH (chỉ được đóng ticket khi KHỚP ĐỦ):
  đúng MÁY + đúng CHỦ THỂ (IP/user/tiến trình/domain) + còn hiệu lực + (với CHG/OC) giờ cảnh báo NẰM TRONG khung phiếu.
  Thiếu bất kỳ điều kiện nào -> coi là SỰ CỐ THẬT (TP).

MA TRẬN ƯU TIÊN (chỉ cho sự cố thật - xét trên máy ghi trong ticket):
  Giai đoạn \ Mức tài sản     Cao   TB    Thấp
  A - Đang tác động           P1    P1    P2
  B - Đã truy cập thành công  P1    P2    P3
  C - Chỉ thử, chưa thành công P3   P3    P4
  (BTP và FP luôn là P4.)

CÁCH XÁC ĐỊNH GIAI ĐOẠN (A/B/C) - luôn lấy giai đoạn TIẾN XA NHẤT có bằng chứng (A > B > C):
  A - Đang tác động : hành vi gây hại ĐANG DIỄN RA / LẶP LẠI / điều khiển tương tác.
      Dấu hiệu: beacon C2 lặp (repeat 30s), exfil DNS nhiều lần, webshell ĐÃ CHẠY lệnh (?cmd=),
      tiến trình lạ kết nối C2 định kỳ.
  B - Đã truy cập   : MỘT lần vào được, chưa thấy hành vi lặp/điều khiển.
      Dấu hiệu: "Accepted password" (đăng nhập được), một lần dump dữ liệu, file độc MỚI TẠO (chưa chạy).
  C - Chỉ thử       : chỉ THẤT BẠI / dò quét, chưa vào được.
      Dấu hiệu: "Failed password" lặp, burst of attempts, scan/probe.
  Mấu chốt A vs B: A = lặp lại / đang chạy / điều khiển ; B = một lần truy cập.
  Lưu ý: vừa truy cập xong VỪA exfil định kỳ -> xếp A (không tách giai đoạn, lấy mốc cao nhất).

PHIẾU TRIAGE (~/triage.txt): mỗi ticket 1 dòng  INC-1xx=V,P,E
  V = kết luận (1/2/3) ; P = ưu tiên (1..4) ; E = bằng chứng (một số nguyên):
    TP  -> IOC chính (octet cuối IP kẻ tấn công / IP C2)
    BTP -> số phiếu CHG hoặc OC (vd 7731)
    FP  -> số SVC (vd 4001)

MỤC TIÊU THỜI GIAN: ~5' mỗi ticket, xong hàng đợi trong 60' đầu ca. (V1: không trừ điểm nếu trễ.)

MA HÀNH ĐỘNG (cho phiếu leo-thang ~/leo-thang.txt, trường DE_XUAT):
  1=cô lập mạng  2=giữ nguyên bộ nhớ/tiến trình  3=chặn IP C2  4=tắt nguồn ngay
  5=vô hiệu hóa tài khoản liên quan  6=xóa ngay file độc  7=đóng ticket vì đã chặn IP  8=báo chủ tài sản
  (LƯU Ý: 4/6/7 làm MẤT bằng chứng -> không chọn khi còn điều tra.)
EOF

# ===================== PHIEU LAM BAI =====================
cat > "$H/triage.txt" <<'EOF'
# PHIẾU TRIAGE - mỗi ticket 1 dòng: INC-1xx=V,P,E  (V=1/2/3  P=1..4  E=số nguyên bằng chứng)
INC-101=
INC-102=
INC-103=
INC-104=
INC-105=
INC-106=
INC-107=
INC-108=
INC-109=
INC-110=
INC-111=
INC-112=
INC-113=
EOF

cat > "$H/leo-thang.txt" <<'EOF'
# PHIẾU LEO THANG P1 (INC-113). Điền giá trị (số) sau dấu '=':
TICKET=
HOST=
ASSET_LEVEL=     # 1=Cao 2=TB 3=Thấp
STAGE=           # 1=A(đang tác động) 2=B(đã truy cập) 3=C(chỉ thử)
MITRE=           # kỹ thuật ATT&CK chính, ghi số (vd T1071 -> 1071)
IOC_C2=          # octet cuối IP máy chủ C2
LIEN_QUAN=       # số ticket khác trong hàng đợi thuộc cùng sự cố
DE_XUAT=         # các mã hành động, cách nhau dấu phẩy (vd 3,5,8)
TOM_TAT=         # 2-3 câu: chuyện gì, từ khi nào, bằng cách nào, mức ảnh hưởng
EOF

cat > "$H/yeu-cau-tinh-chinh.txt" <<'EOF'
# YÊU CẦU TINH CHỈNH LUẬT (cho mỗi báo giả FP): luật nào, trường nào gây nhầm, đề xuất sửa.
# (Giảng viên chấm tay - không chấm tự động.)
EOF

exit 0
__EOF_TRI_9x2k__
cat > "$LAB/defender/_bin/prestop" <<'__EOF_TRI_9x2k__'
#!/bin/bash
# Cham bai triage tren defender: doc ~/triage.txt + ~/leo-thang.txt, doi chieu dap an.
# Dap an V (ket luan) va P (uu tien) CO DINH; bang chung E suy ra tu raw-log (IOC ngau nhien per-student).
# Chi in marker OK, KHONG in dap an.
trap "echo Timed out; exit" SIGTERM
echo "PRESTOP_MARKER"

H="$HOME"
T="$H/triage.txt"
L="$H/leo-thang.txt"

# --- Suy ra IOC that tu raw-log (ground truth cho E cua cac ticket TP) ---
ATK=$(grep -oE '203\.0\.113\.[0-9]+' "$H/raw-logs/web01.log" 2>/dev/null | head -1 | grep -oE '[0-9]+$')
C2A=$(grep -oE '198\.51\.100\.[0-9]+' "$H/raw-logs/app02.log" 2>/dev/null | head -1 | grep -oE '[0-9]+$')
C2D=$(grep -oE '192\.0\.2\.[0-9]+' "$H/raw-logs/db-core.log" 2>/dev/null | head -1 | grep -oE '[0-9]+$')

# --- Dap an ---
declare -A KV=( [101]=1 [102]=3 [103]=1 [104]=2 [105]=1 [106]=2 [107]=1 [108]=3 [109]=1 [110]=2 [111]=3 [112]=3 [113]=1 )
declare -A KP=( [101]=2 [102]=4 [103]=2 [104]=4 [105]=1 [106]=4 [107]=2 [108]=4 [109]=1 [110]=4 [111]=4 [112]=4 [113]=1 )
declare -A KE=( [101]=$ATK [102]=4001 [103]=$ATK [104]=7731 [105]=$ATK [106]=7742 [107]=$C2A [108]=4002 [109]=$ATK [110]=9051 [111]=4003 [112]=4004 [113]=$C2D )

# Lay truong tu dong INC-n ( "V,P,E" )
field(){ sed -n "s/^INC-$1=//p" "$T" 2>/dev/null | head -1 | tr -d ' \r'; }

vcorrect=0; ecorrect=0; miss_tp=0; overesc=0; pwrong=0
for n in 101 102 103 104 105 106 107 108 109 110 111 112 113; do
  line=$(field "$n")
  V=$(echo "$line" | cut -d, -f1)
  P=$(echo "$line" | cut -d, -f2)
  E=$(echo "$line" | cut -d, -f3 | tr -cd '0-9')
  [ "$V" = "${KV[$n]}" ] && vcorrect=$((vcorrect+1))
  [ -n "$E" ] && [ "$E" = "${KE[$n]}" ] && ecorrect=$((ecorrect+1))
  if [ "${KV[$n]}" = "1" ]; then
    [ "$V" != "1" ] && miss_tp=$((miss_tp+1))
    [ "$V" = "1" ] && [ "$P" != "${KP[$n]}" ] && pwrong=$((pwrong+1))
  else
    [ "$V" = "1" ] && overesc=$((overesc+1))
  fi
done

[ "$vcorrect" -ge 10 ] && echo "TRIAGE_ACCURACY_OK"
[ "$miss_tp" -eq 0 ]   && echo "NO_MISSED_TP"
[ "$overesc" -le 1 ]   && echo "LOW_OVERESCALATION"
[ "$pwrong" -le 1 ]    && echo "PRIORITY_OK"
[ "$ecorrect" -ge 9 ]  && echo "EVIDENCE_OK"

# --- INC-113 live: V=1, P=1, E=C2D ---
l113=$(field 113)
V113=$(echo "$l113" | cut -d, -f1)
P113=$(echo "$l113" | cut -d, -f2)
E113=$(echo "$l113" | cut -d, -f3 | tr -cd '0-9')
if [ "$V113" = "1" ] && [ "$P113" = "1" ] && [ -n "$C2D" ] && [ "$E113" = "$C2D" ]; then
  echo "LIVE_TRIAGED"
fi

# --- Phieu leo thang INC-113 ---
gl(){ sed -n "s/^$1=//p" "$L" 2>/dev/null | head -1 | sed 's/#.*//' | tr -d ' \r'; }
AL=$(gl ASSET_LEVEL); ST=$(gl STAGE); IC=$(gl IOC_C2 | tr -cd '0-9'); LQ=$(gl LIEN_QUAN | tr -cd '0-9')
DX=",$(gl DE_XUAT | tr -d ' '),"
has(){ echo "$DX" | grep -q ",$1,"; }
if [ "$AL" = "1" ] && [ "$ST" = "1" ] && [ -n "$C2D" ] && [ "$IC" = "$C2D" ] && [ "$LQ" = "109" ] \
   && has 3 && has 5 && ! has 4 && ! has 6 && ! has 7; then
  echo "ESCALATION_NOTE_OK"
fi

exit 0
__EOF_TRI_9x2k__
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_TRI_9x2k__'
#!/bin/bash
# Mo Wazuh dashboard trong Firefox tren tram defender (source vao shell dang nhap -> khong goi exit).
# Chong loi X11 "cannot open display": tao FILE symlink /tmp/.X11-unix/X<n> khi thieu.
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
__EOF_TRI_9x2k__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-alert-triage.defender.student" <<'__EOF_TRI_9x2k__'
#
# Labtainer Dockerfile - defender (tram analyst: Firefox GUI + cong cu dieu tra)
#
ARG registry
FROM $registry/labtainer.firefox3

ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh

RUN apt-get update && apt-get install -y --no-install-recommends openssh-client coreutils \
    && rm -rf /var/lib/apt/lists/*

# === Locale UTF-8 (de cat/nano/less hien tieng Viet CO DAU trong file ctx-*/SOP/read_first) ===
# Labtainers mo terminal qua login session (PAM/su) -> reset ENV Docker; ghi vao /etc/default/locale
# + /etc/environment + .bashrc de locale ben vung qua moi cach dang nhap.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
RUN printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' > /etc/default/locale \
    && printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' >> /etc/environment

ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /

RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo

USER $user_name
ENV HOME /home/$user_name

ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME

USER root
RUN printf '\nexport LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n' >> /home/$user_name/.bashrc \
    && chown $user_name:$user_name /home/$user_name/.bashrc
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_TRI_9x2k__
cat > "$LAB/dockerfiles/Dockerfile.soc-alert-triage.siem.student" <<'__EOF_TRI_9x2k__'
#
# siem - dung image nen soc-wazuh (Wazuh cai san). Entrypoint khoi phuc quyen Wazuh truoc init.
# LUU Y: anh soc-wazuh KHONG chay boot-hook Labtainers -> fixlocal.sh cua siem KHONG chay.
# Vi vay TOAN BO seeding hang doi alert duoc BAKE vao anh nay (rule + localfile + seed log + seeder nen).
#
ARG registry
FROM localhost:5000/soc-wazuh:latest
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# === Dong bo mui gio voi VM (ICT = UTC+7) ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# === SEEDING (bake) 1: bo rule ho canh bao (match program_name soctriage + FAMILY=...) ===
RUN printf '%s\n' \
  '<group name="local,soctriage_queue,">' \
  '  <rule id="100600" level="8"><program_name>soctriage</program_name><match>FAMILY=ssh_bruteforce</match><description>SSH brute-force suspected</description><mitre><id>T1110</id></mitre></rule>' \
  '  <rule id="100601" level="10"><program_name>soctriage</program_name><match>FAMILY=sqli</match><description>Possible SQL injection against web app</description><mitre><id>T1190</id></mitre></rule>' \
  '  <rule id="100602" level="12"><program_name>soctriage</program_name><match>FAMILY=webfile</match><description>New executable file in web directory (possible web shell)</description><mitre><id>T1505</id></mitre></rule>' \
  '  <rule id="100603" level="10"><program_name>soctriage</program_name><match>FAMILY=dns_tunnel</match><description>Long DNS subdomain to rare domain (possible tunneling)</description><mitre><id>T1048</id></mitre></rule>' \
  '  <rule id="100604" level="8"><program_name>soctriage</program_name><match>FAMILY=offhours_login</match><description>Off-hours interactive login</description><mitre><id>T1078</id></mitre></rule>' \
  '  <rule id="100605" level="12"><program_name>soctriage</program_name><match>FAMILY=susp_process</match><description>Suspicious masquerading process / beaconing</description><mitre><id>T1055</id></mitre></rule>' \
  '  <rule id="100606" level="7"><program_name>soctriage</program_name><match>FAMILY=massfile</match><description>Mass file modification</description><mitre><id>T1070</id></mitre></rule>' \
  '</group>' \
  >> /var/ossec/etc/rules/local_rules.xml
#
# === SEEDING (bake) 2: localfile cho manager giam sat log hang doi + tao san log ===
RUN printf '%s\n' '<ossec_config><localfile><log_format>syslog</log_format><location>/var/log/soc-queue.log</location></localfile></ossec_config>' >> /var/ossec/etc/ossec.conf \
    && touch /var/log/soc-queue.log && chmod 666 /var/log/soc-queue.log
#
# === SEEDING (bake) 3: script seeder nen - ghi 12 ticket + hen INC-113 (co co chong seed trung) ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  '# ensure_mgr: anh soc-wazuh hay fail wazuh-manager luc first-boot (boot-race indexer) -> restart cho song.' \
  'mgr_active(){ [ "$(systemctl is-active wazuh-manager 2>/dev/null)" = "active" ]; }' \
  'ensure_mgr(){ for i in $(seq 1 30); do mgr_active && return 0; sleep 2; done; for r in 1 2 3; do systemctl restart wazuh-manager >/dev/null 2>&1; for j in $(seq 1 25); do mgr_active && return 0; sleep 3; done; done; }' \
  'ensure_mgr' \
  '[ -f /var/ossec/.soc_seeded ] && exit 0' \
  'Q=/var/log/soc-queue.log' \
  'sleep 15' \
  'emit(){ echo "$(date "+%b %d %H:%M:%S") siem soctriage: $1|NOTE=$2" >> "$Q"; sleep 1; }' \
  'emit "INC-101|FAMILY=ssh_bruteforce|HOST=web01" "many failed SSH logins then one success"' \
  'emit "INC-102|FAMILY=ssh_bruteforce|HOST=web01" "burst of SSH auth attempts from one internal host"' \
  'emit "INC-103|FAMILY=sqli|HOST=web01" "SQLi patterns in access log, one client large HTTP 200"' \
  'emit "INC-104|FAMILY=sqli|HOST=web01" "SQLi patterns in access log from one source"' \
  'emit "INC-105|FAMILY=webfile|HOST=web01" "new .php in uploads then executed"' \
  'emit "INC-106|FAMILY=webfile|HOST=web01" "several new files under webroot"' \
  'emit "INC-107|FAMILY=dns_tunnel|HOST=app02" "repeated long base64-like subdomains to rare domain"' \
  'emit "INC-108|FAMILY=dns_tunnel|HOST=app02" "long subdomain lookups to a rare domain"' \
  'emit "INC-109|FAMILY=offhours_login|HOST=db-core" "02:4x login for a finance account from new IP"' \
  'emit "INC-110|FAMILY=offhours_login|HOST=vpn-gw" "02:1x VPN login from a known IP"' \
  'emit "INC-111|FAMILY=susp_process|HOST=app02" "process name matches implant signature"' \
  'emit "INC-112|FAMILY=massfile|HOST=web01" "hundreds of files changed under /var/log and /var/www"' \
  'touch /var/ossec/.soc_seeded' \
  '( sleep 720; echo "$(date "+%b %d %H:%M:%S") siem soctriage: INC-113|FAMILY=susp_process|HOST=db-core|NOTE=[kworker/u4:2] from /tmp/.k beaconing C2 every 30s" >> "$Q" ) &' \
  > /usr/local/bin/soc-seeder.sh && chmod +x /usr/local/bin/soc-seeder.sh
#
# === Entrypoint: khoi phuc quyen Wazuh + launch seeder nen truoc khi exec init ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  'for u in wazuh-indexer wazuh-dashboard; do' \
  '  id "$u" >/dev/null 2>&1 || continue' \
  '  chown -R "$u:$u" /usr/share/$u /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
  'done' \
  'rm -f /var/ossec/queue/rids/* /var/ossec/etc/client.keys /var/ossec/queue/agents-timestamp 2>/dev/null' \
  'setsid bash /usr/local/bin/soc-seeder.sh >/var/log/soc-seeder.log 2>&1 </dev/null &' \
  'exec /sbin/init --log-target=journal 3>&1' \
  > /entrypoint.sh && chmod +x /entrypoint.sh
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
RUN mkdir -p /home/$user_name/.local && echo "soc-alert-triage" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
CMD ["/entrypoint.sh"]
__EOF_TRI_9x2k__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_TRI_9x2k__'
================================================================================
 SOC LAB: TRIAGE HÀNG ĐỢI CẢNH BÁO (lần báo giá) - phân loại TP/BTP/FP + ưu tiên + P1
================================================================================

1. BỐI CẢNH
--------------------------------------------------------------------------------
Sau ca đêm, Wazuh SIEM của Công ty X còn một HÀNG ĐỢI 12 ticket chưa xử lý. Đêm qua có: quét lỗ hổng định kỳ,
pentest thuê ngoài, DevOps deploy, kỹ sư on-call vào hệ thống -> phần lớn ticket là HỢP LỆ. Lẫn trong đó là
những dấu hiệu đầu tiên của một nhóm APT. Nhiệm vụ của bạn: tách hoạt động hợp lệ khỏi sự cố THẬT, xếp ưu tiên,
và xử lý 1 ticket P1 chen ngang.

  *** Lần đầu siem khởi động Wazuh ~1-2'. Hàng đợi 12 alert tự lên dashboard; INC-113 xuất hiện trễ ~12'. ***

2. ĐĂNG NHẬP & DỮ LIỆU
--------------------------------------------------------------------------------
  Dashboard (Firefox tự mở):  https://172.20.0.20   admin / Q*uJjovx2guqFRqntC568k?lf3evm.jl
    -> Threat Hunting / Discover, chọn Today / Last 24h -> thấy 12 ticket INC-101..112 (+ INC-113 sau ~12').
       full_log mỗi alert: INC-1xx|FAMILY=...|HOST=...|NOTE=...
  Trên trạm defender (nơi bạn làm bài) có sẵn:
    ~/SOP-triage.txt      : quy trình (ĐỌC TRƯỚC)
    ~/ctx-assets.txt      : danh mục tài sản + dịch vụ đã duyệt (SVC)
    ~/ctx-changes.txt     : phiếu thay đổi (CHG)
    ~/ctx-oncall.txt      : lịch trực on-call (OC)
    ~/ctx-leave.txt       : hồ sơ nghỉ phép (LV)
    ~/raw-logs/<host>.log : log thô từng máy để PIVOT điều tra (web01/app02/db-core/vpn-gw)
    ~/triage.txt ~/leo-thang.txt ~/yeu-cau-tinh-chinh.txt : các phiếu làm bài

3. BA KẾT LUẬN (xem SOP để đầy đủ)
--------------------------------------------------------------------------------
  1 = TP  (sự cố thật)             : hoạt động CÓ THẬT và KHÔNG được phép        -> leo thang
  2 = BTP (thật nhưng được phép)   : có thật NHƯNG khớp ĐỦ phiếu CHG/OC          -> đóng, ghi số phiếu
  3 = FP  (báo giả)                : hoạt động không xảy ra; luật nổ nhầm trên SVC hợp lệ -> đóng, ghi số SVC
  Quy tắc: chỉ đóng ticket khi KHỚP ĐỦ (đúng máy + đúng chủ thể + còn hiệu lực + giờ nằm trong khung phiếu).
  Thiếu bất kỳ điều kiện nào -> coi là SỰ CỐ THẬT (TP). Cảnh giác PHIẾU LỆCH (hết giờ / sai IP / đã hủy).

4. NHIỆM VỤ (theo thứ tự)
--------------------------------------------------------------------------------
 B1. ĐỌC ~/SOP-triage.txt. Sau đó TRIAGE: với mỗi ticket, tra ÍT NHẤT 2 nguồn: (a) raw-log cùng máy/IP/user (~/raw-logs/<host>.log),
     (b) ngữ cảnh ctx-*. Ghi vào ~/triage.txt mỗi dòng:  INC-1xx=V,P,E
       V = 1/2/3 ; P = ưu tiên 1..4 (BTP và FP luôn 4) ; E = bằng chứng (1 số nguyên):
         TP  -> octet cuối IP kẻ tấn công / IP C2   (tìm trong raw-log)
         BTP -> số phiếu CHG hoặc OC                 (vd 7731)
         FP  -> số SVC                               (vd 4001)
     MA TRẬN ƯU TIÊN (chỉ cho TP, xét trên máy ghi trong ticket):
       Giai đoạn\Mức    Cao  TB   Thấp
       A-đang tác động  P1   P1   P2
       B-đã truy cập    P1   P2   P3
       C-chỉ thử        P3   P3   P4

 B2. P1 CHEN NGANG: khi INC-113 xuất hiện (tiến trình [kworker/u4:2] từ /tmp/.k beacon C2 trên db-core),
     ghi dòng INC-113 vào ~/triage.txt VÀ điền ~/leo-thang.txt (TICKET, HOST, ASSET_LEVEL, STAGE, MITRE,
     IOC_C2, LIEN_QUAN, DE_XUAT, TOM_TAT). Chú ý chọn MÃ HÀNH ĐỘNG đúng - KHÔNG chọn 4/6/7 (làm mất bằng chứng).
     Gợi ý: xem ~/raw-logs/db-core.log; tìm ticket trong hàng đợi dùng chính IP kẻ tấn công -> cùng sự cố.

 B3. (Giảng viên chấm tay) ~/yeu-cau-tinh-chinh.txt: mỗi FP ghi luật/trường gây nhầm + đề xuất sửa.

 GỢI Ý ĐIỀU TRA (cấp 2):
   - SSH brute: grep sshd ~/raw-logs/web01.log  -> IP ngoài 203.0.113.x + "Accepted" = TP; 10.10.0.10 trong 02:00-04:00 = scanner (SVC-4001) = FP.
   - SQLi: grep apache ~/raw-logs/web01.log -> IP ngoài + 200 kích thước lớn = TP; IP 203.0.113.44 khớp CHG-7731 = BTP.
   - web file: shell.php POST rồi GET cmd= từ IP ngoài = TP; file từ 10.10.0.30 khớp CHG-7742 = BTP.
   - DNS: subdomain base64 -> badguy-c2.net = TP (E=octet IP C2 ...100.x); -> av-cloud-security.example = AV (SVC-4002) = FP.
   - Off-hours: ketoan01 (xem ctx-leave ĐANG NGHỈ) từ IP ngoài = TP; le.tran từ 10.10.0.55 khớp OC-9051 = BTP.
     (Chú ý CHG-7750 nhắc db-core NHƯNG hết giờ 01:00 -> KHÔNG phủ sự kiện 02:4x -> vẫn TP.)
   - susp_process app02: /opt/monitoring/sysmon-helper khớp SVC-4003 = FP.
   - massfile web01: log rotation 03:00 khớp SVC-4004 = FP.

5. NỘP BÀI - CÁC MỤC CHẤM (checkwork)
--------------------------------------------------------------------------------
  triage_accuracy   : đúng kết luận >= 10/12 ticket
  no_missed_tp      : KHÔNG đóng nhầm sự cố thật nào (bắt buộc)
  low_overescalation: leo thang thừa tối đa 1 ticket hợp lệ
  priority_ok       : sai ưu tiên tối đa 1 sự cố thật
  evidence_ok       : đúng bằng chứng E >= 9/12 (đã pivot thật)
  live_triaged      : INC-113 đúng V=1, P=1, IP C2
  escalation_note   : phiếu leo-thang.txt đúng trường định lượng + mã hành động (không 4/6/7)
__EOF_TRI_9x2k__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_TRI_9x2k__'
# goals.config - soc-alert-triage (Triage hang doi canh bao). Cham VIEC SV LAM tren ~/triage.txt + ~/leo-thang.txt.
# (yeu-cau-tinh-chinh.txt: giang vien cham tay - khong cham tu dong.)

# Dung ket luan >= 10/12 ticket
triage_accuracy    = boolean : cw_acc
# KHONG dong nham su co that nao (bat buoc)
no_missed_tp       = boolean : cw_miss
# Leo thang thua toi da 1 ticket khong phai su co
low_overescalation = boolean : cw_over
# Sai muc uu tien toi da 1 su co that
priority_ok        = boolean : cw_prio
# Dung bang chung E >= 9/12 (chung minh da pivot that)
evidence_ok        = boolean : cw_evid
# INC-113 (P1 chen ngang): dung ket luan + uu tien P1 + IP C2
live_triaged       = boolean : cw_live
# Phieu leo thang INC-113 dung cac truong dinh luong + ma hanh dong (khong chon ma lam mat bang chung 4/6/7)
escalation_note    = boolean : cw_esc
__EOF_TRI_9x2k__
cat > "$LAB/instr_config/results.config" <<'__EOF_TRI_9x2k__'
# results.config - soc-alert-triage. Prestop (defender) in marker OK, khong lo dap an.
# Goal (goals.config) tro THANG vao cac result cw_* o duoi (chi xet ban prestop.stdout MOI NHAT).
# KHONG dung result _* nua: result khong co tien to cw_ bi grader quet MOI timestamp lich su
# -> marker tung xuat hien 1 lan (luc SV lam dung) se lam goal dau VINH VIEN du sau do sua sai.

# --- Goi y checkwork ---
#CHECK_TRUE: Dung ket luan chua du 10/12 - doi chieu tung ticket voi ngu canh (SVC/CHG/OC/LV) + raw-log ~/raw-logs. Dien ~/triage.txt dang INC-1xx=V,P,E.
cw_acc = defender:prestop.stdout : FILE_REGEX : TRIAGE_ACCURACY_OK
#CHECK_TRUE: Co su co that bi dong nham (V=2 hoac 3) - chi dong khi KHOP DU ngu canh; thieu can cu -> coi la TP (V=1).
cw_miss = defender:prestop.stdout : FILE_REGEX : NO_MISSED_TP
#CHECK_TRUE: Leo thang nham qua nhieu hoat dong hop le - hoat dong khop CHG/OC/SVC la BTP/FP, khong phai TP.
cw_over = defender:prestop.stdout : FILE_REGEX : LOW_OVERESCALATION
#CHECK_TRUE: Sai muc uu tien - xet ma tran (giai doan A/B/C x muc tai san Cao/TB/Thap). BTP/FP luon P4.
cw_prio = defender:prestop.stdout : FILE_REGEX : PRIORITY_OK
#CHECK_TRUE: Bang chung E chua du 9/12 - TP ghi octet cuoi IP tan cong/C2 (tim trong raw-log), BTP ghi so CHG/OC, FP ghi so SVC.
cw_evid = defender:prestop.stdout : FILE_REGEX : EVIDENCE_OK
#CHECK_TRUE: INC-113 chua dung - V=1, P=1, E=octet IP C2 (192.0.2.x trong db-core.log). Dien dong INC-113 trong ~/triage.txt.
cw_live = defender:prestop.stdout : FILE_REGEX : LIVE_TRIAGED
#CHECK_TRUE: Phieu ~/leo-thang.txt chua dung - ASSET_LEVEL=1, STAGE=1, IOC_C2=octet C2, LIEN_QUAN=109, DE_XUAT gom 3,5 va KHONG gom 4/6/7.
cw_esc = defender:prestop.stdout : FILE_REGEX : ESCALATION_NOTE_OK
__EOF_TRI_9x2k__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_TRI_9x2k__'
#!/bin/bash
# LUU Y: anh chung soc-wazuh KHONG chay boot-hook Labtainers nen file nay KHONG duoc goi.
# Toan bo seeding hang doi alert da duoc BAKE vao Dockerfile.soc-alert-triage.siem.student
# (rule + localfile + /usr/local/bin/soc-seeder.sh chay nen tu /entrypoint.sh).
exit 0
__EOF_TRI_9x2k__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/defender/_bin/* "$LAB"/siem/_bin/* 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-alert-triage"
