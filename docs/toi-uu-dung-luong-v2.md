# Tối ưu dung lượng nhiều lab — Phân tích phương án (bản nghiên cứu)

## Vấn đề
10 lab × ~13GB (container siem cài Wazuh runtime) ≈ 130GB → tràn đĩa khi phát triển/phát hành.

## Đã xác định (qua đọc code Labtainers + tài liệu Docker)
- **Image CÓ chia sẻ layer** giữa các lab (đo được `UNIQUE SIZE = 0B`). Vậy nếu Wazuh nằm
  trong 1 image nền dùng chung thì 10 lab chỉ tốn ~1 lần.
- `buildImage.sh`: `sys_<lab>.tar.gz` chỉ gói thư mục `_system/` (nhỏ), `<lab>.tar.gz` gói
  `.local` (nhỏ) → **không nhân đôi file Wazuh**. Có bước `RUN chown root:root /var` (Labtainers
  tự vọc quyền cho rsyslog).
- **Vướng duy nhất:** quyền `/usr/share/wazuh-*` bị đổi về `root` trong lúc build/khởi tạo
  container dẫn xuất → `wazuh-indexer` không đọc được jar → indexer chết. (Cần xác minh thêm
  `/var/lib/wazuh-indexer` có bị đổi không.)
- Chuẩn mực từ **wazuh-docker chính thức**: set quyền cho user `wazuh-indexer` **ngay trong
  image lúc build**; dữ liệu để trong **volume**; chạy service **không phải root**.

---

## Các phương án (kèm ước lượng cho 10 lab)

### A. Image nền dùng chung + chown quyền lúc RUNTIME (trong fixlocal)
- Cách: `FROM soc-wazuh` (Wazuh cài sẵn); fixlocal `chown -R wazuh-indexer /usr/share/wazuh-*`
  + restart service lúc boot.
- Dung lượng: **~45GB** (soc-wazuh ~16GB chung + mỗi lab container ~2-3GB do chown copy-up).
- First-boot: ~5 phút (chown + restart + dashboard optimize).
- Ưu: đã chứng minh CHẠY. Nhược: chown copy-up ~2GB/lab, boot chậm.

### B. Image nền dùng chung + để file Wazuh WORLD-READABLE (sửa 1 lần trong nền)
- Cách: trong `soc-wazuh`, `chmod -R o+rX /usr/share/wazuh-indexer /usr/share/wazuh-dashboard`
  (đọc được kể cả khi owner bị đổi thành root). Không chown runtime.
- Dung lượng: **~20-25GB** (chỉ soc-wazuh chung + container nhỏ ~1GB/lab).
- First-boot: ~2-3 phút (chỉ start + securityadmin).
- Ưu: rẻ (sửa 1 lần trong nền, không copy-up/lab), boot nhanh. Nhược: **CẦN xác minh
  `/var/lib/wazuh-indexer` (cần GHI) có bị đổi quyền không** — nếu có thì phải chown riêng nó
  (nhỏ hơn /usr/share). Giảm nhẹ tính "chuẩn quyền".

### C. Dùng Docker VOLUME cho dữ liệu Wazuh (như wazuh-docker chính thức)
- Cách: khai báo `VOLUME` trong `start.config` cho `/var/lib/wazuh-indexer` (+ logs) → dữ liệu
  ra volume, container writable nhỏ.
- Dung lượng: image chung + volume/lab (dữ liệu index vẫn tốn, nhưng tách khỏi container).
- Ưu: đúng chuẩn Docker/Wazuh; container gọn. Nhược: quản lý volume phức tạp hơn; vẫn tốn chỗ
  cho dữ liệu mỗi lab; cần Labtainers hỗ trợ VOLUME (có, mục 4.2 tài liệu).

### D. Giữ Wazuh tự-cài mỗi lab + DỌN container idle (không tối ưu image)
- Cách: mỗi lúc chỉ giữ 1-2 lab trên đĩa; `docker rm` lab không dùng (cài lại khi cần).
- Dung lượng: ~13GB × (số lab đang giữ) → kiểm soát được nếu kỷ luật dọn.
- Ưu: đơn giản, ổn định, không đụng cơ chế build. Nhược: chuyển lab phải cài lại (~10'), dễ quên dọn.

### E. Sửa lõi Labtainers (buildImage.sh) để không đổi quyền / chown nền 1 lần
- Cách: chèn xử lý quyền vào bước build của framework.
- Ưu: có thể sạch. Nhược: **sửa lõi framework** → ảnh hưởng mọi lab, khó bảo trì/nâng cấp, rủi ro cao. Không khuyến nghị.

### F. Dùng ảnh Wazuh chính thức làm các container RIÊNG (indexer/manager/dashboard tách)
- Cách: theo mô hình wazuh-docker thật (mỗi thành phần 1 container, ảnh dựng sẵn size-optimized).
- Ưu: "chuẩn công nghiệp", ảnh chia sẻ tốt, dữ liệu trong volume. Nhược: **mỗi lab 6-7 container**,
  tích hợp Labtainers phức tạp hơn nhiều; lệch mô hình "SOC gọn 4 container".

### G. Thu nhỏ chính Wazuh (bổ trợ, kết hợp với A/B/C)
- Cap JVM heap indexer (`-Xms512m -Xmx512m`), tắt module thừa, xoá gói/cache/log trước khi đóng gói.
- Giảm được vài GB; nên áp dụng kèm phương án chính.

---

## Bảng so sánh nhanh

| PA | 10 lab (~) | Boot | Độ khó/rủi ro | Tái lập | Ghi chú |
|----|-----------|------|---------------|---------|---------|
| A | 45GB | ~5' | Thấp (đã chạy) | Khá | Tốn ~2GB/lab do chown |
| B | 20-25GB | ~2-3' | Thấp-TB | Tốt | Cần xác minh /var/lib |
| C | image chung + volume | ~2-3' | TB | Tốt | Đúng chuẩn, quản lý volume |
| D | 13GB×(giữ) | ~10' khi bật | Rất thấp | Tốt | Đơn giản, phải dọn tay |
| E | ~20GB | ~2-3' | Cao | Kém | Sửa lõi, không khuyến nghị |
| F | ~image chung | ~2-3' | Cao | Tốt | Nhiều container/lab |

## Khuyến nghị (ưu tiên)
1. **Thử phương án B** (rẻ + nhanh nhất) — chỉ cần **xác minh 1 điểm**: `/var/lib/wazuh-indexer`
   có bị đổi quyền khi build không. Nếu không → B là lựa chọn tốt nhất. Nếu có → chown riêng
   `/var/lib` (nhỏ) hoặc lùi về A.
2. Nếu muốn chắc-chắn-chạy ngay: **phương án A** (đã kiểm chứng), chấp nhận ~45GB/~5'.
3. Kết hợp **G** (cap heap, dọn rác) với bất kỳ phương án nào.
4. Nếu ngại phức tạp giai đoạn phát triển: **D** (dọn container idle) cho tới khi đóng gói.

## Nguồn tham khảo
- Docker image layers & sharing: https://dev.to/arif_hossain/docker-image-layer-sharing-and-digest-22lh ; https://docs.docker.com/build/building/best-practices/
- Wazuh docker (single-node, volumes): https://github.com/wazuh/wazuh-docker ; https://documentation.wazuh.com/current/deployment-options/docker/
- Wazuh indexer tuning (JVM heap): https://documentation.wazuh.com/current/user-manual/wazuh-indexer/wazuh-indexer-tuning.html
- ADD/tar đổi quyền (fix `--no-same-owner`/chown): https://github.com/moby/moby/issues/1295 ; https://vsupalov.com/docker-shared-permissions/
