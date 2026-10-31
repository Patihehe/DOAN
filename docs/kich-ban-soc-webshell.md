# Kịch bản lab: `soc-webshell` — Web Shell Upload → RCE (Hybrid)

> Tài liệu mô tả kịch bản để nhóm/GVHD duyệt TRƯỚC khi code. (Không phải giải mẫu — được commit.)

## 1. Ý tưởng
Web app có chức năng **upload file** dùng **blocklist ngây thơ** (chỉ chặn đúng `.php`) → kẻ tấn công
bypass bằng `.phtml` để thả **web shell** và **thực thi lệnh (RCE)**. Lab theo mô hình **Hybrid A/B**
(như `soc-patch-pwn`): **Blue** vá hệ A, **Red** khai thác hệ B lấy cờ.

Không trùng 8 bài đã có: khác SQLi/XSS (lab 3,5), khác path traversal (lab 7), khác reverse shell
gieo sẵn (lab 4). Đây là **chuỗi xâm nhập web server thật**: recon → upload bypass → RCE →
persistence → điều tra → vá gốc. MITRE **T1505.003** (Web Shell), **T1190**, **T1059**.

## 2. Topology (5 container)
| Container | IP | Vai trò |
|---|---|---|
| `attacker` | 172.20.0.5 | Tự động tấn công **hệ A** (recon → bypass → RCE → persistence → beacon) |
| `targeta` (**hệ A**) | 172.20.0.10 | **SV phòng thủ**: web upload lỗi + Wazuh agent + FIM |
| `targetb` (**hệ B**) | 172.20.0.11 | **SV tấn công** lấy cờ: cùng app lỗi, chỉ HTTP (không SSH/Wazuh) |
| `siem` | 172.20.0.20 | Wazuh (dùng chung ảnh `soc-wazuh`) |
| `defender` | 172.20.0.30 | Trạm SV: điều tra A (dashboard+SSH), tấn công B (curl/trình duyệt) |

## 3. App lỗi (giống nhau trên A và B)
- PHP upload "ảnh đại diện": lưu vào `/var/www/html/uploads/` giữ tên gốc, **không kiểm MIME**,
  thư mục uploads **thực thi PHP**.
- **Blocklist ngây thơ:** `if (strtolower(duoi) === '.php') tu_choi; else nhan`.
- **Bypass chạy được:** `.phtml` (Apache mặc định vẫn thực thi `.phtml`, không khớp blocklist `.php`).
- **Bẫy thực tế:** `.pHp` lọt blocklist nhưng Apache (handler phân biệt hoa thường) **không thực thi**
  → trả source, không RCE → attacker thử rồi loại.

## 4. Attacker tự động (kill-chain thật, không hardcode)
Mỗi vòng chạy LẠI từ đầu (nên khi SV vá thì nó tự fail):
- **Pha 0 Recon:** chờ `targeta:80`, `curl -I` đọc header, xem trang chủ/robots.
- **Pha 1 Content discovery:** dir-bust wordlist nhỏ (`/upload,/uploads,/profile,...`), parse form
  upload (lấy tên field + action) — không hardcode.
- **Pha 2 Dò điều kiện:** thử `test.jpg` (baseline, tìm nơi lưu) → `shell.php` (bị chặn) →
  thử bypass `.phtml`/`.pHp`/double-ext/spoof Content-Type; giữ cái server chấp nhận.
- **Pha 3 Verify RCE:** gọi file vừa upload với marker duy nhất; có marker = RCE thật, else loại.
- **Pha 4 Hậu khai thác:** `whoami/id/ls webroot`, đọc cờ hệ A; thả shell tầng 2 + cron (persistence).
- **Pha 5 Beacon:** vài phút/lần chạy lại Pha 1→3 → xoá-không-vá thì upload lại; vá đúng thì fail.

→ Sinh **log thực tế nhiều nhiễu** (404 dir-bust + loạt upload thử + GET `?cmd=`): blue team phải
tìm **1 upload thành công** giữa nhiễu.

## 5. Hệ A — Blue team
1. Điều tra dashboard: FIM thấy `.phtml` lạ trong uploads + access log POST upload & GET `?cmd=` + IP.
2. Xoá webshell + persistence (shell tầng 2, cron).
3. **Vá gốc** upload: allowlist jpg/png + `getimagesize()`, **hoặc** tắt thực thi PHP ở uploads
   (`.htaccess: php_admin_flag engine off`).
4. (Chặn IP attacker — không đủ, phải vá mới dứt).
5. Giữ **upload ảnh hợp lệ vẫn chạy** (SLA).

## 6. Hệ B — Red team (lấy cờ)
SV tự khai thác B từ trạm defender: recon form → `.php` bị chặn → tìm `.phtml` → upload webshell →
RCE → đọc `flag_<rand>.txt` → lấy **WEBSHELLFLAG** (cá nhân hóa) → nộp.

## 7. Phát hiện (SV tự dựng trên SIEM)
- **FIM** `/var/www/html/uploads` → file đuôi `php/phtml/phar/pht` → rule `local_rules.xml` mức 12.
- (Tùy chọn) rule access-log: GET `/uploads/*.ph*?cmd=`.

## 8. Chấm điểm (rigor)
| Mục | Đạt (Y) khi |
|---|---|
| `a_detected` | SIEM có alert webshell trên A (rule SV nổ) |
| `a_removed` | Không còn file `.php*` trong uploads của A |
| `a_patched` | prestop thử upload `.phtml/.pHp/double-ext` lên A → đều bị chặn/không thực thi |
| `a_sla` | Upload ảnh jpg hợp lệ lên A vẫn OK |
| `b_flag` | SV nộp đúng WEBSHELLFLAG lấy từ B |
| `blue_done` | a_detected ∧ a_removed ∧ a_patched ∧ a_sla |
| `mission_complete` | blue_done ∧ b_flag |

## 9. Cá nhân hóa chống chép (RAND_REPLACE)
- `FLAGVAL` (cờ hệ B) + tên/đường dẫn webshell attacker dùng trên A + đường dẫn file cờ → mỗi SV khác.
- `prestop` chỉ in cờ/OK, không lộ IOC cá nhân hóa.

## 10. Chuẩn tối ưu & tương thích nhóm
- `siem` dùng chung `soc-wazuh` (chạy `apply-shared-siem` sau khi deploy).
- Mọi `RUN apt install` kèm dọn `apt/lists`; base `network.ssh` (A) / `network` (B) / `firefox3` (defender).
- `config/*.config` + `instr_config/*.config` là ASCII thuần; TZ `Asia/Ho_Chi_Minh`.
- Attacker trỏ manager 172.20.0.20; targeta IP cố định 172.20.0.10.
