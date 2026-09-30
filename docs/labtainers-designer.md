# Cơ chế thiết kế lab Labtainers (cheat-sheet)

Tổng hợp từ *Labtainers Lab Designer User Guide* (nps.edu). Dùng để tra khi xây lab.

## 1. Cài công cụ thiết kế (làm 1 lần)

Bản Labtainers chuẩn KHÔNG có công cụ tạo lab. Phải cài thêm:

```bash
cd ~/labtainer/trunk/setup_scripts
./update-designer.sh
# rồi mở shell mới (hoặc logout/login) để nạp biến môi trường $LABTAINER_DIR
```

`$LABTAINER_DIR` trỏ tới `~/labtainer/trunk`.

## 2. Tạo lab mới

```bash
cd $LABTAINER_DIR/labs
mkdir <tên-lab>            # phải chữ thường, không dấu cách
cd <tên-lab>
new_lab_setup.py          # sinh template cho 1 container (tên = tên lab)
new_lab_setup.py -a <tên-container>   # thêm container
new_lab_setup.py -h       # xem trợ giúp
```

## 3. Build & test (dành cho người thiết kế, KHÁC lệnh của sinh viên)

```bash
cd $LABTAINER_DIR/scripts/labtainer-student
rebuild <tên-lab>         # xoá & dựng lại container mỗi lần (dùng khi phát triển)
rebuild -f <tên-lab>      # ép build lại khi có xoá file
tail -f labtainer.log     # xem tiến trình build ở terminal khác
stoplab <tên-lab>         # dừng, in ra đường dẫn file zip kết quả
```

> Sinh viên dùng `labtainer <tên-lab>`; người thiết kế dùng `rebuild`.

## 4. Cấu trúc thư mục một lab

```
<tên-lab>/
├── config/
│   ├── start.config        # container, mạng, IP, GRADE_CONTAINER
│   ├── parameter.config    # cá nhân hoá (RAND_REPLACE...)
│   └── about.txt           # mô tả lab (hiện khi liệt kê)
├── instr_config/
│   ├── goals.config        # tiêu chí đạt/không (ghép results)
│   └── results.config      # trích dữ liệu từ container
├── docs/
│   ├── read_first.txt      # hiện trước khi mở terminal (LAB MANUAL → link PDF)
│   └── <tên-lab>.pdf       # tài liệu hướng dẫn (viết bằng LaTeX)
└── <tên-container>/        # nội dung 1 container (mỗi container 1 thư mục)
    ├── Dockerfile...       # thêm gói phần mềm (RUN), thêm file (ADD)
    ├── _bin/
    │   ├── fixlocal.sh     # chạy LẦN ĐẦU, dưới quyền user; nhận mật khẩu qua $1
    │   ├── student_startup.sh  # chạy trong MỖI terminal ảo
    │   ├── treataslocal    # liệt kê lệnh cần ghi lại stdin/stdout để chấm
    │   └── prestop         # chạy lúc stoplab, chụp trạng thái cuối → prestop.stdout
    └── (các file đổ vào HOME của user)
```

## 5. Base image & dịch vụ

- Base `labtainer.network`: đã chạy sẵn `xinetd` (fork `sshd` theo `/etc/xinetd.d/`)
  và `rsyslog` (nên `/var/log/auth.log`, syslog hoạt động). → Rất hợp cho lab SSH.
- Xem các base có sẵn: `$LABTAINER_DIR/scripts/designer/base_dockerfiles/`.
- Thêm gói: dùng `RUN apt-get install ...` trong Dockerfile của container.
- Bật service tùy chỉnh — trong `_bin/fixlocal.sh`:
  ```bash
  echo $1 | sudo -S systemctl enable <service>.service
  echo $1 | sudo -S systemctl start  <service>.service
  ```
- Chạy lệnh mỗi lần boot: đặt trong `system/etc/rc.local`; bật bằng
  `RUN systemctl enable rc-local` trong Dockerfile.

## 6. Chấm điểm tự động

**`results.config`** — trích một dữ liệu:
```
tên = <container>:<file> : <TOÁN_TỬ> : <mẫu>
```
- File nguồn: `<lệnh>.stdout` (Labtainers tự ghi nếu lệnh có trong `treataslocal`),
  hoặc `prestop.stdout` (do script prestop tạo).
- Toán tử: `FILE_REGEX`, `CONTAINS`, `TIME_DELIM`, ...

**`goals.config`** — ghép result thành tiêu chí:
```
goal = boolean : ( a and b and_not c )
goal = time_during : X : Y
```

**Gợi ý cho sinh viên** (hiện khi `checkwork`): thêm comment ngay trên dòng result:
```
#CHECK_TRUE:  Câu hiện khi kỳ vọng TRUE mà lại sai
#CHECK_FALSE: Câu hiện khi kỳ vọng FALSE mà lại đúng
```

**`prestop`** (chụp trạng thái cuối, ví dụ để chấm rule iptables):
- Đặt tại `<container>/_bin/prestop`; stdout ghi vào `prestop.stdout.<timestamp>`.
- Timeout 30s. Nên xử lý tín hiệu SIGTERM nếu script chạy lâu.

## 7. Cá nhân hoá (chống chép bài)

`config/parameter.config`, mỗi dòng: `<id> : <thao_tác> : ...`
```
<id> : RAND_REPLACE : <file> : <symbol> : <cận_dưới> : <cận_trên>
```
Thay symbol trong file bằng giá trị ngẫu nhiên theo từng sinh viên
(chạy TRƯỚC `fixlocal.sh`).
