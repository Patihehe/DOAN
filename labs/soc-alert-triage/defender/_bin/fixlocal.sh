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
