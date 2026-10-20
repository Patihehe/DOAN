# Hướng dẫn tối ưu dung lượng lab (dùng chung cho nhóm)

> Mục tiêu: mỗi lab SIEM không còn tự cài Wazuh 15.9GB riêng, mà **tất cả dùng chung 1 ảnh
> `soc-wazuh`**. 5 lab chỉ tốn ~1 bản Wazuh thay vì 5×15.9GB.

## ⚠️ Nguyên tắc quan trọng nhất
- **Docker image nằm CỤC BỘ trên từng VM.** Git chỉ chia sẻ **code** (script + Dockerfile),
  **KHÔNG** chia sẻ image. → Mỗi người phải **tự dựng `soc-wazuh` một lần** trên VM của mình.
- Các script cần đã nằm trong repo, thư mục `labs/`:
  `make-soc-wazuh.sh`, `apply-shared-siem.sh`, `apply-shared-siem-all.sh`, `optimize-disk.sh`.
  (Trên VM thường được sync vào `~/` hoặc `$LABTAINER_DIR/labs/` — chạy ở đâu cũng được.)

---

## Bước 1 — Mỗi người dựng ảnh Wazuh chung (LÀM 1 LẦN trên VM của mình)
```bash
# 1. Chạy 1 lab có Wazuh đầy đủ để lấy "khuôn"
labtainer soc-ssh-defense
#    Đợi Wazuh lên (indexer active). Xem tiến độ trên siem:
#    tail -f /var/log/wazuh-install.log

# 2. Lấy mật khẩu admin (chạy TRÊN container siem)
#    sudo cat /root/wazuh-admin-credentials.txt

# 3. Dựng + đẩy ảnh chung vào registry cục bộ
bash make-soc-wazuh.sh <mat_khau_admin>
```
Xong sẽ có `soc-wazuh` + `localhost:5000/soc-wazuh` (cùng IMAGE ID) trên VM.

> **Cách thay thế (tránh cài lại Wazuh ~15')**: 1 người dựng xong rồi xuất ra file chia sẻ:
> ```bash
> docker save soc-wazuh:latest | gzip > soc-wazuh.tar.gz    # ~6GB
> ```
> Người khác nạp vào VM của mình:
> ```bash
> gunzip -c soc-wazuh.tar.gz | docker load
> docker tag soc-wazuh:latest localhost:5000/soc-wazuh:latest
> docker start registry 2>/dev/null || docker run -d -p 5000:5000 --restart=always --name registry registry:2
> docker push localhost:5000/soc-wazuh:latest
> ```
> File 6GB hơi to; thường tự dựng (Bước 1) nhanh và gọn hơn.

---

## Bước 2 — Chuyển lab "CÁCH CŨ" (siem tự cài Wazuh) sang dùng ảnh chung
Áp cho MỘT lab:
```bash
bash apply-shared-siem.sh <ten-lab>
cd $LABTAINER_DIR/scripts/labtainer-student && rebuild <ten-lab>
```
Áp cho TẤT CẢ lab có siem cùng lúc:
```bash
bash apply-shared-siem-all.sh
# rồi rebuild từng lab như hướng dẫn in ra cuối script
```

**Script làm gì & an toàn ra sao:**
- Đổi Dockerfile siem thành `FROM localhost:5000/soc-wazuh` + entrypoint khôi phục quyền Wazuh.
- **Tự lưu bản gốc `.bak`** → muốn quay lại: `mv Dockerfile....bak Dockerfile...`.
- **GIỮ nguyên** các file riêng của lab (sys.tar / home.tar / `_bin`) — chỉ thay phần CÀI Wazuh.
- ⚠️ Nếu siem cũ có bước `RUN` tùy biến ngoài việc cài Wazuh (vd baked custom rules vào image),
  hãy chuyển các bước đó vào `_bin`/`sys.tar`, hoặc thêm lại vào Dockerfile **sau** dòng
  `FROM soc-wazuh`. Luật Wazuh mà sinh viên tự viết lúc làm bài thì không bị ảnh hưởng.

---

## Bước 3 — Chuẩn cho lab MỚI (làm từ đầu)
- **Siem**: build bình thường rồi chạy `apply-shared-siem.sh <lab>`, hoặc dùng luôn template
  `FROM localhost:5000/soc-wazuh`.
- **Mọi `RUN apt-get install ...`**: thêm `&& rm -rf /var/lib/apt/lists/*` ở **cuối cùng của
  đúng RUN đó** (dọn ở RUN sau vô ích vì layer trước đã ghi rồi).
- Base nhẹ sẵn có: `network`/`network.ssh` (attacker/target), `firefox3` (defender xem dashboard).

---

## Bước 4 — Dọn ổ bất cứ lúc nào
```bash
bash optimize-disk.sh          # phần an toàn (image rác) + in ra các lệnh tùy chọn
docker container prune -f      # thu NHIỀU nhất (container đã dừng) - chỉ khi không còn lab dở
docker image prune -f          # xoá image cũ bị thay thế sau rebuild
```
Xoá ảnh nền của lab KHÁC không dùng (chỉ chạy các lab SOC):
```bash
docker rmi labtainers/labtainer.wireshark2 labtainers/labtainer.wireshark \
           labtainers/labtainer.netmon labtainers/labtainer.tap \
           labtainers/labtainer.java labtainers/labtainer.lamp \
           labtainers/labtainer.firefox labtainers/labtainer.centos
```
**GIỮ LẠI** (đang dùng): `soc-wazuh`, `localhost:5000/soc-wazuh`, `labtainer.base2`,
`labtainer.network2`, `labtainer.network.ssh2`, `labtainer.firefox3`, `labtainer.grader` (cần chấm điểm), `registry`.

> ⚠️ **TUYỆT ĐỐI KHÔNG** `docker system prune -a` hay `docker image prune -a`
> → xoá sạch toàn bộ lab, phải build lại từ đầu (cần mạng).

---

## Kiểm tra / đọc đúng con số
```bash
docker system df                 # con số THẬT (đừng cộng cột SIZE của 'docker images' - nó cộng trùng layer chung)
docker images | grep soc-wazuh   # phải thấy 2 nhãn CÙNG IMAGE ID
```
`docker system df` báo một phần lớn là "RECLAIMABLE (99%)" là **bình thường** — đó là các lab
của bạn (không có lab nào đang chạy nên Docker coi là "có thể thu hồi"). **Đừng** thu hồi chúng.

---

## Kết quả tham chiếu (máy 1 thành viên, 5 lab)
- Trước: ~102GB đã dùng / 126GB.
- Sau (share Wazuh + dọn container/image cũ + xoá base thừa): giải phóng **~53GB**, còn trống ~75GB.
- Mỗi lab mới thêm vào chỉ tốn vài trăm MB (lớp app riêng), không phải +15.9GB.

---

## ✅ Checklist LAB MỚI (tick trước khi coi là xong)

### A. Dung lượng
- [ ] Siem **KHÔNG** có bước `RUN ... wazuh-install.sh` (không re-bake Wazuh 15.9GB).
- [ ] Đã chạy `apply-shared-siem.sh <lab>` cho siem → `FROM localhost:5000/soc-wazuh`.
- [ ] Mọi `RUN apt-get install ...` có `&& rm -rf /var/lib/apt/lists/*` ở cuối **đúng RUN đó**.
- [ ] Chỉ dùng base có sẵn: `network` / `network.ssh` / `firefox3` / `base2` (không kéo base nặng mới).
- [ ] Sau khi rebuild: `docker system df` — tổng **không** phình thêm ~16GB (nếu phình → quên `apply-shared-siem`).

### B. Khớp Wazuh dùng chung (nếu sai → agent "Disconnected")
- [ ] Siem đặt IP **`172.20.0.20`** trong `start.config` (vì agent bake sẵn `WAZUH_MANAGER="172.20.0.20"`).
- [ ] Đã `apply-shared-siem.sh` (tự thêm entrypoint khôi phục quyền + dọn `rids`/`client.keys` + sudoers prestop).
- [ ] Target cài `wazuh-agent` từ repo `4.x/apt stable` (cùng dòng version với manager, hiện 4.14).

### C. Chuẩn chất lượng nhóm
- [ ] `config/*.config` và `instr_config/*.config` là **ASCII thuần** (không dấu tiếng Việt → tránh crash checkwork).
- [ ] Mọi container đặt `TZ=Asia/Ho_Chi_Minh` (chấm theo timeline thật).
- [ ] Chấm điểm: chỉ chấm việc SV làm (không auto-Y), khớp thực tế; `prestop` chỉ in cờ/OK, **không lộ đáp án**.

### D. Quy trình
- [ ] Đã **mô tả kịch bản lab** cho nhóm duyệt **trước khi** code.
- [ ] Làm xong tạo **giải mẫu** `docs/giai-mau-<lab>.md` (file này đã `gitignore` — **không commit**).
- [ ] Đã rebuild + checkwork thử end-to-end (agent Active, các mục chấm đúng kỳ vọng).
