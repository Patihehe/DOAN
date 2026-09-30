# Hướng dẫn đồng bộ file: Windows (E:\THI_DOAN) → VM Linux

File được soạn trên Windows tại `E:\THI_DOAN`, nhưng Labtainers chạy trên VM
Linux. Mỗi lab phải nằm trong thư mục `labs/` của Labtainers trên VM, ví dụ:

```
~/labtainer/trunk/labs/<tên-lab>/
```

Dưới đây là 3 cách đồng bộ, chọn 1 tùy điều kiện của bạn.

---

## Cách 1 — Git (khuyến nghị: gọn, có lịch sử, dễ backup)

Trên **Windows**, khởi tạo repo và push lên GitHub/GitLab (private):

```bash
cd E:\THI_DOAN
git init
git add .
git commit -m "khoi tao du an SOC labtainers"
# tạo repo private trên GitHub rồi:
git remote add origin <URL-repo-cua-ban>
git push -u origin main
```

Trên **VM Linux**, clone/pull về rồi tạo symlink (hoặc copy) vào thư mục labs:

```bash
git clone <URL-repo-cua-ban> ~/THI_DOAN
# Trỏ lab vào Labtainers (symlink để mỗi lần sửa chỉ cần git pull):
ln -s ~/THI_DOAN/labs/soc-ssh-defense \
      ~/labtainer/trunk/labs/soc-ssh-defense
```

Mỗi lần sửa trên Windows: `git commit && git push` → trên VM: `git pull`.

---

## Cách 2 — Thư mục chia sẻ (Shared Folder) của VirtualBox/VMware

1. Trong VirtualBox: **Settings → Shared Folders**, thêm `E:\THI_DOAN`,
   bật *Auto-mount* và *Make Permanent*.
2. Trên VM (Ubuntu), thư mục thường được mount tại `/media/sf_THI_DOAN`.
   Thêm user vào nhóm để có quyền đọc:
   ```bash
   sudo usermod -aG vboxsf $USER   # cần đăng xuất/đăng nhập lại
   ```
3. Symlink hoặc copy lab vào Labtainers:
   ```bash
   cp -r /media/sf_THI_DOAN/labs/soc-ssh-defense \
         ~/labtainer/trunk/labs/
   ```

> Lưu ý: một số phiên bản Labtainers không thích symlink trỏ ra ngoài cây thư
> mục của nó. Nếu gặp lỗi build, hãy **copy** thay vì symlink.

---

## Cách 3 — scp/rsync qua mạng (nếu VM có SSH)

Từ Windows (PowerShell/Git Bash), đẩy lab sang VM:

```bash
scp -r E:/THI_DOAN/labs/soc-ssh-defense \
    user@<IP-cua-VM>:~/labtainer/trunk/labs/
```

---

## Quy trình build & test trên VM sau khi đồng bộ

```bash
cd ~/labtainer/trunk
labtainer soc-ssh-defense      # build + khởi động lab
# ... thao tác trong container ...
checkwork soc-ssh-defense      # kiểm tra điểm
stoplab soc-ssh-defense        # dừng lab
```

Khi sửa Dockerfile/cấu hình và muốn build lại sạch:

```bash
labtainer -r soc-ssh-defense   # -r = rebuild
```
