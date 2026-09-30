# Tái sử dụng kiến trúc: 1 nền tảng, nhiều kịch bản

Bài lab 1 (`soc-ssh-defense`, 4 container + Wazuh + chấm điểm + bake) **KHÔNG phải một bài
riêng lẻ** — nó là **NỀN TẢNG SOC dùng chung**. Các nhóm kịch bản khác của thầy tái sử dụng
phần lớn, chỉ thay "gói nội dung" (tấn công + dịch vụ lỗ hổng + rule phát hiện + tiêu chí chấm).

## Cái gì DÙNG CHUNG vs cái gì ĐỔI theo kịch bản

| Thành phần | Dùng chung? | Ghi chú |
|---|---|---|
| `siem` (Wazuh: indexer/manager/dashboard, bake offline) | ✅ 100% | Build 1 lần, mọi lab dùng lại image y hệt |
| `defender` (Firefox + SSH tới target) | ✅ ~100% | Chỉ đổi hướng dẫn/URL nếu cần |
| Pipeline agent (target → siem) | ✅ | Agent cài sẵn trong target |
| Khung chấm điểm (`prestop`, `results.config`, `goals.config`) | ✅ cơ chế | Chỉ viết tiêu chí mới cho từng kịch bản |
| Cá nhân hóa (`parameter.config` RAND_REPLACE) | ✅ cơ chế | Áp dụng lại cho biến của kịch bản mới |
| Bake/offline, tự vận hành | ✅ | Kế thừa nguyên |
| Topology 4 container | ✅ | Giữ nguyên |
| `attacker` — **script tấn công** | ❌ đổi | hydra/hping3/sqlmap/reverse shell... tùy kịch bản |
| `target` — **dịch vụ lỗ hổng** | ⚠️ tùy | SSH đã có; web cần thêm Apache/PHP/DB; PLC cần base khác |
| **Rule phát hiện** (Wazuh decoder/rule; +Snort/ModSecurity) | ⚠️ thêm | Cấu hình phát hiện riêng cho kịch bản |

→ **Phần nặng nhất (Wazuh + defender + chấm điểm + bake) chỉ làm 1 lần.** Kịch bản mới chỉ
tốn công ở: script tấn công + tinh chỉnh target + rule phát hiện + tiêu chí chấm.

## Ánh xạ 4 nhóm của thầy → mức tái sử dụng

| Nhóm / kịch bản | Tái sử dụng | Việc mới cần làm |
|---|---|---|
| **Nhóm 1** – KB2 SYN flood/DDoS | ~95% | attacker dùng `hping3`; chấm rate-limit (iptables/sysctl). target gần như giữ nguyên |
| **Nhóm 2** – SQLi/WAF | ~70% | Thêm **web service lỗi** vào target (Apache/PHP/DB), WAF **ModSecurity**, attacker bắn SQLi; chấm theo access.log/WAF |
| **Nhóm 2** – Path traversal/Snort | ~70% | Web service + **Snort** IDS rule; attacker `dirb`/traversal |
| **Nhóm 3** – Reverse shell/persistence | ~90% | Lây nhiễm sẵn (cron/reverse shell) + rule Wazuh FIM/process; **đã có sẵn một phần** từ KB1 (backdoor+cron) |
| **Hybrid** – Patch & Pwn | ~80% | Thêm **Hệ B** (target thứ 2) + phần red-team lấy flag |

## Cơ chế tái sử dụng có sẵn trong Labtainers

`new_lab_setup.py` hỗ trợ **clone/copy container** — dùng để đẻ lab mới từ nền tảng:
- Clone cả lab: `new_lab_setup.py -c <ten-lab-moi>` (nhân bản `soc-ssh-defense`).
- Copy 1 container từ lab khác: `new_lab_setup.py -C soc-ssh-defense siem siem`
  (mang nguyên container `siem` Wazuh sang lab mới).

Nhờ đó image `siem`/`defender` **dùng chung** giữa các lab (Docker cache lại layer, không build lại từ đầu).

## Đề xuất cấu trúc "họ lab" (lab family)

Tổ chức thành nhiều lab cùng chia sẻ nền tảng:
```
soc-ssh-defense     (KB1 - đã xong, làm BẢN MẪU)
soc-ddos            (KB2 - SYN flood)
soc-web-sqli        (KB3 - SQLi/WAF)
soc-threat-hunt     (KB - reverse shell/persistence)
soc-patch-pwn       (Hybrid)
```
Tất cả dùng chung `siem` (Wazuh) + `defender` + khung chấm điểm; chỉ khác `attacker`/`target`.

> Đây cũng là **một luận điểm mạnh cho báo cáo**: đồ án không chỉ tạo 1 bài lab, mà xây một
> **khung/nền tảng SOC tái sử dụng** để sinh ra nhiều bài lab phòng thủ có chấm điểm trên Labtainers.

## Quy trình đẻ một kịch bản mới (checklist)

1. Clone: `new_lab_setup.py -c soc-<ten>` (hoặc copy siem/defender bằng `-C`).
2. Sửa `attacker/attack.sh` — cơ chế tấn công mới.
3. Sửa/bổ sung `target` — dịch vụ lỗ hổng + rule phát hiện (Wazuh/Snort/ModSecurity).
4. Viết `instr_config/results.config` + `goals.config` — tiêu chí chấm mới.
5. `parameter.config` — cá nhân hóa biến của kịch bản.
6. `docs/read_first.txt` — kịch bản + nhiệm vụ.
7. `rebuild` + validate.
