# Khảo sát công trình liên quan (Related Work)

Khảo sát: đã có ai làm hướng "attack/defense + SIEM" cho huấn luyện SOC chưa, đặc biệt
**trên Labtainers**? Họ có kịch bản gì, có công khai không? Từ đó xác định **điểm mới**
của đồ án.

> Kết luận nhanh: mô hình SOC (automated attacker + SIEM + defender) **đã rất phổ biến**
> dưới dạng "home lab" tự dựng, NHƯNG **chưa thấy ai đưa nó vào Labtainers** với đầy đủ
> **chấm điểm tự động + cá nhân hóa + chạy trên laptop** như đồ án này. Đó là khoảng trống.

---

## Nhóm 1 — Labtainers (chính khung ta dùng) — NPS

- Labtainers (Thompson & Irvine, Naval Postgraduate School) là framework lab an ninh mạng
  dựa trên Docker, **60+ bài lab**, 9 nhóm chủ đề, **chấm điểm tự động** và **cá nhân hóa
  từng sinh viên**, chạy trên một máy Linux/laptop. Mã nguồn mở (GitHub `mfthomps/Labtainers`).
- **Labtainers ĐÃ có sẵn nhiều lab phòng thủ, nhưng đều là ĐƠN LẺ (một công cụ / một chủ đề):**
  - `snort` — IDS mạng
  - `ossec` — HIDS (host-based IDS)
  - `denyhost` — chặn brute-force SSH
  - `iptables2` — tường lửa
  - `file-integrity` — kiểm tra toàn vẹn file (AIDE)
  - `sys-log`, `centos-log` — cấu hình log hệ thống
  - `netflow`, `pcapanalysis`, `wireshark-intro`, `packet-introspection` — phân tích lưu lượng
  - `acl`, `capabilities` — kiểm soát truy cập
- **Điều Labtainers CHƯA có:** một bài lab **tích hợp SOC hoàn chỉnh** = kẻ tấn công tự
  động chạy ngầm liên tục + **SIEM tập trung (Wazuh) có dashboard** + **trạm analyst
  (defender) riêng** + phản ứng sự cố + chấm điểm hành vi phòng thủ. Các lab phòng thủ của
  Labtainers là "nguyên tử" (một tool), không ghép thành quy trình SOC. **Không có lab Wazuh.**

→ Đồ án = **lần đầu đưa mô hình SOC/SIEM tích hợp vào khung Labtainers có chấm điểm.**

## Nhóm 2 — SOC home lab mã nguồn mở dùng Wazuh (GitHub) — RẤT NHIỀU, công khai

Có hàng loạt repo công khai dựng "SOC home lab" với Wazuh + máy tấn công (thường Kali):
- `Crhernandez03/home-soc-lab` — defender + attacker (Kali) sinh traffic brute-force để phát hiện.
- `ahmed-atiah/wazuh-soc-home-lab` — phát hiện & triage brute-force RDP.
- `marxgoo/Wazuh-SOC-Lab` — Wazuh + pfSense + Suricata + Sysmon (mô phỏng SOC hiện đại).
- `jordankanda330-cmd/SOC_PENTEST_HOME_LAB` — Wazuh + SQLi + nhiều endpoint, detection engineering.
- `xuanson26/wazuh-soc-lab` — attack & defense có ánh xạ **MITRE ATT&CK**.
- `sivolko/aws-soc-lab-wazuh`, `FriikoX/SOC-Analyst-Home-Lab` (Wazuh + TheHive + Shuffle)...

**Điểm chung & khác biệt với đồ án:**
- Giống: đều là mô hình attacker → target → Wazuh SIEM → phân tích. Kịch bản phổ biến:
  **brute-force SSH/RDP**, quét cổng, SQLi, reverse shell.
- Khác (điểm yếu so với đồ án): **KHÔNG chấm điểm tự động**, không cá nhân hóa, không đóng
  gói thành bài giảng tái lập; dựng trên VM/Docker-Compose/cloud (không phải Labtainers);
  thường yêu cầu người học tự viết báo cáo tay. Tấn công hay phải kích thủ công.

## Nhóm 3 — Nền tảng blue-team thương mại (SaaS)

- **Blue Team Labs Online, CyberDefenders, Immersive Labs, Security Blue Team, HTB Blue.**
- Kịch bản DFIR/SOC rất phong phú (điều tra sự cố thật, APT, threat hunting), có chấm/điểm.
- **Nhưng:** đóng (proprietary), chạy trên cloud của họ, **không mã nguồn mở**, không tự dựng
  lại được, không dành cho "chạy trên laptop trong lớp" như Labtainers.

## Nhóm 4 — Adversary emulation / Detection engineering (mã nguồn mở)

- **Splunk Attack Range** — dựng môi trường phát hiện, dùng **Atomic Red Team / Prelude** để
  sinh dữ liệu tấn công tự động → Splunk. Công khai, mạnh, nhưng nặng (cloud AWS/Azure/GCP),
  hướng **kỹ sư phát hiện (detection engineer)**, không phải bài lab **chấm điểm phản ứng của
  sinh viên**.
- **DetectionLab** — tự dựng môi trường Active Directory + logging/security tooling. Công khai.
- **Atomic Red Team** — thư viện kỹ thuật tấn công theo MITRE ATT&CK để test phát hiện.

→ Các công cụ này lo phần "sinh tấn công + xây detection", không lo phần "khung giáo dục +
chấm điểm tự động cho người phòng thủ". Có thể **tái sử dụng ý tưởng kịch bản** từ đây.

## Nhóm 5 — Nghiên cứu học thuật

- "Automated Cyber Defence: A Review" (arXiv 2303.04926) — tổng quan tự động hóa blue team.
- "HARMer: Cyber-attacks Automation and Evaluation" (arXiv 2006.14352) — tự động hóa cả red
  lẫn blue để đánh giá.
- "Scalable and automated Evaluation of Blue Team cyber posture in Cyber Ranges" (arXiv 2312.17221).
- "A next-generation platform for Cyber Range-as-a-Service" (arXiv 2112.11233).

→ Hướng nghiên cứu về **tự động hóa & đánh giá** cyber range đang sôi động, nhưng thường là
hạ tầng lớn (cyber range), không phải lab nhẹ chấm-điểm-tự-động cho một môn học.

---

## Bảng so sánh (định vị đồ án)

| Tiêu chí | Labtainers gốc | SOC home lab (Wazuh, GitHub) | Blue-team SaaS | Attack Range/DetectionLab | **Đồ án này** |
|---|---|---|---|---|---|
| Chấm điểm tự động | ✅ | ❌ | ✅ (đóng) | ❌ | ✅ |
| Cá nhân hóa chống chép | ✅ | ❌ | một phần | ❌ | ✅ (dự kiến) |
| SIEM đầy đủ (Wazuh) | ❌ | ✅ | ✅ | ✅ (Splunk) | ✅ |
| Attacker tự động (ngầm) | ❌ | một phần | ✅ | ✅ | ✅ |
| Trạm defender riêng | ❌ | một phần | ✅ | ❌ | ✅ |
| Chạy trên laptop / tự dựng | ✅ | tùy | ❌ (cloud) | ❌ (nặng) | ✅ |
| Mã nguồn mở / tái lập | ✅ | ✅ | ❌ | ✅ | ✅ |
| Chạy offline | một phần | ❌ | ❌ | ❌ | ✅ |

## Khoảng trống nghiên cứu (điểm mới của đồ án)

Chưa thấy công trình nào **hội tụ đủ**: (1) khung giáo dục **Labtainers** (nhẹ, laptop, cá
nhân hóa, **chấm điểm tự động**) + (2) **kẻ tấn công tự động chạy ngầm** + (3) **SIEM Wazuh
đầy đủ có dashboard** + (4) **trạm defender** làm cả giám sát lẫn phản ứng (SSH khắc phục) +
(5) **chấm điểm hành vi phòng thủ** + (6) **tự vận hành, chạy offline**.

- Các SOC home lab (Nhóm 2) có SIEM nhưng **không chấm điểm/không phải khung giáo dục**.
- Labtainers (Nhóm 1) có chấm điểm nhưng **lab phòng thủ đơn lẻ, không có SIEM/SOC tích hợp**.
- Đồ án **lấp đúng khoảng giữa** hai bên.

## Gợi ý kịch bản để bổ sung (học từ các nguồn trên)

Kịch bản phổ biến trong các SOC lab khác (đồ án có thể thêm để phong phú):
- Brute-force SSH/RDP ✅ (đã có)
- Quét cổng / recon (nmap)
- SQL Injection + WAF
- Reverse shell / C2 / persistence
- Leo thang đặc quyền
- Ánh xạ **MITRE ATT&CK** cho từng kịch bản (điểm cộng học thuật, nhiều lab dùng)

## Nguồn tham khảo

- Labtainers (NPS): https://nps.edu/web/c3o/labtainers ; danh mục lab: https://nps.edu/web/c3o/labtainer-lab-summary1
- Labtainers paper (USENIX ASE17): https://www.usenix.org/system/files/conference/ase17/ase17_paper_irvine.pdf
- Labtainers (NCS 2017): https://nps.edu/documents/107523844/117286646/17NCS-Labtainers-Framework.pdf
- Crhernandez03/home-soc-lab: https://github.com/Crhernandez03/home-soc-lab
- ahmed-atiah/wazuh-soc-home-lab: https://github.com/ahmed-atiah/wazuh-soc-home-lab
- marxgoo/Wazuh-SOC-Lab: https://github.com/marxgoo/Wazuh-SOC-Lab
- xuanson26/wazuh-soc-lab (MITRE ATT&CK): https://github.com/xuanson26/wazuh-soc-lab
- jordankanda330-cmd/SOC_PENTEST_HOME_LAB: https://github.com/jordankanda330-cmd/SOC_PENTEST_HOME_LAB
- Splunk Attack Range: https://www.splunk.com/en_us/blog/security/splunk-attack-range-v5-security-lab-guide.html
- Automated Cyber Defence: A Review (arXiv): https://arxiv.org/pdf/2303.04926
- HARMer (arXiv): https://arxiv.org/pdf/2006.14352
- Blue Team cyber posture evaluation in Cyber Ranges (arXiv): https://arxiv.org/pdf/2312.17221
- CyberDefenders: https://cyberdefenders.org/blue-team-labs/
- Blue Team Labs Online: https://blueteamlabs.online/
