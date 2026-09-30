# Kế hoạch phân phối lab cho nhiều sinh viên

## Nguyên tắc: sinh viên PULL image dựng sẵn, KHÔNG build

Labtainers phân phối lab qua **image Docker dựng sẵn** trên một registry (Docker Hub
hoặc registry của trường). Khi sinh viên gõ `labtainer soc-ssh-defense`, máy họ **tải
image về** rồi chạy — **không build, không tải gói Wazuh**. Việc build (tải ~1GB, tạo
cert) là **một lần của người tạo lab**.

3 giai đoạn:
| Giai đoạn | Ai | Bao lâu | Số lần |
|---|---|---|---|
| Build + publish image | Người tạo lab | Lâu | 1 lần |
| Pull image | Mỗi sinh viên | Tùy mạng | 1 lần |
| First-boot | Mỗi sinh viên | ~8-10' (offline-bake) hoặc ~2' (image cài sẵn) | 1 lần |
| Các lần sau | Sinh viên | Tức thì | Mãi |

## Cách 1 — Publish chuẩn lên registry (from-source)

1. Tạo tài khoản Docker Hub (miễn phí) hoặc dùng registry của trường.
2. Trong `config/start.config` thêm: `REGISTRY <docker-hub-id-cua-ban>`.
3. Build + push:
   ```bash
   cd $LABTAINER_DIR/distrib
   ./publish.py -l soc-ssh-defense
   ```
4. Sinh viên chạy `labtainer soc-ssh-defense` → pull image → first-boot cài offline
   (~8-10 phút, 1 lần) → chạy offline.

- Ưu: chuẩn, tái lập từ source. Nhược: sinh viên chờ ~8-10' first-boot.

## Cách 2 — Publish image ĐÃ CÀI SẴN Wazuh (first-boot ~2 phút)

Nhờ `fixlocal.sh` có guard `if [ ! -d /var/ossec ]`, nếu image đã có Wazuh cài sẵn thì
first-boot sẽ bỏ qua cài, chỉ khởi động service.

1. `rebuild soc-ssh-defense`, chạy 1 lần cho Wazuh cài xong trên siem (~8-10').
2. Chụp trạng thái đã khởi tạo:
   ```bash
   docker ps                    # tim ten container siem
   docker commit <siem-container> <docker-hub-id>/soc-ssh-defense.siem.student:<tag>
   docker push <docker-hub-id>/soc-ssh-defense.siem.student:<tag>
   ```
3. Sinh viên pull → first-boot ~2 phút (chỉ start service), offline.

- Ưu: nhanh nhất cho sinh viên. Nhược: image siem là "ảnh chụp" (source vẫn build lại
  được; ghi rõ bước này trong báo cáo).

## Cách 3 — Lớp học không có internet (phát file image)

1. `docker save` các image của lab ra file .tar:
   ```bash
   docker save -o soc-ssh-defense-images.tar <cac image cua lab>
   ```
2. Chép .tar qua USB/mạng nội bộ, sinh viên `docker load -i soc-ssh-defense-images.tar`.
3. Chạy `labtainer soc-ssh-defense` (dùng image local, không cần registry).

## Khuyến nghị

- Phân phối là **bước đóng gói cuối cùng**, làm khi nội dung lab đã hoàn chỉnh.
- Cho nhiều sinh viên + muốn nhanh: **Cách 2** (image cài sẵn) hoặc **Cách 3** (offline lớp học).
- Ghi cả 3 cách vào báo cáo như phần "Triển khai & phân phối".
