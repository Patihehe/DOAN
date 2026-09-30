# Tối ưu dung lượng cho nhiều lab (10 lab dùng chung Wazuh)

## Vấn đề
10 lab × ~13 GB = ~130 GB. Sinh viên không tải nổi.

## Nguyên nhân
13 GB là **lớp ghi (writable layer) của container `siem`** — sinh ra khi Wazuh **tự cài lúc
first-boot** (giải nén gói offline + dữ liệu OpenSearch + cache dashboard + log). Mỗi lab tự
cài → **10 bản Wazuh giống hệt bị nhân bản 10 lần**. Image thì chia sẻ layer (UNIQUE ~0), nhưng
**runtime KHÔNG chia sẻ** → phình.

## Giải pháp: 1 image Wazuh CÀI SẴN, dùng chung

Xây **một** image `soc-wazuh` (Wazuh đã cài + khởi tạo sẵn), mọi lab `FROM` nó. Docker lưu 1 lần
→ 10 lab chia sẻ. Container siem khi chạy chỉ ghi thêm chút (log/session) → nhỏ.

### Bước 1 — Dựng image Wazuh cài sẵn (làm 1 lần, phía người thiết kế)
1. Dựng + chạy 1 container siem cho Wazuh cài xong (như hiện tại).
2. **Dọn rác trong container** để giảm size trước khi chụp:
   ```bash
   # trong container siem (qua docker exec hoac SSH), quyen root:
   rm -rf /root/wz /root/wazuh-offline* /root/wazuh-install-files.tar   # goi offline da bake
   apt-get clean; rm -rf /var/lib/apt/lists/*
   # xoa log/alert tich luy (chi giu cau hinh + security index)
   find /var/ossec/logs -type f -delete 2>/dev/null
   rm -rf /var/log/wazuh-install.log /tmp/*
   ```
3. **Chụp thành image + làm phẳng (flatten) để bỏ hẳn file đã xóa:**
   ```bash
   docker commit <siem-container> soc-wazuh:staging
   docker run --name flat soc-wazuh:staging /bin/true
   docker export flat | docker import - <registry>/soc-wazuh:latest
   docker rm flat
   ```
   (export|import **gộp mọi layer thành 1**, loại bỏ file đã xóa → nhỏ đi nhiều, ~4-6GB.)
4. Đẩy lên registry của trường: `docker push <registry>/soc-wazuh:latest`.

### Bước 2 — Mọi lab dùng image chung
Trong `dockerfiles/Dockerfile.<lab>.siem.student`:
```dockerfile
ARG registry
FROM $registry/soc-wazuh          # <-- Wazuh da cai san, KHONG cai lai
# ... cac ARG chuan cua Labtainers ...
# fixlocal.sh CHI can start service (khong chay wazuh-setup.sh nua)
```
`fixlocal.sh` bỏ bước cài, chỉ đảm bảo service chạy (systemd tự start là đủ). Guard
`if [ ! -d /var/ossec ]` sẽ tự bỏ qua vì /var/ossec đã có sẵn trong image.

### Bước 3 — defender cũng dùng chung
`defender` (Firefox) giống nhau mọi lab → cũng là image chung (đã vậy: base firefox3 chia sẻ).

## Kết quả

| | Trước | Sau |
|---|---|---|
| 10 lab | ~130 GB | **~15 GB** (1 image Wazuh ~5GB + defender ~1.8GB + base ~3GB + 10 lab vài MB mỗi cái) |
| Sinh viên tải | 130 GB | pull image chung 1 lần, lab nhẹ |
| First-boot | ~8-10 phút cài | ~1-2 phút (chỉ start service) |

## Lợi ích kép cho báo cáo
- Tiết kiệm đĩa **~90%**.
- Khởi động nhanh hơn (không cài lại).
- Chạy **offline** (Wazuh đã trong image).
- Đúng triết lý Labtainers: base image dựng sẵn, tải 1 lần, dùng chung.

## Thu nhỏ thêm image Wazuh (tùy chọn)
- Cap heap OpenSearch: `-Xms512m -Xmx512m` trong `/etc/wazuh-indexer/jvm.options`.
- Hạ ngưỡng/же tắt module không dùng của Wazuh.
- Đảm bảo xóa apt cache + gói offline trước khi flatten.
