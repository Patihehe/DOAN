# socq — thư viện dùng chung cho các lab "hàng đợi SOC" (Bài 0 / 14 / 18 / 19)

Chỉ dùng thư viện chuẩn Python 3. Chạy trên **siem** (sinh và ghi dữ liệu). Defender không import thư viện này.

| Module | Việc |
|---|---|
| `world.py` | "Thế giới" cá nhân hóa của 1 SV: máy (mức quan trọng, IP), nhân sự `emp####`, IP kẻ tấn công / C2, domain exfil, tên webshell, tham số lệnh, máy sao lưu + cổng agent |
| `ctx.py` | Ngữ cảnh `ctx-assets` / `ctx-changes` / `ctx-hr` theo hợp đồng dữ liệu Bài 14 (mục 4.3). Cấp số ID duy nhất; **một phần mềm = một SVC** |
| `cases.py` | Mẫu ticket hàng đợi: `plan` (lúc seed, chốt đáp án V/P/E) và `render` (lúc phát, sinh ticket + bằng chứng). Bản tối thiểu cho Bài 18: T1, T5, T4, X1B1, B1, B4, F1, F2, M1 |
| `chain.py` | Chiến dịch C1–C6 trên `web-shop` + dòng log thật (webshell, bão, quét, web hợp lệ) đi qua analysisd |
| `shift.py` | Lịch ca 90' (lệch ±2', giữ thứ tự nhân quả), số INC, trạng thái ca + `shift.json` (không đáp án) |
| `ca.py` | `build(seed, t_ref)`: dựng lại **toàn bộ** ca từ seed (siem chỉ lưu seed + t_ref + T0) |
| `docs.py` | Document dạng cảnh báo Wazuh + định dạng dòng log (nginx, netfilter) đã kiểm bằng spike S-A |
| `indexer.py` | Bulk/count/tạo index/index pattern; đọc mật khẩu admin từ ảnh nền; **kiểm `errors` của bulk** |
| `test_socq.py` | Bất biến trên nhiều seed: `cd labs/_shared && python3 -m socq.test_socq 1000` |

Quy ước toàn lab (khớp sự kiện thật qua `<localfile>`): agent luôn `000/siem`; **máy của sự kiện = `predecoder.hostname`**; tên người dùng sshd ở `data.dstuser`.

Khác Bài 14 (có chủ đích, để lab đúng ở mọi giờ trong ngày): T5/B4 dùng luật "đăng nhập từ địa chỉ mới" (căn cứ LV/OC) thay vì "ngoài giờ"; bỏ F3 (logrotate 00:00); thêm M1 (beacon của agent hợp lệ, mồi gom sự cố với C4). Bài 14 khi dựng có thể thêm lại mẫu theo giờ tuyệt đối.
