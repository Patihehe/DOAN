# Lộ trình đào tạo: Điều tra sự cố & Kỹ nghệ phát hiện trên SIEM (Wazuh)

> Tài liệu lộ trình chủ — nền tảng thực hành SOC trên Labtainers + Wazuh.
> Phiên bản 1.0 — 06/11/2026.

---

## 1. Đối tượng & vấn đề

**Đối tượng:** sinh viên năm cuối / người mới ra trường ngành ATTT, đã biết Linux – mạng – các loại tấn công ở mức lý thuyết, **chưa từng** làm SOC, chưa từng đụng một SIEM thật, một dòng log thật hay một hàng đợi cảnh báo thật.

**Khoảng trống thật của họ (lý do lộ trình tồn tại):**
- Biết "tấn công là gì" nhưng không biết **phát hiện tấn công đó từ log**.
- Đứng trước một cảnh báo không biết **làm gì đầu tiên**, không phân biệt được **thật / báo giả (false positive)**.
- Chưa từng **tự viết một luật phát hiện** và đo xem nó có báo rác không.
- Viết báo cáo/ghi chú sự cố chưa quen.

Đây đúng là nhóm yêu cầu trong hầu hết tin tuyển **SOC Analyst / Security Monitoring (fresher/intern)**: phân tích log, dùng SIEM, phân loại & điều tra cảnh báo, viết use-case/correlation rule.

---

## 2. Kỹ năng lõi được bảo chứng

> **Biến log thô / một cảnh báo trên SIEM thành kết luận an ninh có căn cứ — rồi tự tay viết "cái bẫy" (luật phát hiện) để hệ thống tự bắt kẻ tấn công đó ở lần sau, và tinh chỉnh để không báo rác.**

Trong ngành đây là công việc hằng ngày của **SOC Analyst (Tier 1→2)** cộng bước khởi đầu của **Detection Engineer**. Dù dạy trên Wazuh, kỹ năng chuyển thẳng sang Splunk/ELK/QRadar (khái niệm giống: index & truy vấn, decoder/parser, correlation rule, triage).

### Vòng lặp xuyên suốt mọi bài
**① Thấy** (đọc log/alert) → **② Hiểu** (điều tra, dựng timeline, phân loại thật/giả) → **③ Bắt** (viết decoder + rule) → **④ Tinh chỉnh** (giảm FP/FN, đo precision/recall)

---

## 3. Bản đồ năng lực (lộ trình phải phủ hết)

| Nhóm | Vi-kỹ năng |
|---|---|
| **A. Nền tảng – "đôi mắt"** | Dùng Wazuh (truy vấn/lọc/field/dashboard) · đọc nguồn log Linux (auth.log, sshd, apache, auditd, dns, syscheck) · hiểu pipeline `log→decoder→rule→alert` + mức độ & nhãn MITRE · baseline bình thường/bất thường |
| **B. Điều tra & Triage** | Phân loại thật/giả + mức ưu tiên theo SOP · pivot & tương quan đa nguồn · làm giàu IOC · dựng timeline + xác định phạm vi · viết báo cáo & quyết định leo thang |
| **C. Kỹ nghệ phát hiện** | Sửa rule có sẵn · viết decoder cho log lạ · viết rule 1 kỹ thuật (+gắn MITRE) · rule tương quan/tần suất · rule FIM · rule tiến trình (auditd) · tinh chỉnh đo precision/recall |
| **D. Vận hành thực chiến** | Triage dưới áp lực thời gian · điều tra end-to-end · phân tích khoảng trống phát hiện · ca trực mô phỏng |

---

## 4. Nguyên tắc sư phạm (cái tạo ra "nắm vững")

Không phải số lượng bài, mà 5 nguyên tắc sau quyết định mastery:

1. **Chia nhỏ từng vi-kỹ năng**, luyện riêng trước khi ghép.
2. **Lặp xoắn ốc:** cùng vòng `Thấy→Hiểu→Bắt→Tinh chỉnh` lặp qua nhiều họ tấn công → thành phản xạ.
3. **Tăng dần độ thật & độ nhiễu:** log sạch có hướng dẫn → hàng đợi alert lẫn báo giả → ca trực liên tục.
4. **Phản hồi tức thì:** chấm tự động nói ngay sai ở đâu.
5. **Đo chuyển giao (transfer):** bài đo đầu vào vs đầu ra chứng minh *trước không làm được, sau làm được*.

---

## 5. Cấu trúc 5 chặng

- **Chặng 0 — Nền tảng ("đôi mắt"):** làm quen SIEM, đọc log, baseline. *(Dễ)*
- **Chặng 1 — Điều tra từng kỹ thuật:** đọc & hiểu dấu vết từng họ tấn công. *(Dễ→TB)*
- **Chặng 2 — Săn tìm & Viết luật:** chủ động hunting + tự viết decoder/rule. *(TB→Khó)*
- **Chặng 3 — Quy trình SOC & Tinh chỉnh:** triage hàng đợi, đo FP/FN. *(Khó)*
- **Chặng 4 — Tổng hợp:** điều tra trọn vẹn + ca trực mô phỏng (capstone). *(Khó nhất)*

---

## 6. Danh mục bài (13 lõi ⭐ + 5 mở rộng ➕ = 18)

Ký hiệu nguồn: **[Tái dùng]** = lab đã có, bọc thêm phiếu điều tra & xếp mạch, **giữ nguyên logic chấm**. **[Mới]** = dựng mới.

| # | Chặng | Bài | Vi-kỹ năng chính | Nguồn | Lõi |
|---|---|---|---|---|---|
| 0 | Đo | Đo đầu vào (mini-triage 20') | *(đo baseline)* | [Mới] | ⭐ |
| 1 | 0 | Làm quen Wazuh | A: truy vấn/lọc/dashboard | [Mới] | ⭐ |
| 2 | 0 | Từ log → alert | A: pipeline decoder/rule, đọc log | [Mới] | ⭐ |
| 3 | 0 | Baseline & bất thường | A: phân biệt lạ/thường | [Mới] | ⭐ |
| 4 | 1 | Brute-force & duy trì | B: timeline, IOC | soc-ssh-defense [Tái dùng] | ⭐ |
| 5 | 1 | Tấn công web (SQLi) | B: đọc web log | soc-sqli-waf [Tái dùng] | ⭐ |
| 6 | 1 | Dò quét & Path traversal | B: 404/200, quét vs khai thác | soc-path-traversal [Tái dùng] | ➕ |
| 7 | 1 | Web shell → RCE | B+C: FIM, chuỗi upload→RCE | soc-webshell [Tái dùng] | ⭐ |
| 8 | 1 | Lộ .git/secrets → chiếm quyền | B: dựng lại chuỗi, xoay credential | soc-secrets-leak [Tái dùng] | ➕ |
| 9 | 1 | DDoS / SYN flood | B: nhận diện bất thường lưu lượng | soc-ddos [Tái dùng] | ➕ |
| 10 | 2 | Reverse shell & implant | C: rule tiến trình/auditd, hunting trong nhiễu | soc-threathunt [Tái dùng] | ⭐ |
| 11 | 2 | DNS exfil | C: rule tần suất/độ dài (stateful) | soc-dns-exfil [Tái dùng] | ⭐ |
| 12 | 2 | Ransomware | C: rule FIM + tiến trình | soc-ransomware [Tái dùng] | ➕ |
| 13 | 2 | Viết decoder cho log lạ | C: decoder regex cho app log chưa parse | [Mới] | ⭐ |
| 14 | 3 | Triage hàng đợi alert (lẫn false positive) | B+D: SOP, ra quyết định, nhận FP | [Mới] | ⭐ |
| 15 | 3 | Làm giàu thông tin & IOC (offline intel) | B: tra cứu nội bộ/cache, nối đa nguồn | [Mới] | ➕ |
| 16 | 3 | Tinh chỉnh phát hiện – đo FP/FN | C: precision/recall, giảm báo rác | [Mới] | ⭐ |
| 17 | 4 | Điều tra sự cố đa giai đoạn + báo cáo IR | B+C: timeline toàn cảnh, hardening | soc-privesc [Tái dùng] | ⭐ |
| 18 | 4 | Ca trực mô phỏng (capstone) | D: triage + viết rule nhanh, chấm theo chính xác+thời gian+chất lượng rule | [Mới] | ⭐ |
| 19 | Đo | Đo đầu ra (cùng dạng bài 0) | *(đo chuyển giao)* | [Mới] | ⭐ |

### Hai giai đoạn triển khai
- **Giai đoạn 1 (cam kết): 13 bài lõi ⭐ + 2 bài đo.** Đã phủ trọn bản đồ năng lực, đủ chứng minh mastery.
- **Giai đoạn 2 (nâng cấp): cắm thêm 5 bài ➕** (6, 8, 9, 12, 15) vào đúng chặng có sẵn → đủ 18. Chỉ cộng thêm, không sửa bài lõi.

---

## 7. Cách chấm & đo hiệu quả (giá trị số liệu cho đồ án)

- **Điều tra:** người học ghi IOC / timeline / kết luận vào tệp chuẩn (vd `~/dieu-tra.txt`); `prestop` đọc, grader đối chiếu. **Không lộ đáp án** qua stdout (đúng chuẩn rigor của nhóm).
- **Kỹ nghệ phát hiện:** grader **phát lại một bộ log lành + độc**, đếm rule của người học có nổ đúng không → tính **precision/recall (FP/FN)**. Đây là điểm đo khách quan mạnh nhất.
- **Số liệu chính:** Bài đo đầu vào (#0) vs Capstone/đầu ra (#18–19) cùng dạng → so **thời gian triage** + **độ chính xác phân loại** + **số tấn công phát hiện**.
- **Bổ trợ:** khảo sát tự tin 1–5 trước/sau từng vi-kỹ năng; log thời gian & số gợi ý dùng mỗi bài (biết chỗ thiết kế chưa tốt).

---

## 8. Hạ tầng cần dựng mới

1. **Bộ seed log/alert** nạp sẵn (bài 0, 1, 2, 3, 14) — người học truy vấn dữ liệu thật mà không cần chạy tấn công mỗi lần; lặp lại được.
2. **Bộ "phát lại log lành + độc"** để chấm FP/FN (bài 16, 18) — script trong container siem.
3. **Khung tài liệu chuẩn mỗi bài** (mục 9) + phiếu điều tra dùng chung cho các bài tái dùng.

---

## 9. Cấu trúc chuẩn mỗi bài

1. Bối cảnh (câu chuyện ngắn tại "Công ty X")
2. Mục tiêu học tập (vi-kỹ năng nào)
3. Kiến thức cần có trước
4. Nhiệm vụ (đánh số rõ ràng)
5. Gợi ý theo 3 cấp (cấp 1 nhẹ → cấp 3 gần như lời giải)
6. Tiêu chí hoàn thành & cách chấm
7. "Trong thực tế SOC" (liên hệ công việc thật)
8. Thời lượng ước tính
9. Giải mẫu riêng (`docs/giai-mau-<lab>.md`, chỉ để local)

---

## 10. Bối cảnh xuyên suốt

Cùng hạ tầng **Công ty X** (TMĐT vừa: web PHP/Apache + MySQL, server SSH, SOC non trẻ dùng Wazuh). Người học vào vai **analyst tập sự**. Sợi dây nối: một chiến dịch leo thang của nhóm APT giả định; mỗi bài là một giai đoạn, capstone là *phát lại cả chiến dịch* trong nhiễu.

---

## 11. Thứ tự triển khai đề xuất

1. ✅ Tài liệu lộ trình chủ (tệp này).
2. Dựng **Bài 1 – Làm quen Wazuh** làm mẫu kiến trúc (seed log + cơ chế chấm) → mô tả chi tiết để duyệt trước khi code, kèm giải mẫu local.
3. Lần lượt Bài 2 → 3 (nền tảng), rồi bọc các bài tái dùng (4,5,7,10,11,17), rồi các bài mới khó (13,14,16,18), cuối cùng 2 bài đo.
4. Mỗi bài: mô tả → duyệt → code → giải mẫu local → kiểm thử trên VM (báo trước khi cần cập nhật/rebuild VM).
