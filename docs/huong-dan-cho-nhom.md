# Hướng dẫn cho nhóm: dùng chung khung & tự tạo lab riêng

Tài liệu này dành cho **thành viên nhóm** muốn lấy khung SOC-lab (Labtainers) này và **tự tạo
bài lab riêng**. Khung gồm: lab mẫu `soc-ssh-defense` (4 container + Wazuh + chấm điểm) + bộ
tài liệu + script, được chia sẻ qua **Git repo chung**.

## 1. Chuẩn bị (mỗi người làm 1 lần)

- **Một máy ảo Linux có Labtainers** (xem `docs/labtainers-designer.md` để cài công cụ designer).
- Cài `git` trên máy.
- Đọc lướt 2 tài liệu nền:
  - `docs/giai-thich-kien-truc-lab.md` — vai trò từng thư mục + vòng đời lab.
  - `docs/kien-truc-tai-su-dung.md` — cái gì dùng chung, cái gì đổi theo kịch bản.

## 2. Lấy khung (clone repo chung)

```bash
git clone <URL-repo-cua-nhom> THI_DOAN
cd THI_DOAN
```
(URL do trưởng nhóm tạo — xem mục 5.)

## 3. Đưa lab mẫu sang Labtainers để chạy thử

Trên VM, đồng bộ lab mẫu vào thư mục labs của Labtainers rồi build (xem `docs/huong-dan-dong-bo.md`):
```bash
cp -r THI_DOAN/labs/soc-ssh-defense $LABTAINER_DIR/labs/
cd $LABTAINER_DIR/scripts/labtainer-student
rebuild soc-ssh-defense
```
Chạy được (checkwork ra các tiêu chí Y) = khung OK, sẵn sàng nhân bản.

## 4. Tự tạo bài lab RIÊNG của bạn (nhân từ mẫu)

```bash
cd $LABTAINER_DIR/labs/soc-ssh-defense
new_lab_setup.py -c soc-<ten-lab-cua-ban>      # clone ca 4 container + Wazuh + cham diem
cd ../soc-<ten-lab-cua-ban>
```
Rồi **chỉ sửa 4 chỗ** (theo `docs/de-xuat-kich-ban.md` + `docs/giai-thich-kien-truc-lab.md`):
1. `attacker/attack.sh` (+ Dockerfile attacker) — cách tấn công của kịch bản bạn.
2. `target/` (+ Dockerfile target) — dịch vụ lỗ hổng + rule phát hiện.
3. `instr_config/results.config` + `goals.config` — tiêu chí chấm điểm.
4. `docs/read_first.txt` — đề bài.
Giữ nguyên `siem` (Wazuh) + `defender`.

Build & test: `rebuild soc-<ten-lab-cua-ban>` → `checkwork`.

## 5. Thiết lập Git repo chung (trưởng nhóm làm 1 lần)

Trên máy có thư mục `THI_DOAN`:
```bash
cd THI_DOAN
git init
git add .
git commit -m "khung SOC-lab tren Labtainers + lab mau soc-ssh-defense"
# Tao repo PRIVATE tren GitHub/GitLab, moi 2 thanh vien lam collaborator, roi:
git remote add origin <URL-repo>
git branch -M main
git push -u origin main
```
Thành viên: `git clone <URL-repo>`. Sau này: sửa → `git add . && git commit -m "..." && git push`;
lấy bản mới: `git pull`.

## 6. Phân công & tránh đụng nhau

- **Mỗi người 1 kịch bản/lab riêng** (thư mục `labs/soc-<ten>` khác nhau) → hầu như không đụng file nhau.
- Gợi ý phân công (theo nhóm kịch bản của thầy):
  - Người A: Nhóm 1 (brute-force ✅ đã có / SYN flood).
  - Người B: Nhóm 2 (SQL Injection + WAF, path traversal).
  - Người C: Nhóm 3 (reverse shell + threat hunting) / Hybrid.
- Nếu sửa **file chung** (docs, script khung): báo nhau, hoặc mỗi người 1 nhánh (branch) rồi merge.

## 7. Lưu ý dung lượng (quan trọng)

Mỗi lab chạy Wazuh tốn ~13GB (container). Khi phát triển:
- Mỗi lúc chỉ giữ 1-2 lab; xong thì `stoplab` + `docker rm` container lab không dùng.
- Đừng để nhiều lab cùng tồn tại kẻo tràn đĩa.
- Việc **tối ưu dung lượng dùng chung Wazuh** để làm 1 lần ở khâu đóng gói cuối
  (hướng chuẩn: Docker VOLUME / ảnh wazuh chính thức — xem `docs/toi-uu-dung-luong-v2.md`).

## 8. Danh mục tài liệu trong repo (đọc khi cần)
- `giai-thich-kien-truc-lab.md` — hiểu cấu trúc & vòng đời lab.
- `kien-truc-tai-su-dung.md` — tái sử dụng khung.
- `de-xuat-kich-ban.md` — ý tưởng + cách chấm điểm cho kịch bản mới.
- `labtainers-designer.md` — cơ chế designer của Labtainers.
- `huong-dan-dong-bo.md` — đồng bộ file ↔ VM.
- `khao-sat-lien-quan.md` — công trình liên quan (cho báo cáo).
- `toi-uu-dung-luong-v2.md` — phương án tối ưu dung lượng (giai đoạn đóng gói).
