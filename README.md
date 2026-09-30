# Đồ án: Môi trường huấn luyện SOC thu nhỏ trên Labtainers

Nâng cấp Labtainers thành mô hình **Defender vs. Automated Attacker + SIEM** — một
Security Operations Center (SOC) thu nhỏ để huấn luyện kỹ năng phân tích log và
phản ứng sự cố (blue team).

> Thư mục này (`E:\THI_DOAN`) là **nguồn gốc (source of truth)**. File được soạn ở
> đây rồi **đồng bộ sang VM Linux** chạy Labtainers để build và chấm điểm.
> Xem [docs/huong-dan-dong-bo.md](docs/huong-dan-dong-bo.md).

## Kiến trúc mục tiêu (4 container)

| Container  | Vai trò | Ghi chú |
|------------|---------|---------|
| `attacker` | Tấn công tự động (hidden) | Chạy ngầm script/cron sinh traffic độc hại |
| `target`   | Máy nạn nhân | Chạy dịch vụ có lỗ hổng + agent đẩy log |
| `siem`     | Máy chủ SIEM | Thu thập & phân tích log, có dashboard |
| `defender` | Trạm sinh viên | Truy cập SIEM + quyền khắc phục trên target |

## Lộ trình xây dựng (tăng dần)

Mỗi bước phải **chạy được + chấm điểm được** trước khi sang bước sau.

- [x] **Bước 1 — Vòng lặp cốt lõi (2 container):** `attacker` + `target`.
      Kịch bản SSH brute-force → sinh viên chặn IP bằng iptables → Labtainers chấm
      tự động. ✅ ĐÃ CHẠY & CHẤM ĐIỂM THÀNH CÔNG (3/3 tiêu chí Y) trên VM.
- [x] **Bước 2 — Thêm SIEM (Wazuh đầy đủ):** ✅ HOÀN THÀNH & TỰ ĐỘNG HÓA.
      Wazuh (indexer+manager+dashboard) trên `siem`, wazuh-agent trên `target`,
      phát hiện brute-force, dashboard xem được. Đã BAKE: agent cài lúc build,
      Wazuh tự cài trên siem lúc first-boot → chỉ `labtainer soc-ssh-defense` là cả SOC tự lên.
- [x] **Bước 3 — Tách `defender`:** ✅ HOÀN THÀNH. Container `defender` (base firefox3)
      xem dashboard Wazuh bằng Firefox → **đủ kiến trúc 4 container chạy thật trên VM**.
- [ ] **Bước 4 — Mở rộng kịch bản:** SQLi/WAF, Path traversal/Snort,
      Reverse shell/persistence → rồi kịch bản Hybrid "Patch & Pwn".

## Danh mục kịch bản (theo gợi ý của thầy)

**Nhóm 1 — Dò quét & truy cập trái phép (mạng/hệ thống)**
1. SSH/FTP brute-force → chặn bằng iptables/Fail2ban  ✅ (lab `soc-ssh-defense`)
2. SYN flood/DDoS nhỏ → rate limiting (iptables/sysctl)  ✅ (lab `soc-ddos`, clone từ lab 1 — chứng minh tái sử dụng)

**Nhóm 2 — Ứng dụng web (L7)**
3. SQL Injection tự động → viết rule ModSecurity (WAF)
4. Quét thư mục & Path traversal → phân quyền + rule Snort (IDS)

**Nhóm 3 — Khai thác & mã độc (host-based)**
5. Persistence & reverse shell → threat hunting, kill process, xóa cronjob

**Hybrid — "Patch & Pwn"** (50% phòng thủ + 50% tấn công có kiểm soát)

## Cấu trúc thư mục

```
THI_DOAN/
├── README.md                  # File này
├── docs/                      # Tài liệu kế hoạch, hướng dẫn
├── labs/                      # Các lab Labtainers (đồng bộ sang VM)
│   └── soc-ssh-defense/       # Lab Bước 1
└── templates/                 # start.config mẫu lấy từ lab có sẵn (tham khảo)
```

## Nguyên tắc an toàn (quan trọng)

- Đây là **môi trường lab kín, tự động, phục vụ huấn luyện phòng thủ**. Các
  script "tấn công" chỉ chạy **bên trong mạng ảo của Labtainers**, không hướng
  ra ngoài Internet.
- Không đưa payload/công cụ tấn công thật ra khỏi phạm vi lab.
