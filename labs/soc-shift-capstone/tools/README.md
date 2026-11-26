# Bài 18 — công cụ ngoài lab (giảng viên / phát triển)

Thư mục này **không** được chép vào container.

| File | Dùng khi nào |
|---|---|
| `gen-grading18.py` | Sinh lại `instr_config/results.config` + `goals.config` (13 ticket theo thứ tự phát). Sửa ở đây, không sửa tay file config. Sau đó sinh lại install script. |
| `score-bai18.py` | **Giảng viên**: điểm tổng 100 (kịch bản mục 9.2), 3 cổng, 3 chỉ số đồ án, cột ghi chú. `python3 score-bai18.py <thư mục .lab \| file .lab \| 2 file prestop> [--csv out.csv] [-v]`. Đọc thẳng `.lab` của `checkwork` / `gradelab`. |
| `test-grading18.py` | Kiểm config sinh ra + `score-bai18.py` trên 9 bài làm giả (mô phỏng ngữ nghĩa Labtainers, **báo lỗi khi thiếu result** như grader thật). Chạy sau mọi thay đổi phần chấm. |
| `p7-luat.py` | Chép vào siem, chạy root: chấm tập ẩn cho 7 biến thể luật (T5–T10 của lộ trình). Chỉ dùng **sau** khi ca đã hết; tự nạp lại giải mẫu. |
| `spike/` | Spike P1 (S-A/S-B/S-C) — tham khảo, không dùng khi chạy lab. |

Kiểm nhanh trước khi commit:
```bash
cd labs/_shared && python3 -m socq.test_socq 500
cd ../soc-shift-capstone && python3 tools/test-grading18.py
```
