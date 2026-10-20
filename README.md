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
- [x] **Bước 4 — Mở rộng kịch bản:** ✅ ĐÃ CÓ **5 lab** chạy & chấm điểm được —
      `soc-ssh-defense`, `soc-sqli-waf`, `soc-threathunt`, `soc-privesc`, `soc-patch-pwn`.
- [x] **Tối ưu dung lượng:** ✅ mọi `siem` dùng chung ảnh nền `soc-wazuh` (tiết kiệm ~15.9GB/lab) —
      xem [docs/huong-dan-toi-uu-dung-luong.md](docs/huong-dan-toi-uu-dung-luong.md).

## Danh mục kịch bản (theo gợi ý của thầy)

**Nhóm 1 — Dò quét & truy cập trái phép (mạng/hệ thống)**
1. SSH brute-force → chặn bằng iptables  ✅ `soc-ssh-defense`
2. SYN flood/DDoS nhỏ → rate limiting (iptables/sysctl)  ⏳ dự kiến

**Nhóm 2 — Ứng dụng web (L7)**
3. SQL Injection tự động → viết rule ModSecurity (WAF)  ✅ `soc-sqli-waf`
4. Quét thư mục & Path traversal → phân quyền + rule Snort (IDS)  ⏳ dự kiến

**Nhóm 3 — Khai thác & mã độc (host-based)**
5. Persistence & reverse shell → threat hunting, kill process, xóa cronjob  ✅ `soc-threathunt`
6. Leo thang dac quyen → điều tra + hardening (IR)  ✅ `soc-privesc`

**Hybrid — "Patch & Pwn"** (50% phòng thủ + 50% tấn công có kiểm soát)  ✅ `soc-patch-pwn` (NoteBox: UNION SQLi + Stored XSS)

## Cấu trúc thư mục

```
THI_DOAN/
├── README.md                  # File này
├── docs/                      # Tài liệu kế hoạch, hướng dẫn, chuẩn chất lượng
├── labs/                      # Các lab Labtainers + script (đồng bộ sang VM)
│   ├── soc-ssh-defense/       # Lab 1 - SSH brute-force IR (bản mẫu)
│   ├── soc-sqli-waf/          # SQLi + WAF (ModSecurity)
│   ├── soc-threathunt/        # Reverse shell + threat hunting
│   ├── soc-privesc/           # Leo thang dac quyen + IR
│   ├── soc-patch-pwn/         # Hybrid "Patch & Pwn" (NoteBox)
│   ├── make-soc-wazuh.sh      # Dựng ảnh nền Wazuh dùng chung
│   ├── apply-shared-siem*.sh  # Chuyển siem sang ảnh chung
│   └── optimize-disk.sh       # Dọn dung lượng VM
└── templates/                 # start.config mẫu (tham khảo)
```

## Nguyên tắc an toàn (quan trọng)

- Đây là **môi trường lab kín, tự động, phục vụ huấn luyện phòng thủ**. Các
  script "tấn công" chỉ chạy **bên trong mạng ảo của Labtainers**, không hướng
  ra ngoài Internet.
- Không đưa payload/công cụ tấn công thật ra khỏi phạm vi lab.
