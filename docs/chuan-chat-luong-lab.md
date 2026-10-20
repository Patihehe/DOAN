# Chuẩn chất lượng lab SOC (theo mẫu NPS: acl, ossec, setuid-env)

Mục tiêu: mọi lab của nhóm đạt độ "chuyên nghiệp" như lab gốc của Labtainers —
sinh viên HIỂU vấn đề, không chỉ copy-paste vài lệnh là xong.

## A. Cấu trúc manual bắt buộc (docs/read_first.txt)

Theo thứ tự (học từ `ossec`/`setuid-env`):

1. **Tiêu đề + Overview** — giới thiệu khái niệm, VÌ SAO quan trọng (1-2 đoạn).
2. **Mục tiêu học tập (Objectives)** — gạch đầu dòng "Sau bài này, sinh viên sẽ...":
   liệt kê 4-7 năng lực cụ thể (cấu hình, phát hiện, điều tra, vá, kiểm chứng).
3. **Kiến thức nền (Background)** — giải thích CƠ CHẾ liên quan hoạt động thế nào
   (vd: Wazuh agent/decoder/rule/FIM; ModSecurity engine/rule; SUID/sudo), + link tài liệu.
4. **Môi trường & sơ đồ (Topology)** — các container, mạng, vai trò, tài khoản/mật khẩu.
5. **Nhiệm vụ (Tasks)** — nhiều task tăng dần, MỖI task gồm:
   - *Mục tiêu task* (1 câu: cần đạt điều gì).
   - *Bối cảnh / Quan sát* (yêu cầu SV xem log/trạng thái, DỰ ĐOÁN).
   - *Yêu cầu* (phải ĐẠT gì — mô tả kết quả, KHÔNG đưa sẵn câu lệnh đáp án).
   - *Gợi ý công cụ* (chỉ tên lệnh/tài liệu, vd "dùng `getfacl -h`", "xem `sudo -l`").
   - *Tự kiểm chứng* (SV tự xác nhận đã đạt).
6. **Nộp bài** — `checkwork` (tự kiểm) / `stoplab` (nộp).

### Nguyên tắc sư phạm (QUAN TRỌNG)
- **KHÔNG spoil đáp án**: không viết sẵn `sudo chmod u-s ...`. Thay bằng mục tiêu +
  gợi ý công cụ để SV tự tìm ra (giống acl: "use setfacl to allow Alice to read...").
- Bắt SV **quan sát → dự đoán → làm → kiểm chứng** ("describe your observation",
  "draw your conclusion").
- Có ít nhất 1 task **chiều sâu khái niệm** (như acl "Trojan Horse": phân biệt truy cập
  *file* vs *thông tin*).

## B. Chuẩn chấm điểm (instr_config)

Triết lý: **phải THỰC SỰ đạt yêu cầu mới "Y"**, nhiều tiêu chí, kiểm kết quả cuối.

Ba lớp tiêu chí nên có (học từ ossec + setuid-env):
1. **Phát hiện qua SIEM** — kiểm `alerts.log` chứa đúng alert/rule:
   `siem_detected = siem:/var/ossec/logs/alerts/alerts.log : CONTAINS : <chuoi/rule dac trung>`
   → chứng minh SV cấu hình/điều tra để SIEM phát hiện đúng, không chỉ chạy fix.
2. **Hành vi điều tra của SV** — kiểm `.bash_history`/stdout cho thấy SV đã điều tra:
   `did_enum = client:.bash_history : COMMAND_COUNT_REGEX : find .*-perm`
3. **Kết quả cuối (end-state)** — trạng thái bảo mật đã đạt (quyền file, rule WAF chặn,
   không còn kết nối C2...). Tổ hợp boolean: `incident_resolved = ( A and B and_not C )`.

### Toán tử results.config hay dùng (Labtainers)
| Toán tử | Ý nghĩa |
|---|---|
| `CONTAINS : <chuoi>` | file chứa chuỗi |
| `STRING_COUNT : <chuoi>` | đếm số lần xuất hiện |
| `COMMAND_COUNT : <lenh>` / `COMMAND_COUNT_REGEX : <regex>` | đếm lệnh trong `.bash_history` |
| `FILE_REGEX : <regex>` | khớp regex trong file (nhóm đang dùng) |
| `matchany` + `int_greater_than` | nhiều nguồn, so sánh số |

### Kiểu goal (goals.config)
- `boolean : (<bieu thuc>)` → Y/N (ưu tiên cho tiêu chí "đạt").
- `value : <tag>` / `count : <tag>` → báo một con số (vd số lần đăng nhập thất bại phát hiện được).
- Tổ hợp `and` / `and_not`: ĐỂ các vế dương TRƯỚC, `and_not` SAU (tránh parser lỗi).

### BẪY: prestop tích tụ nhiều bản chụp → grader đọc nhầm bản cũ
Mỗi lần `checkwork`/`stoplab`, Labtainers lưu một bản `~/.local/result/prestop.stdout.<timestamp>`.
Khi chạy checkwork nhiều lần (nhất là với lab có "sự cố xảy ra sau vài phút"), grader có thể đọc
nhầm bản chụp SỚM (trước khi sự cố/ hành động xảy ra) → chấm sai (vd backdoor có mặt nhưng vẫn báo
"đã gỡ"). KHẮC PHỤC: cho prestop TỰ DỌN các bản cũ ở đầu file, chỉ giữ bản mới nhất:
```
ls -t /home/<user>/.local/result/prestop.stdout.* 2>/dev/null | tail -n +2 | xargs -r rm -f 2>/dev/null
```
(với lab có kịch bản theo thời gian, nên cho "sự cố" xảy ra SỚM + retry để mọi bản chụp đều phản ánh đúng.)

## C. Checklist tự rà mỗi lab trước khi "đạt chuẩn"
- [ ] Manual đủ 6 mục (Overview, Objectives, Background, Topology, Tasks, Submission).
- [ ] KHÔNG còn câu lệnh đáp án copy-paste trong phần Tasks (chỉ mục tiêu + gợi ý).
- [ ] Có ≥1 task chiều sâu khái niệm.
- [ ] Chấm có đủ 3 lớp: SIEM phát hiện + hành vi điều tra + end-state.
- [ ] Mỗi tiêu chí "Y" chỉ đạt khi SV thực sự làm đúng (không pass nhờ 1 lệnh tầm thường).
- [ ] File config THUẦN ASCII (grader đọc ASCII) — xem reference-labtainers-config-ascii.
- [ ] parameter.config tồn tại (dù rỗng).

## Nguồn tham khảo (mã nguồn lab gốc NPS)
- Labtainers (mã nguồn mở, public domain): https://github.com/mfthomps/Labtainers
- Lab `ossec`, `acl`, `setuid-env`, `denyhost` trong `labs/<ten>/` (manual docs/*.pdf + instr_config/).
- Lab Designer User Guide: https://nps.edu/web/c3o/labtainers
