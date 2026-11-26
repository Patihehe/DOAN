# Bài 18 (`soc-shift-capstone`) — ghi chú triển khai

Tài liệu đi kèm bản dựng Bài 18. Kịch bản: `docs/kich-ban-soc-shift-capstone.md`. Giải mẫu: luật mẫu sinh từ chính lab (`grade18.py mau`); đáp án phiếu theo từng SV: `grade18.py print --all` (kịch bản nhắc `docs/giai-mau-soc-shift-capstone.md` — chưa viết, local).

## 1. Những gì đã có trong bản dựng

| Phần | File | Trạng thái |
|---|---|---|
| Thư viện dùng chung | `labs/_shared/socq/` (thế giới, ngữ cảnh, mẫu ticket, chiến dịch C1–C6, lịch ca, indexer), `labs/_shared/goi-y-src/bai18.txt` | `test_socq` 1000 seed, 0 lỗi |
| siem | Dockerfile (ảnh chung + 5 unit systemd + entrypoint nhanh), `bai18/{seed18,lich-ca,grade18,reset-ca}.py`, luật sản xuất + khung, `_bin/prestop` | Chạy trên VM (ca nhanh, nhiều lần) |
| defender | Dockerfile (khóa sudo, mật khẩu dashboard từ ảnh chung), `_system/` (công cụ + watcher + thu thập), phiếu, SOP, `_bin/prestop` | Chạy trên VM |
| Chấm | `instr_config/*.config` (sinh bởi `tools/gen-grading18.py`), `tools/score-bai18.py` | `checkwork` thật: đủ goal, không lỗi grader |
| Manual | `docs/read_first.txt`, `config/about.txt` | ASCII |
| Cài đặt | `labs/install-soc-shift-capstone.sh` (sinh bằng `make-install.py`) | |

## 2. Quyết định khi dựng (khác kịch bản / lộ trình)

1. **Đồng hồ ca**: `T0` = lúc seed xong (không cần SV bấm bắt đầu). Start thường mở terminal sau ~1', seed xong sau ~5–10' → SV luôn có mặt trước `T0`. Trong lúc chờ, watcher và `trang-thai` báo tiến độ seed.
2. **Không lộ đáp án giữa ca**: siem chỉ in đáp án/tập ẩn khi `SHIFT_END=Y`; trước đó in `SHIFT_RUNNING` → `checkwork` giữa ca mọi goal N (không dùng `checkwork` để dò đáp án hay dò tập ẩn).
3. **Giá trị giữ chỗ**: Labtainers **lỗi grader** (không ra N) khi `matchany` tham chiếu result không có. Mọi trường số luôn được in: siem giữa ca `999999`, defender ô bỏ trống / slot chưa phát `999998`.
4. **Prestop ≤ 30 s**: siem in trực tiếp tối đa 20 s → không kịp thì dùng bản in sau hết ca đã lưu (`print.cache`, do `grade-bai18` lưu sau mỗi lần chấm) → không có thì giữ chỗ. Bản in chỉ được dùng khi có dòng `PRINT_DONE`. (Gặp trên VM: `mau-nap` ngay trước `checkwork` → prestop "Timed out" → grader lỗi.)
5. **Chỉ `integer_equal`**: tập số → mã `1` + mỗi số đệm 0 thành 5 chữ số; tên máy → crc32 (nhận cả tên lẫn IP thế giới). Hai phía tính giống nhau.
6. **MTTA đo trên defender** (`LAT_k` = lần đầu ghi dòng − giờ phát trong `shift.json`); giờ phát công khai nên không lộ gì.
7. **R-A "triển khai"** = lần nạp thành công đầu tiên có luật cảnh báo trong dải R-A (`rules-history`, giờ hiệu lực = max(mtime, lúc analysisd khởi động)).
8. **Khoanh vùng bão**: mốc "giảm 80%" so với `max(đỉnh đo được, 20/phút)` — SV sửa R-B ngay khi bão vừa bắt đầu không bị coi là chậm. `storm_contained` cần thêm `RB_NOT_BLIND` (làm mù luật không phải khoanh vùng).
9. **`LIVE_GAP`** = `lich-ca` khởi động lại trong [R-B, hết ca] (siem tắt giữa ca). Khi đó `score-bai18.py` tính khoanh vùng theo lần sửa R-B đầu tiên và C5 theo recall R-B tập ẩn.
10. **Entrypoint siem**: ảnh chung `chown -R` cả cây indexer/dashboard mỗi lần start (overlayfs copy-up vài GB, ~5'). Dockerfile Bài 18 ghi đè: `/usr/share/<u>` chỉ chown file sai chủ; thư mục dữ liệu vẫn `chown -R` (nếu không, `node.lock` copy-up giữa chừng → indexer chết, đã gặp).
11. **Khóa quyền**: `bai18-khoa-quyen` gỡ `ubuntu` khỏi nhóm sudo sau khi Labtainers khởi tạo xong, mỗi lần boot. `bai18-thu-thap` là lệnh root duy nhất SV gọi được (sudoers riêng).

## 3. Chạy trên VM

```bash
cd <repo>/labs
bash install-soc-shift-capstone.sh
cd $LABTAINER_DIR/scripts/labtainer-student
rebuild soc-shift-capstone        # ~20'; cần ảnh soc-wazuh ở localhost:5000
labtainer soc-shift-capstone      # siem ~5-10' để seed; ca tự bắt đầu
```

**Dung lượng**: Wazuh + bão ghi nhiều. Giữ đĩa VM trống > 15% (indexer khóa chỉ-đọc ở 95%: ticket không phát được, `trang-thai` báo "siem LOI: dia day"). Dọn: `docker image prune -f`, `docker builder prune -f`.

## 4. Chế độ phát triển (không ghi trong read_first)

| Việc | Lệnh (`S=soc-shift-capstone.siem.student`) |
|---|---|
| Ca 15' | `docker exec $S sh -c 'echo 0.1667 > /root/.bai18/scale'` rồi `reset-ca.py` |
| Bắt đầu lại ca | `docker exec $S python3 /home/ubuntu/bai18/reset-ca.py [--giu-luat]` — xóa ticket cũ (chạy nền), nạp lại luật khung, `T0` mới; defender tự làm mới (phiếu cũ → `~/.ca-cu/`) |
| Xem đáp án giữa ca | `docker exec $S python3 /home/ubuntu/bai18/grade18.py print --all` |
| Nạp giải mẫu | `docker exec $S python3 /home/ubuntu/bai18/grade18.py mau-nap` (chỉ xem: `mau`) |
| Biến thể luật T5–T10 | `tools/p7-luat.py` (xem `tools/README.md`) |

Xóa file `scale` trước khi bàn giao VM (file nằm trong container, không trong repo).

## 5. Chấm điểm

- `checkwork`: 3 cổng (`gate_no_missed_p1`, `gate_storm_not_blind`, `gate_ra_deployed`) + `bai18_gates`, thành phần từng ticket (`v_k/p_k/e_k`), SC1, leo thang, chất lượng luật, C3/C5, khoanh vùng, bàn giao, khảo sát. `#CHECK_TRUE` gợi ý không lộ đáp án.
- Điểm tổng 100 + đạt/không đạt: `python3 labs/soc-shift-capstone/tools/score-bai18.py ~/labtainer_xfer/soc-shift-capstone -v`. Đạt = 3 cổng + ≥ 60.
- Luật được chấm theo luật **đang nạp** lúc prestop. Nạp luật xong chờ 1–2' rồi mới `checkwork` (prestop nhắc khi luật vừa đổi).

## 6. Kiểm thử (P7)

| # | Cách chạy | Kết quả |
|---|---|---|
| T1–T5, T7 (mô phỏng) | `tools/test-grading18.py` (9 bài làm giả) | 9/9 |
| T2 | VM, ca nhanh, giải mẫu | `bai18_gates` Y, `c3_seen` `c5_seen` `storm_contained` Y; score 83 (ghi phiếu theo đợt → điểm thời gian thấp, đúng) |
| T5–T10 | VM, `p7-luat.py` | 7/7 (mù: level 3, xóa luật, ngưỡng ×10, loại trừ /24 → R 17%, loại trừ cổng 22 → R 67%; R-A `cmd=` → 0) |
| T11 | VM, gỡ R-A trong ca, nạp sau ca | `gate_ra_deployed` N + gợi ý R-A |
| T12 | VM, stoplab giữa bão | phát bù, không lặp, sudo vẫn khóa, `LIVE_GAP` |
| T13 / T14 | VM | sửa phiếu sau ca không đổi điểm / SV không đọc-ghi được `/var/lib/soc-shift` |
| T15 | VM, boot lạnh | `T0` sau seed |
| Giữa ca / ô trống / prestop chậm | VM | mọi goal N / `v_k` N / không lỗi grader |

Chưa làm: ca thật 90' (chỉ khác `scale`), chạy thử với người không biết đáp án (P8).

## 7. Việc còn lại / cho nhóm

- Sửa ảnh chung `soc-wazuh` (không `docker commit` lại): entrypoint như mục 2.10; ảnh đang có sẵn `did_param` từ `soc-ssh-defense` → `fixlocal.sh` / `parameter.config` của siem **không chạy** ở mọi lab dùng ảnh này.
- Pilot P8 (90', người làm thật) → chỉnh thời lượng / SOP / gợi ý.
