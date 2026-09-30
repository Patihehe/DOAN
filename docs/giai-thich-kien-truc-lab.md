# Giải thích kiến trúc bài lab (để hiểu & mở rộng)

Tài liệu này giải thích **cấu trúc thư mục** của một bài lab Labtainers và **vòng đời** của nó,
lấy `soc-ssh-defense` làm ví dụ. Hiểu phần này là bạn mở rộng sang lab khác dễ dàng.

## 1. Bức tranh tổng thể — 4 container

```
[attacker] --(tấn công SSH)--> [target] --(agent đẩy log)--> [siem: Wazuh]
   (ẩn)                          (nạn nhân)                      ^  |
                                    ^                            |  v (dashboard)
                                    |______(SSH khắc phục)______[defender]
                                                                 (analyst)
```
- **attacker**: chạy ngầm (`TERMINALS 0`), tự động tấn công. Sinh viên không thấy.
- **target**: máy nạn nhân, chạy dịch vụ (sshd) + `wazuh-agent` đẩy log về siem.
- **siem**: chạy Wazuh (indexer + manager + dashboard) — trung tâm phát hiện.
- **defender**: trạm analyst — Firefox xem dashboard + SSH sang target xử lý.

## 2. Cấu trúc thư mục của lab & vai trò

```
soc-ssh-defense/
├── config/          # ĐỊNH NGHĨA LAB (phần sinh viên) — "bản thiết kế"
│   ├── start.config       # container nào, mạng/IP, GRADE_CONTAINER, seed
│   ├── parameter.config   # cá nhân hóa (RAND_REPLACE) chống chép bài
│   └── about.txt          # mô tả lab (hiện khi liệt kê)
├── dockerfiles/     # CÁCH DỰNG IMAGE mỗi container
│   ├── Dockerfile.soc-ssh-defense.target.student
│   ├── Dockerfile.soc-ssh-defense.attacker.student
│   ├── Dockerfile.soc-ssh-defense.siem.student
│   └── Dockerfile.soc-ssh-defense.defender.student
├── docs/            # TÀI LIỆU cho sinh viên
│   └── read_first.txt     # hiện ra khi khởi động lab (đề bài + hướng dẫn)
├── instr_config/    # PHẦN GIẢNG VIÊN — chấm điểm (sinh viên không thấy)
│   ├── results.config     # "trích" dữ liệu từ container
│   └── goals.config       # ghép results thành tiêu chí đạt/không
├── target/          # NỘI DUNG container target (mỗi container 1 thư mục)
│   ├── _bin/              # script framework (xem mục 3)
│   └── _system/          # file đổ vào / (hệ thống) của container
├── attacker/
│   ├── _bin/fixlocal.sh   # thiết lập lần đầu
│   └── attack.sh          # (file ở gốc -> vào HOME) script tấn công
├── siem/
│   ├── _bin/{fixlocal.sh, prestop}
│   └── wazuh-setup.sh     # (HOME) script cài Wazuh offline
└── defender/
    └── _bin/student_startup.sh
```

**Ba "khu vực" chính:**
- `config/` = phần **sinh viên** thấy (định nghĩa lab).
- `instr_config/` = phần **giảng viên** (chấm điểm) — tách riêng để giấu đáp án.
- `<container>/` + `dockerfiles/` = **nội dung & cách dựng** từng máy.

## 3. Các thư mục đặc biệt của Labtainers (RẤT quan trọng khi mở rộng)

Mỗi container có 1 thư mục cùng tên. Bên trong, Labtainers hiểu các quy ước sau:

| Vị trí trong source | Vào đâu trong container | Dùng làm gì |
|---|---|---|
| `<ct>/_bin/*` | `~/.local/bin/` | Script framework đặc biệt (bên dưới) |
| `<ct>/_system/*` | `/` (thư mục hệ thống) | Đổ file cấu hình vào /etc, /usr... |
| `<ct>/<file khác>` | `~` (HOME của user) | File thường (script, dữ liệu) vào home |
| `dockerfiles/Dockerfile.<lab>.<ct>.student` | (dựng image) | Chọn base image + cài gói (RUN apt...) |

**Script đặc biệt trong `_bin/`:**
- `fixlocal.sh` — chạy **LẦN ĐẦU** khi container khởi động, dưới quyền user; `$1` = mật khẩu
  sudo. Dùng: tạo user, cấu hình, khởi động dịch vụ, launch tiến trình nền.
- `prestop` — chạy khi `checkwork`/`stoplab`; **stdout → prestop.stdout** để chấm điểm
  (ví dụ chụp `iptables -S`, đọc log).
- `student_startup.sh` — chạy trong **mỗi terminal ảo** (VD defender mở Firefox).
- `treataslocal` — liệt kê lệnh cần **ghi lại stdin/stdout** để chấm (VD `iptables`).
- (`precheck.sh` — chụp trạng thái trước khi một lệnh chạy; không dùng ở lab này.)

## 4. Vòng đời một bài lab (build → chạy → chấm)

```
1. BUILD   : rebuild đọc dockerfiles/ -> dựng image mỗi container
             (base image + cài gói + ADD _system vào /, file HOME vào ~)
2. KHỞI ĐỘNG: container chạy /sbin/init (systemd)
             -> parameter.config thay token (cá nhân hóa)
             -> _bin/fixlocal.sh chạy 1 lần (thiết lập)
             -> dịch vụ chạy (sshd, rsyslog, attack.sh, cài Wazuh...)
3. LÀM BÀI : sinh viên đọc docs/read_first.txt -> thao tác qua terminal/SSH/dashboard
4. CHẤM ĐIỂM: checkwork/stoplab
             -> _bin/prestop chạy trên các container (chụp trạng thái)
             -> framework thu artifact -> results.config TRÍCH dữ liệu
             -> goals.config ĐÁNH GIÁ đạt/không -> in Y/N
```

## 5. Luồng hoạt động của lab này (cụ thể)

1. `attacker/attack.sh` (nền, từ fixlocal) brute-force SSH vào `target`.
2. `target` chạy sshd (từ base `network.ssh`) → ghi `/var/log/auth.log`; `wazuh-agent`
   (bake trong Dockerfile) đẩy log về `siem`.
3. `siem` chạy Wazuh (cài offline ở first-boot qua `wazuh-setup.sh`) → sinh alert, dashboard.
4. `defender` mở Firefox tới dashboard (`student_startup.sh`) + SSH sang target để chặn IP.
5. Chấm: `target/_bin/prestop` chụp `iptables -S` + auth.log; `siem/_bin/prestop` chụp alert;
   `results.config` trích; `goals.config` cho Y/N.

## 6. Khi MỞ RỘNG sang lab khác — chạm vào đâu?

| Muốn đổi | Sửa ở |
|---|---|
| Cách tấn công | `attacker/attack.sh` (+ gói trong attacker Dockerfile) |
| Dịch vụ lỗ hổng trên nạn nhân | `target/` + `dockerfiles/...target...` (base image + cài gói) |
| Cách phát hiện | Rule Wazuh / thêm Snort/ModSecurity (trong target hoặc siem) |
| Tiêu chí chấm | `instr_config/results.config` + `goals.config` (+ `_bin/prestop`) |
| Cá nhân hóa | `config/parameter.config` |
| Đề bài | `docs/read_first.txt` |
| Mạng/số container | `config/start.config` |

**Giữ nguyên (dùng lại):** container `siem` (Wazuh) + `defender`, cơ chế bake, khung chấm điểm.
Xem [kien-truc-tai-su-dung.md](kien-truc-tai-su-dung.md).
