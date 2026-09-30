# Đề xuất kịch bản lab SOC (nâng cấp độ khó)

Tham khảo từ các cuộc thi/nền tảng phòng thủ: **CCDC** (defend + inject + giữ dịch vụ sống),
**Boss of the SOC / OpenSOC** (điều tra, dựng lại kill chain, trích IOC, trả lời câu hỏi),
**CyberDefenders** (log analysis, SIEM case investigation, threat hunting).

## Vì sao lab hiện tại "quá dễ"

Lab SSH brute-force hiện tại chấm theo **một hành động** (chặn 1 IP bằng 1 lệnh). Nhược điểm:
- Sinh viên không cần **điều tra** (IP kẻ tấn công đã lộ rõ, cố định).
- Chỉ **một bước** xử lý (không có gỡ persistence, không hardening, không kiểm chứng dịch vụ).
- **Chép được** (mọi sinh viên cùng 1 lệnh `iptables ... 172.20.0.5`).

## 6 nguyên tắc thiết kế lab SOC tốt (áp dụng cho mọi kịch bản)

1. **Điều tra-dẫn-dắt:** sinh viên phải TỰ tìm IOC (IP, user, tiến trình, tham số) từ SIEM/log.
2. **Cá nhân hóa (chống chép):** dùng `parameter.config` (`RAND_REPLACE`) → mỗi sinh viên có
   IP kẻ tấn công / tài khoản / "secret" khác nhau → đáp án khác nhau.
3. **Chấm theo câu trả lời (quiz):** Labtainers hỗ trợ `goals.answers` (băm đáp án) — bắt sinh
   viên nhập IOC tìm được (IP, user, số lần thất bại, tên tiến trình...) → chấm chiều sâu điều tra.
4. **Xử lý nhiều bước:** chặn + gỡ persistence + hardening + vá cấu hình, không chỉ 1 lệnh.
5. **Giữ dịch vụ sống (như CCDC):** chấm cả "không chặn nhầm traffic hợp lệ / dịch vụ vẫn chạy".
6. **Ánh xạ MITRE ATT&CK:** mỗi kịch bản gắn technique → tăng tính học thuật.

---

## KB1 (nâng cấp) — Brute-force → chiếm tài khoản → cài cắm  [DỄ→TB]

**MITRE:** T1110 Brute Force · T1136 Create Account · T1098 Account Manipulation · T1053.003 Cron

**Nâng cấp so với hiện tại:** attacker KHÔNG chỉ dò thất bại — nó **dò trúng** một tài khoản
yếu (mật khẩu cá nhân hóa theo seed), rồi **cài cắm**: tạo user backdoor / thêm SSH key lạ /
thêm cronjob. Sinh viên phải làm nhiều bước:
1. Điều tra SIEM: tìm **IP kẻ tấn công** (cá nhân hóa), **tài khoản bị chiếm**, **thời điểm**,
   **số lần thất bại trước khi thành công**.
2. Nhập đáp án (quiz): IP, user, số lần thất bại → chấm băm (mỗi sinh viên khác nhau).
3. Xử lý: chặn IP + khóa/đổi mật khẩu tài khoản bị chiếm + **gỡ persistence**
   (xóa user backdoor / SSH key lạ / cronjob).
4. Hardening: tắt `PasswordAuthentication` hoặc bật Fail2ban.
5. Kiểm chứng: SSH hợp lệ vẫn hoạt động (không khóa nhầm).

**Chấm điểm (nhiều tiêu chí):** trả lời đúng IOC · IP bị chặn · persistence đã gỡ · hardening
đã áp · dịch vụ SSH hợp lệ vẫn chạy.

## KB2 — SQL Injection → rò rỉ dữ liệu → viết WAF  [TB]

**MITRE:** T1190 Exploit Public-Facing App · T1005/T1041 Collection/Exfil

- Attacker tự động bắn payload SQLi vào web app lỗi trên target (kiểu DVWA), lấy được "secret"
  (cá nhân hóa). Sinh viên:
  1. Phân tích `access.log` qua SIEM → nhận diện **pattern SQLi**, **IP**, **endpoint/tham số**
     bị khai thác, **secret** bị lộ.
  2. Kích hoạt + viết **rule ModSecurity (WAF)** chặn SQLi.
  3. Kiểm chứng: request tấn công → **403**, nhưng traffic bình thường vẫn **200** (không chặn nhầm).
- **Chấm:** WAF chặn đúng payload · giữ request hợp lệ · trả lời đúng tham số/endpoint bị khai thác.

## KB3 — Reverse shell + persistence → threat hunting  [KHÓ]

**MITRE:** T1059 Command & Scripting · T1053.003 Cron · T1071 C2 · T1070 xóa dấu vết

- target bị "lây nhiễm sẵn": mỗi vài phút một cronjob độc hại sinh **reverse shell** về attacker.
  Sinh viên **săn mối đe dọa** qua Wazuh (FIM/giám sát tiến trình):
  1. Tìm **tiến trình lạ** + **tiến trình cha** bất thường + **cronjob/persistence** + IP C2.
  2. Trả lời: tên tiến trình/đường dẫn script độc, chu kỳ cron, IP C2.
  3. Xử lý: kill tiến trình + xóa cronjob + **vá lỗ hổng** (VD file script world-writable / sudo
     misconfig) để nó **không tái kết nối**.
  4. Kiểm chứng: sau xử lý, không còn kết nối reverse shell mới.
- **Chấm:** cron đã xóa · tiến trình hết · không còn kết nối C2 mới · trả lời đúng IOC · lỗ hổng đã vá.

## KB4 — SYN flood / DoS → rate limiting  [TB]

**MITRE:** T1498 Network Denial of Service

- Attacker `hping3` SYN flood làm cạn tài nguyên. Sinh viên: phát hiện băng thông/kết nối bất
  thường qua SIEM → áp **rate-limit** (`iptables ... -m limit` / `hashlimit`) hoặc bật
  `tcp_syncookies` (sysctl) → **giữ dịch vụ vẫn phản hồi** dưới tải.
- **Chấm:** có rule rate-limit / syncookies bật · dịch vụ vẫn phản hồi · không chặn toàn bộ.

## KB5 (Hybrid) — "Patch & Pwn"  [KHÓ, tổng hợp]

**MITRE:** kết hợp phòng thủ + tấn công có kiểm soát.

- Hệ A (của sinh viên): dịch vụ web lỗi, có agent đẩy log về SIEM. Hệ C tấn công A liên tục.
- **Giai đoạn Blue (50%):** dùng SIEM học payload mà C dùng → vá lỗi/viết WAF trên A để chặn C.
- **Giai đoạn Red (50%):** dùng chính payload học được, tinh chỉnh để khai thác Hệ B (máy lỗi
  tương tự), leo thang, lấy **flag**.
- **Chấm:** A hết bị dính (Blue) · sinh viên tạo được file flag từ B (Red).

---

## Bảng độ khó & kỹ năng

| KB | Độ khó | Kỹ năng chính | Điều tra? | Nhiều bước? | Cá nhân hóa? |
|----|--------|---------------|-----------|-------------|--------------|
| KB1 nâng cấp | Dễ→TB | Log auth, gỡ persistence, hardening | ✅ | ✅ | ✅ |
| KB2 SQLi/WAF | TB | Log web, ModSecurity | ✅ | ✅ | ✅ |
| KB3 Reverse shell | Khó | Threat hunting tiến trình/FIM | ✅✅ | ✅✅ | ✅ |
| KB4 SYN flood | TB | Phân tích mạng, rate-limit | ✅ | ✅ | một phần |
| KB5 Hybrid | Khó | Blue + Red | ✅✅ | ✅✅ | ✅ |

**Gợi ý lộ trình:** nâng cấp **KB1** trước (sửa ngay điểm "quá dễ", ít việc vì hạ tầng đã có) →
rồi **KB3** (threat hunting, khoe được sức mạnh Wazuh) → **KB2** (web/WAF) → **KB5** (hybrid, ấn tượng).

## Nguồn tham khảo

- CCDC (mô hình defend + inject + giữ dịch vụ): https://en.wikipedia.org/wiki/Collegiate_Cyber_Defense_Competition ; https://nccdc.org/files/CCDCteamprepguide.pdf
- Boss of the SOC (Splunk BOTS): https://cyberdefenders.org/blueteam-ctf-challenges/boss-of-the-soc-v1/
- OpenSOC (network defense simulation): https://opensoc.io/
- CyberDefenders (danh mục thử thách blue team): https://cyberdefenders.org/labs/
- Threat hunting với MITRE ATT&CK cho SOC: https://cyberdefenders.org/blog/mitre-attack-framework/
- SOC home lab + MITRE mapping (tham khảo kịch bản): https://github.com/akranisushant30/SOC-Home-Lab
