# Bài 17 (`soc-privesc` mở rộng) — ghi chú triển khai

Tài liệu đi kèm bản dựng Bài 17. Kịch bản: `docs/kich-ban-soc-privesc-ir.md`. Giải mẫu: `docs/giai-mau-soc-privesc-ir.md` (local, không commit).

## 1. Những gì đã có trong bản dựng

| Phần | File | Trạng thái |
|---|---|---|
| Hạ tầng dùng chung | `labs/_shared/soc-tools/` (`wzapi.py`, `replay.py`, `kiem-thu-luat`, `thu-dong`, `goi-y`), `labs/_shared/sync-soc-tools.sh`, `labs/_shared/make-install.py`, `labs/_shared/goi-y-src/bai17.txt` | Đã kiểm với API Wazuh **mô phỏng** |
| attacker | `attack.sh` (7 giai đoạn), `_bin/fixlocal.sh` (sinh khóa SSH thật, thay `BK_KEY` trong `plant.sh`) | `bash -n` OK; chưa chạy trên VM |
| target | `_bin/fixlocal.sh` (nối khối 7–13), `ops-noise.sh`, `_bin/prestop` (nối khối chấm mới), Dockerfile (+ `libcap2-bin perl python3 vim-tiny nano less`, sudoers `sshd -T`) | `prestop` đã giả lập với log/phiếu giả |
| siem | Dockerfile (ảnh chung + 3 unit systemd), `bai17/seed17.py`, `bai17/grade17.py`, `bai17/gen17.py`, `bai17/bai17_prod_rules.xml`, `_bin/prestop` | Grader + bản đồ phủ đã kiểm với dữ liệu giả |
| defender | `_bin/fixlocal.sh`, `_bin/prestop`, `soc-tools/`, `bai17/` (CSV, tài liệu GTFO offline, gợi ý mã hóa, bộ sinh tập phát triển), Dockerfile (+ `python3`) | Công cụ đã kiểm với API mô phỏng |
| Chấm | `instr_config/results.config`, `goals.config` (giữ 8 goal gốc, thêm 9 goal + `bai17_pass`), `#CHECK_*` không lộ lệnh | ASCII OK; chưa chạy `checkwork` thật |
| Manual | `docs/read_first.txt`, `config/about.txt`, `config/parameter.config` (+ `NSPRAY`, `HVAR`, `EDVAR`), `config/start.config` (siem `TERMINALS 0`) | |
| Cài đặt | `labs/install-soc-privesc.sh` (sinh lại bằng `make-install.py`) | Đã thử cài ra thư mục tạm: cây file khớp nguồn |

## 2. Quyết định khi dựng (khác kịch bản / lộ trình)

1. **Bản đồ phủ** đặt ở khối `COVER_*` cuối `findings.txt` trên **target** (phương án B), để so khớp trong một `prestop`. siem tính đáp án thật và in `COVER_DESIGN_OK`; `coverage_ok` cần cả hai.
2. **L1 kiểm thêm tĩnh** `timeframe ≥ 600`: bộ phát lại gửi cả kịch bản gần như cùng lúc nên không đo được độ dài cửa sổ. `kiem-thu-luat` cảnh báo khi `timeframe` < `window_s` của kịch bản.
3. **User API `soc-tool`** (vai trò administrator) do `seed17.py` tạo bằng tài khoản API của dashboard (đọc từ `wazuh.yml`, vì ảnh chung đã xóa file mật khẩu cài đặt). Tập kiểm tra ẩn nằm trên hệ thống file siem, không truy cập được qua API.
4. **Decoder `sudo.program`**: trên Wazuh 4.14 decoder sudo gốc là chuỗi anh em nối tiếp (`offset="after_regex"`), decoder `COMMAND=(\.+)` cuối chuỗi ăn hết dòng nên **không thể thêm decoder anh em ở file khác** (đã thử trên VM: `program=None`). `seed17.py` chép `0320-sudo_decoders.xml` sang `etc/decoders/`, đổi 2 decoder COMMAND thành `<regex type="pcre2" offset="after_regex">COMMAND=((\S+).*)</regex>` + `<order>command, sudo.program</order>` (giữ nguyên `command`), và thêm `<decoder_exclude>` file gốc. Kiểm `analysisd -t` trước restart; lỗi thì tự gỡ. Tự kiểm → `DECODER=OK|FAIL`. Đã xác nhận trên VM (4.14.8): `sudo.program: '/usr/bin/awk'`.
5. **Luật sản xuất 100300** (UID 0 mới, level 12) — ngoài dải của SV.
6. **Bộ sinh kịch bản** thêm 2 biến thể lành so với kịch bản: "tác vụ dùng mật khẩu cũ" (1 user lỗi 6–8 lần) và "quên mật khẩu" (5–7 lần), để luật L1 đếm *số lần* thay vì *số tài khoản* bị bắt.
7. **`plant.sh` không sửa logic**: attacker thay dòng `BK_KEY` bằng khóa thật lúc khởi động.

## 3. Chạy trên VM

```bash
# 1) Ảnh chung soc-wazuh phải có sẵn ở localhost:5000 (như các lab khác)
cd <repo>/labs
bash install-soc-privesc.sh                # chép lab vào $LABTAINER_DIR/labs/soc-privesc
cd $LABTAINER_DIR/scripts/labtainer-student
rebuild soc-privesc                         # KHONG chay apply-shared-siem.sh nua (Dockerfile siem da dung anh chung)
labtainer soc-privesc
```

Phát triển nhanh: tạo file `/home/ubuntu/.fast` trong container attacker **trước** khi chuỗi chạy (vd sửa `attacker/_bin/fixlocal.sh` tạm thời) → mọi khoảng chờ chia 4. **Xóa trước khi phát hành.**

Sửa công cụ dùng chung: sửa trong `labs/_shared/soc-tools/` → `bash labs/_shared/sync-soc-tools.sh soc-privesc` → `python3 labs/_shared/make-install.py soc-privesc "..."`.

## 4. Spike phải chạy trên VM (kèm chỗ chỉnh nếu lệch)

| # | Lệnh kiểm | Kỳ vọng | Nếu lệch, sửa ở |
|---|---|---|---|
| S2 | Sau khi chuỗi xong: `docker exec soc-privesc.siem.student python3 /home/ubuntu/bai17/grade17.py cover` | `GT_COVER=0000010`, `CHAIN_STAGES_SEEN=1111111` | Giai đoạn 0 có cảnh báo ≥ 10 → tăng khoảng cách dò trong `attack.sh` (`25 + RANDOM % 11`). Giai đoạn 5 = 0 → kiểm ID `5902` trong `bai17_prod_rules.xml` |
| S3 | `grep COMMAND=list /var/log/auth.log` trên target | có dòng của `emp<EMPNUM>` | `attack.sh` giai đoạn 2 |
| S6 | `getcap /usr/local/bin/*-report` trên target | có `cap_setuid` | khối 10 trong `target/_bin/fixlocal.sh` |
| S8 | `cat /root/.bai17/seeded` trên siem | `DECODER=OK` | xem `/root/.bai17/seed.log`; nếu FAIL: đổi L2 sang regex `<field name="command">` (gợi ý cấp 3 + giải mẫu) |
| S9 | Trên defender: `thu-dong "<dòng sudo>"` | in decoder + `sudo.program` | `wzapi.py` (URL/cổng), `seed17.py` (tạo user) |
| API | `cat /root/.bai17/seed.log` trên siem | `user API soc-tool id=...` | `wui_creds()` trong `seed17.py` (đường dẫn `wazuh.yml`) |
| Grader | Sau `kiem-thu-luat` với luật mẫu, đợi 30 s: `sudo python3 /home/ubuntu/bai17/grade17.py print` trên siem | `L1_OK L2_OK L3_OK`, `RULES_VALID=Y` | `grade17.py` |
| Thời gian | `cat /var/run/soc-ca-truc` trên target | có nội dung sau ~22–28' (chờ siem seed xong mới tấn công) | `nap` trong `attack.sh` |
| Chấm | Làm theo giải mẫu rồi `checkwork` | `bai17_pass = Y`, 8 goal gốc như trước | `results.config` / `goals.config` |

## 5. Ma trận kiểm thử (làm sau khi spike xanh)

Xem lộ trình `lo-trinh-xay-dung-bai17-soc-privesc.md` mục P8 (T1–T16). Các ca về luật (T7–T10) đã chạy trên bộ mô phỏng cho 8 tập ẩn khác nhau; kết quả ở giải mẫu mục 4.

## Kết quả chạy trên VM (Wazuh 4.14.8) — những điểm khác giả định ban đầu

| Điểm | Giả định | Thực tế | Đã sửa |
|---|---|---|---|
| Decoder `sudo.program` | decoder anh em ở file riêng | decoder sudo gốc là chuỗi `after_regex`, decoder COMMAND ăn hết dòng | chép + sửa `0320-sudo_decoders.xml`, `decoder_exclude` (seed17) |
| Khởi động | systemd đủ thời gian | indexer/manager hết giờ chờ khi VM tải nặng | drop-in `TimeoutStartSec`, seed restart 3 lần, attacker chờ seed |
| API | trả lỗi khi không ghi được | HTTP 200 + `failed_items` (1113) | `wzapi` kiểm `failed_items`; `kiem-thu-luat` đọc lại file |
| API timeout | 10 s đủ | lỗi 3021 khi VM chậm | `request_timeout: 60`, thử lại 3021 |
| `restart` | `/manager/status` phản ánh ngay | vài giây đầu vẫn báo tiến trình cũ | chờ thấy xuống rồi lên |
| Thẻ luật | `<srcuser>`, `<field name="srcuser">` | không hợp lệ (1113) | ngoại lệ bằng `<regex type="pcre2">`; kiểm cục bộ chặn |
| L1 | `different_srcuser` | sshd: tên ở `dstuser` → luôn 0 | `different_user` + `if_matched_sid 5760` |
| L2 | 5403 là con của 5402 | 5403 là con của 5400 | 2 luật (5402 + 5403) |
| prestop target | `stat %a` 4* = SUID | `755` khớp `7*` → báo sai (lỗi có từ lab gốc) | `[ -u ] \|\| [ -g ]` |
| defender `lab.json` | `S bash -c 'cat >' <<heredoc` | heredoc bị nuốt bởi pipe mật khẩu → rỗng | ghi /tmp rồi `S install` |

## Mật khẩu dashboard
Mỗi thành viên dựng ảnh `soc-wazuh` riêng → trình cài Wazuh sinh mật khẩu ngẫu nhiên khác nhau. Bài 17 **không ghi cứng** mật khẩu: Dockerfile defender `COPY --from=localhost:5000/soc-wazuh:latest /root/wazuh-admin-credentials.txt` (cùng ảnh với `FROM` của siem) và sinh `/etc/soc-tools/dashboard.txt`; `read_first` bảo người học `cat` file đó. Build sẽ **dừng** (`test -n "$P"`) nếu ảnh nền không có file mật khẩu. Các lab khác vẫn ghi cứng — nên áp dụng cùng cách hoặc phát hành chung một ảnh.
