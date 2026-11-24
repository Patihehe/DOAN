# Kịch bản lab: Bài 17 — `soc-privesc` (bản bọc) — Điều tra sự cố đa giai đoạn + báo cáo IR

> Tài liệu mô tả kịch bản để nhóm/GVHD **duyệt TRƯỚC khi code** (được commit).
> Giải mẫu: `docs/giai-mau-soc-privesc-ir.md` (chỉ để local, không commit).
> Nguồn: **[Tái dùng]** `labs/soc-privesc` trên `main` — Chặng 4, bài lõi ⭐. Bọc thêm phiếu, mở rộng chuỗi tấn công, **giữ nguyên toàn bộ logic chấm gốc** và chỉ cộng thêm.

---

## 0. Tóm tắt một trang

| Mục | Nội dung |
|---|---|
| Vị trí lộ trình | **Bài 17 — Chặng 4 (Tổng hợp)**, độ khó Khó nhất, lõi ⭐ |
| Vi-kỹ năng chính (theo lộ trình) | **B + C: timeline toàn cảnh, hardening** — dựng lại **toàn bộ** chuỗi tấn công từ trước cảnh báo đầu tiên tới sau nó; ứng phó theo vòng đời IR; **hardening** đóng cả những đường kẻ tấn công **chưa** dùng; lấp **lỗ hổng phát hiện**; viết **báo cáo IR** |
| Vòng lặp | ① Thấy (một cảnh báo root bất thường) → ② Hiểu (dựng timeline 7 giai đoạn, bản đồ phủ phát hiện) → ③ Bắt (luật cho các giai đoạn SIEM bỏ lỡ) → ④ Tinh chỉnh (hardening + kiểm chứng luật không báo giả) |
| Điểm mới so với Chặng 1–3 | Các bài trước dừng ở **một** giai đoạn (một luật, một ticket, một chiến dịch IOC). Bài 17 là **toàn bộ vòng đời** một sự cố: từ dò mật khẩu tới quay lại lấy dữ liệu, từ cách ly tới bài học rút ra. |
| Khái niệm chiều sâu | (1) **Điều tra hai chiều từ cảnh báo**: lùi về trước (cảnh báo đầu tiên hiếm khi là bước đầu tiên) và tiến về sau (kẻ tấn công đã quay lại chưa?). (2) **Gỡ bỏ ≠ hardening**: gỡ đúng thứ kẻ tấn công dùng chưa đủ; đường chưa bị dùng vẫn là đường. (3) **Phủ phát hiện**: giai đoạn nào trong timeline **không** có cảnh báo là nợ của Detection Engineering (nối Bài 16). (4) **Cách ly trước, gỡ sau** (giữ từ lab gốc). |
| Topology | Giữ 4 container của lab gốc: `target` .10, `attacker` .5 (ẩn), `siem` .20, `defender` .30. `siem` chuyển sang ảnh chung `soc-wazuh` và `TERMINALS 0` (mục 4.1). |
| Chấm | **Giữ nguyên** 8 goal gốc (IOC, timeline 3 mốc, cách ly, 2 đường leo quyền, 4 lớp persistence, foothold). **Cộng thêm:** timeline 7 mốc, MITRE từng giai đoạn, bản đồ phủ phát hiện, 3 luật lấp lỗ hổng (chấm bằng bộ phát lại của Bài 16), hardening (3 điểm yếu tiềm ẩn, trong đó có việc chặn root đăng nhập bằng SSH), dọn tạo tác, báo cáo IR (rubric GV). |
| Thời lượng | ~150 phút (có thể chia 2 buổi: buổi 1 pha ①②, buổi 2 pha ③④ + báo cáo) |

---

## 1. Lab gốc có gì và vì sao phải bọc lại

| # | Hiện trạng lab gốc | Vấn đề so với lộ trình | Xử lý trong bản bọc |
|---|---|---|---|
| G1 | Chuỗi tấn công 3 giai đoạn: đăng nhập → leo quyền (sudo awk, SUID find) → cài 4 lớp persistence | "Timeline toàn cảnh" chỉ có 3 điểm, đều nằm **sau** lúc kẻ tấn công đã có mật khẩu; không có gì **trước** (lấy mật khẩu) hay **sau** (quay lại, lấy dữ liệu) | Thêm 4 giai đoạn **bao quanh** chuỗi gốc (mục 5), không đổi 3 giai đoạn gốc |
| G2 | Gỡ đúng 2 đường leo quyền đã bị dùng | Đó là **eradication**, chưa phải **hardening** — vi-kỹ năng C của lộ trình | Cài sẵn 3 điểm yếu tiềm ẩn **chưa bị khai thác**; SV phải tìm bằng rà soát chủ động |
| G3 | Không có phần phát hiện | Chặng 4 tổng hợp nhưng bỏ trống mảng C mà Chặng 2–3 đã dạy | Bản đồ phủ phát hiện + 3 luật lấp lỗ hổng, chấm bằng `replay.py` của Bài 16 |
| G4 | `findings.txt` là phiếu IOC, không có báo cáo IR | Lộ trình ghi rõ "báo cáo IR" | Thêm `~/bao-cao-ir.md` theo khung NIST SP 800-61 rút gọn, rubric GV |
| G5 | Manual đưa sẵn nhiều lệnh (`find -perm`, quy tắc `iptables … -j DROP` ngay trong gợi ý checkwork, đường dẫn `.dbus-cache`) | Vi phạm `chuan-chat-luong-lab.md` mục A (không đưa lệnh copy-paste) | Viết lại manual: mục tiêu + gợi ý công cụ + 3 cấp gợi ý; gợi ý checkwork không lộ đường dẫn hay lệnh |
| G6 | `siem` tự cài Wazuh offline (~8–10'), `TERMINALS 1` | Chậm; SV có root trên siem sẽ đọc được tập kiểm tra ẩn của phần luật | Đổi sang ảnh chung `soc-wazuh`, `TERMINALS 0`, dùng công cụ `kiem-thu-luat` của Bài 16 trên defender |
| G7 | `/root/.soc_truth` nằm trên target, analyst có sudo đọc được | Rủi ro lộ đáp án — **đã có từ lab gốc** | Giữ nguyên (chấp nhận, ghi rõ trong mục 12); phần đáp án **mới** đặt trên siem ẩn |

**Nguyên tắc "giữ nguyên logic chấm":** toàn bộ `results.config` / `goals.config` gốc giữ tên và ý nghĩa; `target/_bin/prestop` chỉ **in thêm** dòng mới. Bài làm đạt lab gốc vẫn đạt các goal gốc trong bản bọc.

---

## 2. Bối cảnh (câu chuyện tại Công ty X)

> **Sáng thứ Hai, kết thúc chiến dịch.** Nhóm APT của chiến dịch xuyên suốt đã có chỗ đứng trong mạng Công ty X: một máy nội bộ (172.20.0.5) bị chiếm từ trước mà không sinh cảnh báo nào. Cuối tuần, từ máy đó, kẻ tấn công nhắm sang máy chủ `target`. Wazuh chỉ ghi được **một** cảnh báo đáng chú ý: *tài khoản UID 0 lạ được tạo*.
>
> *(Ghi chú cho người làm lab: bài tự sinh dữ liệu riêng, không phụ thuộc bài nào khác — kể cả các bài ➕. Câu chuyện chỉ để nối mạch; với kẻ tấn công, đây là một bước di chuyển ngang từ máy đã chiếm sang máy mới — nhưng SV chỉ điều tra phía máy đích.)*
>
> Trưởng nhóm IR giao cho bạn chủ trì vụ việc:
>
> *"Một cảnh báo chỉ là cái đuôi. Tôi cần **cả con vật**: hắn vào bằng cách nào, làm gì trước khi lên root, làm gì sau, đã quay lại chưa, đã lấy gì đi. Cách ly trước, dọn sau. Dọn xong thì đừng chỉ vá đúng lỗ hắn đã chui — kiểm tra xem còn lỗ nào hắn **chưa kịp** chui. Và cho tôi biết: những bước nào của hắn mà SIEM mình **không hề thấy**? Viết luật để lần sau thấy. Cuối cùng là báo cáo cho ban giám đốc."*

---

## 3. Mục tiêu học tập & kiến thức cần có trước

Sau bài này, người học có thể:

1. **Dựng timeline toàn cảnh 7 giai đoạn** từ nhiều nguồn (Wazuh, `auth.log`, FIM): lùi về trước cảnh báo đầu tiên và tiến về sau nó.
2. **Gán kỹ thuật MITRE ATT&CK** cho từng giai đoạn.
3. **Ứng phó theo vòng đời IR**: cách ly → gỡ bỏ → khôi phục (giữ từ lab gốc).
4. **Lập bản đồ phủ phát hiện**: giai đoạn nào có cảnh báo đủ mức để analyst chú ý, giai đoạn nào SIEM bỏ lỡ.
5. **Viết luật lấp lỗ hổng phát hiện** cho các giai đoạn bị bỏ lỡ, có kiểm chứng không báo giả (ôn Bài 16).
6. **Hardening chủ động**: rà soát và đóng các đường leo quyền/duy trì **chưa** bị khai thác; siết cấu hình đăng nhập root.
7. **Viết báo cáo IR** theo khung chuẩn: tóm tắt, timeline, phạm vi, nguyên nhân gốc, hành động, bài học.

**Ánh xạ bản đồ năng lực:**

- B — dựng timeline + xác định phạm vi ✔ (chính; ở đây là **chuỗi giai đoạn trên một máy**, không phải lan rộng theo IOC)
- B — báo cáo & quyết định ✔ (báo cáo IR)
- C — hardening ✔ (chính)
- C — viết luật + kiểm chứng FP ✔ (ôn Bài 16, quy mô nhỏ)

### Kiến thức cần có trước

| Cần | Học ở (đều là bài lõi) |
|---|---|
| Đọc `auth.log` (`Failed`/`Accepted password`, `publickey`, dòng `sudo`), dựng timeline IOC, cách ly bằng tường lửa | Bài 4 |
| FIM (syscheck): đọc sự kiện `added`/`modified`, đường dẫn bị giám sát | Bài 7 |
| Luật tần suất (`frequency`, `timeframe`, `if_matched_sid`, `same_*`/`different_*`) | Bài 11 |
| Gắn MITRE ATT&CK cho luật và giai đoạn | Bài 2, 10 |
| Precision/recall, `thu-dong`, `kiem-thu-luat`, CDB list (`match_key`, `address_match_key`, `negate`), ngoại lệ bằng luật con level 0, "chỉ lấy dòng còn hiệu lực" | Bài 16 |
| Bản ghi phê duyệt, mức tài sản, ghi chú leo thang | Bài 14 |

**Kiến thức nền mới** (manual giải thích ngắn, không đưa đáp án):

- **Vòng đời IR theo NIST SP 800-61**: chuẩn bị → phát hiện & phân tích → ngăn chặn, loại bỏ, khôi phục → hoạt động sau sự cố.
- **Leo quyền qua chương trình hợp lệ**: nhiều chương trình phổ biến (trình soạn thảo, trình xem file, ngôn ngữ kịch bản) có thể mở shell; được chạy bằng `sudo` hay mang quyền đặc biệt thì shell đó là shell root (danh mục công khai kiểu GTFOBins).
- **Linux capabilities**: cấp từng quyền root riêng lẻ cho một file thực thi — một cơ chế leo quyền ngoài bit SUID.
- **Cấu hình đăng nhập root của `sshd`** (`PermitRootLogin`) và vì sao xóa khóa thôi là chưa đủ.
- **Bản đồ phủ phát hiện**: đối chiếu từng giai đoạn của sự cố với việc SIEM có cảnh báo hay không.

---

## 4. Môi trường

### 4.1 Topology

| Container | IP | Vai trò | Thay đổi so với lab gốc |
|---|---|---|---|
| `target` | 172.20.0.10 | Máy bị xâm nhập; Wazuh agent; FIM realtime như gốc | `fixlocal.sh`: thêm 3 điểm yếu tiềm ẩn (mục 6.3), tài khoản lành cho nhiễu, khung file bài làm mới; `prestop` in thêm dòng |
| `attacker` | 172.20.0.5 | **Ẩn.** Thực hiện chuỗi 7 giai đoạn (mục 5) | `attack.sh` thêm giai đoạn 0, 2, 4, 6; `plant.sh` giữ nguyên |
| `siem` | 172.20.0.20 | Wazuh | Ảnh chung `soc-wazuh` (khởi động nhanh, mật khẩu cố định như các bài trên `main`), `TERMINALS 0`; chứa `replay.py` + tập kiểm tra ẩn của phần luật + đáp án mới |
| `defender` | 172.20.0.30 | Firefox + SSH sang target; công cụ `kiem-thu-luat`, `thu-dong` của Bài 16 | Thêm công cụ và khung bài làm |

### 4.2 Dấu hiệu bắt đầu ca

Chuỗi tấn công mất ~16–18 phút (đợt dò chậm chiếm ~5–7 phút). Bài là **điều tra sau sự cố**: SV vào ca khi chuỗi đã xong.

- Script tấn công, ở bước cuối, ghi một dòng vào `/var/run/soc-ca-truc` trên target (đọc được bởi mọi user).
- Manual: *"Khi `cat /var/run/soc-ca-truc` có nội dung, ca trực của bạn bắt đầu."*
- Thay cho câu "chờ 12–15 phút" của lab gốc → không phụ thuộc tốc độ máy.

---

## 5. Chuỗi tấn công 7 giai đoạn

Giai đoạn 1, 3, 5 là **của lab gốc, giữ nguyên**. Các giai đoạn thêm vào đều có khoảng cách ≥ 2 phút với giai đoạn kề nhau để timeline tách bạch như gốc.

| # | Giai đoạn | Kẻ tấn công làm gì | Dấu vết | MITRE (chấm số hiệu kỹ thuật chính) | Mốc trong phiếu |
|---|---|---|---|---|---|
| 0 | **Dò mật khẩu** *(mới)* | Thử 1 mật khẩu phổ biến lên `N_SPRAY` tài khoản `emp*` có thật (10–14, random), **rải chậm**: mỗi lần cách 25–35 giây (cả đợt ~5–7 phút); tài khoản bị chiếm là lần thử **cuối** và là lần duy nhất thành công (các tài khoản mồi phải tồn tại để `auth.log` ghi `Failed password` chứ không phải `Invalid user`) | `auth.log`: `Failed password` từ `.5` cho nhiều user khác nhau | T1110 (`1110`) | `TIME_SPRAY` = lần thất bại **đầu tiên** |
| 1 | **Truy cập ban đầu** *(gốc)* | Đăng nhập bằng `emp<EMPNUM>` | `Accepted password for emp… from 172.20.0.5` | T1078 (`1078`) | `TIME_ACCESS` (gốc) |
| 2 | **Trinh sát quyền** *(mới)* | Liệt kê quyền sudo của chính mình; tìm file SUID | `auth.log`: sự kiện sudo liệt kê quyền (`COMMAND=list`) | — (không chấm MITRE) | `TIME_DISCOVERY` |
| 3 | **Leo thang đặc quyền** *(gốc)* | Thoát shell qua `sudo awk`; thử cả SUID `find` | `sudo: … COMMAND=/usr/bin/awk` | T1548 (`1548`) | `TIME_ESCALATION` (gốc) |
| 4 | **Thu thập thông tin xác thực** *(mới)* | Với quyền root, chép `/etc/shadow` ra một file ẩn trong `/tmp` | FIM: file mới trong `/tmp` (đã được giám sát ở lab gốc) | T1003 (`1003`) | `TIME_CRED` |
| 5 | **Duy trì** *(gốc)* | `plant.sh`: tài khoản UID 0, SSH key cho root, bản sao bash SUID ẩn, cronjob | `new user: name=svc-…`; FIM `/etc/passwd`, `/root/.ssh`, `/usr/local/bin`, `/etc/cron.d` | T1136 (`1136`) | `TIME_PERSIST` (gốc) |
| 6 | **Quay lại & lấy dữ liệu** *(mới)* | Đăng nhập **root bằng SSH key** vừa cài, kéo file shadow đã chép về máy mình | `Accepted publickey for root from 172.20.0.5` | T1021 (`1021`) — đăng nhập dịch vụ từ xa bằng khóa đã cài (việc **cài** khóa là T1098, thuộc giai đoạn 5); lấy dữ liệu qua chính kênh SSH | `TIME_REENTRY` |
| (nền) | Cronjob mỗi 2' | như gốc | FIM/cron | T1053 | — |

**Ghi chú thiết kế:**

- **Vì sao giai đoạn 0 là dò mật khẩu "rải chậm":** luật brute-force mặc định của Wazuh cho sshd đếm số lần thất bại **từ cùng một IP** trong một cửa sổ ngắn (cỡ vài lần trong ~2 phút). Một đợt dò **nhanh** (11 lần trong 90 giây) sẽ vượt ngưỡng và bị bắt ngay. Kẻ tấn công thật né điều đó bằng cách dò chậm (*low-and-slow*): mỗi tài khoản 1 lần, các lần cách nhau đủ xa để không bao giờ chạm ngưỡng tần suất. Lỗ hổng SV phải lấp là đúng chỗ này: một luật nhìn **cửa sổ dài** và đếm **tài khoản khác nhau** từ một IP.
- **Bất biến seed:** với luật mặc định, đợt dò của mọi seed **không** sinh cảnh báo level ≥ 10. Khoảng cách giữa 2 lần thử luôn lớn hơn `timeframe / (frequency − 1)` của luật brute-force mặc định, cộng biên an toàn.
- **Vì sao giai đoạn 6 quan trọng:** nó trả lời câu hỏi IR quan trọng nhất sau "vào bằng gì" — **đã lấy gì đi**. Nó cũng là bằng chứng sống cho thấy lớp persistence SSH key đã thực sự được dùng.
- **Tiến trình lab gốc thực hiện leo quyền qua SSH của tài khoản thường**, nên giai đoạn 2 và 4 chỉ thêm 1–2 lệnh vào cùng cơ chế `run_v` sẵn có; không đổi cách lab gốc hoạt động.
- **Phạm vi:** bài **không** có di chuyển ngang (cần thêm máy đích). Kịch bản Bài 15 đã được chỉnh câu ràng buộc cho khớp (mục 15).

---

## 6. Dữ liệu và trạng thái máy cho phần mở rộng

### 6.1 Nhiễu lành trên target (để timeline không "sạch" một cách giả tạo)

| Nhiễu | Chi tiết | Vì sao cần |
|---|---|---|
| Nhân viên gõ sai mật khẩu | 3–4 `Failed password` rời rạc từ IP nội bộ khác, mỗi lần một user, rồi `Accepted` | SV phải phân biệt "gõ nhầm" với "dò mật khẩu" — cũng là nền FP cho luật số 1 |
| Quản trị viên `deploy` dùng sudo | Định kỳ `sudo systemctl restart …` (đã duyệt) | Nền FP cho luật số 2 |
| Quản trị viên tạo user thường | 1 lần `useradd` UID ≥ 1000 | Nhiễu cho timeline (không phải mọi "new user" đều là backdoor) |
| Quản trị viên đăng nhập root từ máy chủ quản trị | 1–2 lần `Accepted publickey for root` từ IP máy chủ quản trị đã duyệt | Nền FP cho luật số 3; SV phải phân biệt với giai đoạn 6 |

### 6.2 Bản đồ phủ phát hiện — sự thật

Với luật mặc định của Wazuh, mỗi giai đoạn có cảnh báo **level ≥ 10** hay không. Đây là đáp án của phần "bản đồ phủ".

> **Đáp án không viết cứng:** `siem:prestop` tính `GT_COVER_0..6` từ chính các cảnh báo mà luật **nguyên trạng** đã sinh trong cửa sổ thời gian của từng giai đoạn (mốc do attacker ghi). Lab giữ đúng ý đồ dưới đây bằng hai biện pháp: đợt dò rải chậm (giai đoạn 0) và một luật sản xuất level 12 cho tài khoản UID 0 mới (giai đoạn 5) được cài sẵn cùng bộ luật nguyên trạng.

| Giai đoạn | Ý đồ thiết kế (đáp án `COVER_*`) |
|---|---|
| 0 Dò mật khẩu | **0** — dò chậm nên không bao giờ đủ số lần thất bại trong cửa sổ của luật brute-force mặc định (đếm theo IP) → lỗ hổng mà L1 lấp |
| 1 Truy cập | **0** — đăng nhập thành công là bình thường với luật mặc định |
| 2 Trinh sát | **0** |
| 3 Leo thang | **0** — sudo thành công tới root chỉ ở mức thấp → lỗ hổng mà L2 lấp |
| 4 Thu thập | **0** — FIM file mới trong `/tmp` mức thấp |
| 5 Duy trì | **1** — tài khoản mới / thay đổi `/etc/passwd` (đây là "cảnh báo duy nhất" trong câu chuyện; bộ luật nguyên trạng có sẵn một luật sản xuất level 12 cho sự kiện này) |
| 6 Quay lại | **0** — root đăng nhập bằng key mức thấp → lỗ hổng mà L3 lấp |

→ Thông điệp: **6/7 giai đoạn không có cảnh báo đủ mức**. SV tự rút ra điều này bằng cách đối chiếu timeline với dashboard.

### 6.3 Ba điểm yếu tiềm ẩn (hardening) — **chưa** bị kẻ tấn công dùng

| # | Điểm yếu | Vì sao là đường leo quyền / duy trì | Trạng thái đạt |
|---|---|---|---|
| H1 | Một trình thông dịch có **capability** cho phép đổi UID (`cap_setuid`) | Leo root không cần SUID hay sudo — `find -perm -4000` **không** thấy | capability bị gỡ |
| H2 | User `deploy` có sudo NOPASSWD tới một **trình soạn thảo / trình xem file** có thể thoát shell (ngoài các lệnh `systemctl` đã duyệt) | Cùng loại lỗi với `sudo awk`, nhưng trên user khác | dòng sudo nguy hiểm bị gỡ; các quyền `systemctl` đã duyệt **còn nguyên** (không được xóa trắng sudo của `deploy` — đó là quyền hợp lệ) |
| H3 | `sshd` cho root đăng nhập bằng key (`PermitRootLogin prohibit-password` — mặc định) | Chính là đường giai đoạn 6 đã đi; xóa key chưa đủ nếu lần sau kẻ tấn công cài key khác | `PermitRootLogin no` và `sshd` đã nạp lại cấu hình |

Không gợi ý trực tiếp H1–H3 trong manual; manual chỉ yêu cầu **rà soát chủ động** theo một checklist khái niệm (mục 7, pha ④).

### 6.4 Ba luật lấp lỗ hổng (pha ③)

Chấm bằng `replay.py` của Bài 16, cùng quy ước đếm theo kịch bản, chỉ xét cảnh báo level ≥ 10 trong dải của từng luật. Kịch bản của L1 khai báo `window_s = 600` (đợt dò rải chậm) thay cho cửa sổ mặc định 120 giây của Bài 16; mỗi kịch bản vẫn là một phiên `wazuh-logtest` riêng.

Để L2 dùng được CDB list, lab cung cấp sẵn **decoder con** `sudo-prog` tách đường dẫn chương trình (không kèm tham số) từ dòng lệnh `sudo` vào trường `sudo.program` (vd `/usr/bin/awk BEGIN {...}` → `/usr/bin/awk`). Không có trường này thì `lookup="match_key"` trên cả dòng lệnh không bao giờ khớp.

| Luật | Dải ID | Phát hiện | Kịch bản độc (kiểm tra ẩn) | Kịch bản lành (kiểm tra ẩn) |
|---|---|---|---|---|
| **L1** Dò mật khẩu | 100270–100279 | Từ **một** IP, thất bại trên **nhiều tài khoản khác nhau** trong một **cửa sổ dài** (đợt dò rải chậm ~5–7 phút), kể cả khi mỗi tài khoản chỉ lỗi 1 lần | 4 (số tài khoản và IP thay đổi; có 1 kịch bản kết thúc bằng đăng nhập thành công) | 6 (gõ nhầm 1–3 lần trên **cùng** user; một máy chủ nhảy dùng chung với 2–3 user gõ nhầm rời rạc) |
| **L2** Sudo tới chương trình thoát được shell | 100280–100289 | `sudo` chạy chương trình thuộc danh sách có thể thoát shell (CDB list SV dựng, tra trên `sudo.program`), trừ các **cặp user–lệnh** đã duyệt. Lưu ý: chính `systemctl` cũng thoát được shell qua pager — quyền `systemctl` của `deploy` là **rủi ro được chấp nhận có ghi nhận**, không phải "an toàn". Wazuh không ghép hai trường thành một khóa CDB, nên ngoại lệ theo cặp phải là các luật con riêng (khớp cả `srcuser` lẫn `sudo.program`) | 4 (`awk`, `find`, trình soạn thảo, `less` — qua các user khác nhau; **có 1 kịch bản do chính `deploy` chạy trình soạn thảo**) | 6 (`systemctl` của `deploy`, `apt` của quản trị, …) |
| **L3** Root đăng nhập từ xa | 100290–100299 | Đăng nhập SSH **thành công của `root`** (bằng key hoặc mật khẩu) từ một IP **không** thuộc danh sách máy chủ quản trị đã duyệt (`~/admin-hosts.csv` → CDB list). Lấp đúng giai đoạn 6 | 4 (root bằng key từ máy nội bộ thường; root bằng key từ IP khác; root bằng mật khẩu; 1 kịch bản từ IP **từng** là máy quản trị nhưng nay ở trạng thái `retired` trong danh sách) | 5 (root từ máy chủ quản trị đã duyệt; user thường đăng nhập bằng key; `deploy` đăng nhập bằng key; …) |

Tất cả nguồn đều là dòng `auth.log` → phát lại được bằng `wazuh-logtest` (khác FIM, xem Bài 16 mục 13).

**Bất biến tập kiểm tra (unit test):**

- Kịch bản lành "máy chủ nhảy": trong **mọi** cửa sổ 600 giây, ≤ 3 tài khoản khác nhau thất bại từ cùng IP. Kịch bản độc: ≥ 8 tài khoản khác nhau trong cửa sổ 600 giây. Khoảng cách đủ rộng cho nhiều ngưỡng đúng.
- Kịch bản lành "gõ nhầm": ≤ 4 lần thất bại, **cùng** một tài khoản.
- L2: ≥ 1 kịch bản độc do chính user có quyền đã duyệt (`deploy`) chạy một chương trình **không** được duyệt → ngoại lệ chỉ theo user sẽ FN.
- L3: `admin-hosts.csv` có cột trạng thái; ≥ 1 kịch bản độc đến từ IP `retired` → đưa nguyên danh sách vào CDB list sẽ FN (cùng bài học "chỉ lấy dòng còn hiệu lực" của Bài 16).

**Ngưỡng:** mỗi luật **recall = 100%** (bỏ sót bất kỳ kịch bản độc nào = chưa lấp được lỗ hổng) và **≤ 1 FP**. Tập nhỏ nên ngưỡng tính theo số đếm, không theo tỉ lệ.

---

## 7. Nhiệm vụ (khung `read_first.txt` — ASCII, không spoil)

### Pha ① THẤY — Nhận vụ việc (≈10')

- Đợi dấu hiệu bắt đầu ca (mục 4.2).
- Trên dashboard: tìm cảnh báo duy nhất ở mức cao; ghi máy, giờ, chủ thể.
- **Dự đoán bắt buộc** (`~/du-doan.txt` trên defender, trước khi điều tra): `SO_GIAI_DOAN=` (bạn nghĩ chuỗi tấn công có mấy bước), `SO_CANH_BAO=` (bao nhiêu bước trong đó SIEM có cảnh báo đủ mức). Không chấm đúng sai.
- **Khảo sát trước** (`~/khao-sat.txt`, một dòng cho mỗi vi-kỹ năng chính, thang 1–5):
  - `TRUOC_B=` *"Tôi tự tin dựng lại toàn bộ chuỗi tấn công trên một máy, từ trước tới sau cảnh báo đầu tiên."*
  - `TRUOC_C=` *"Tôi tự tin tìm và đóng các đường leo quyền/duy trì mà kẻ tấn công chưa dùng."*

### Pha ② HIỂU — Cách ly, dựng timeline, gỡ bỏ (≈50')

**Task 2.1 — Cách ly** *(goal gốc `contained`)*: cắt khả năng kẻ tấn công quay lại qua mạng, **trước** khi dọn.
- *Câu hỏi chiều sâu:* *"Cách ly có làm dừng mọi thứ kẻ tấn công đã cài không? Thứ gì vẫn chạy được mà không cần mạng?"*

**Task 2.2 — Dựng timeline toàn cảnh** (`/home/analyst/findings.txt` trên target, mở rộng từ khung gốc):

```
# -- Giu nguyen tu lab goc --
COMPROMISED=  IP_KE_TAN_CONG=  VECTOR1=  VECTOR2=  BACKDOOR=
TIME_ACCESS=  TIME_ESCALATION=  TIME_PERSIST=
# -- Mo rong (HH:MM, khop gio that trong auth.log / SIEM, dung sai +-1 phut) --
TIME_SPRAY=       # lan dang nhap THAT BAI dau tien cua dot do mat khau
TIME_DISCOVERY=   # luc tai khoan bi chiem liet ke quyen sudo cua minh
TIME_CRED=        # luc file chua thong tin xac thuc bi chep ra (FIM)
TIME_REENTRY=     # luc ke tan cong QUAY LAI bang duong persistence
SO_TAI_KHOAN_BI_DO=   # so tai khoan KHAC NHAU bi thu trong dot do mat khau, TINH CA tai khoan bi chiem
# -- MITRE: ghi SO hieu ky thuat chinh (vd T1110 -> 1110) --
MITRE_SPRAY=  MITRE_ESCALATION=  MITRE_CRED=  MITRE_PERSIST=  MITRE_REENTRY=
```

- **Yêu cầu lùi về trước:** cảnh báo bạn có là giai đoạn mấy? Trước đó kẻ tấn công đã làm gì, bắt đầu từ lúc nào?
- **Yêu cầu tiến về sau:** sau khi cài persistence, kẻ tấn công đã **dùng** nó chưa? Lấy gì đi?
- *Câu hỏi chiều sâu:* *"Vì sao tài khoản `emp…` lại là tài khoản bị chiếm, trong khi hàng chục tài khoản khác bị thử cùng lúc?"*

**Task 2.3 — Gỡ bỏ** *(goal gốc: 2 đường leo quyền, 4 lớp persistence, khóa foothold)*: như lab gốc; manual chỉ nêu **loại** thứ cần tìm, không nêu đường dẫn. Thêm: dọn **mọi tạo tác** kẻ tấn công để lại, kể cả dữ liệu đã chép ra.

### Pha ③ BẮT — Bản đồ phủ và luật lấp lỗ hổng (≈35')

**Task 3.1 — Bản đồ phủ** (khối `COVER_*` cuối `/home/analyst/findings.txt` trên target): với mỗi giai đoạn 0–6, Wazuh (luật **nguyên trạng**, trước khi bạn sửa gì) có cảnh báo **level ≥ 10** không?

```
COVER_0=  COVER_1=  COVER_2=  COVER_3=  COVER_4=  COVER_5=  COVER_6=     # 1 = co, 0 = khong
```

**Task 3.2 — Viết 3 luật** L1, L2, L3 (mục 6.4) trong `~/luat/`, kiểm thử bằng `sudo kiem-thu-luat` (tập phát triển nhỏ có nhãn trong `~/dev/`).
- Ràng buộc: dải ID cố định; level ≥ 10; có `<mitre>`; L2 dùng **CDB list** các chương trình có thể thoát shell; ngoại lệ lấy từ danh sách cặp user–lệnh đã duyệt `~/sudo-da-duyet.csv`; L3 lấy ngoại lệ từ `~/admin-hosts.csv` (chỉ dòng còn hiệu lực).
- *Câu hỏi chiều sâu:* *"Luật L1 của bạn có phân biệt được 'một người gõ nhầm 3 lần' với 'một IP thử 12 tài khoản, mỗi tài khoản 1 lần' không? Trường nào làm nên khác biệt?"*

### Pha ④ TINH CHỈNH — Hardening (≈25')

- **Mục tiêu:** đóng các đường kẻ tấn công **chưa kịp** dùng.
- **Checklist rà soát chủ động** (manual chỉ đưa checklist, không đưa đáp án):
  - Mọi cách một chương trình có thể chạy với quyền cao hơn người gọi — **không chỉ** bit SUID.
  - Mọi quy tắc sudo của **mọi** user, đối chiếu với `~/sudo-da-duyet.csv`.
  - Cấu hình đăng nhập từ xa của tài khoản đặc quyền.
- **Ràng buộc:** không phá quyền hợp lệ (quyền sudo đã duyệt của `deploy` phải còn), và không khóa chính bạn khỏi máy.
- **Tự kiểm chứng:** với mỗi thay đổi, ghi một dòng vào `~/hardening.txt`: điểm yếu — vì sao nguy hiểm — đã làm gì — kiểm chứng thế nào.

### Báo cáo IR (≈20')

`~/bao-cao-ir.md` (khung có sẵn, chấm tay theo rubric 9.5):

```
1. Tom tat cho ban giam doc (5 cau, khong thuat ngu)
2. Timeline (bang 7 giai doan: gio - giai doan - bang chung - MITRE)
3. Pham vi & tac dong (du lieu nao bi lay, tai khoan nao bi anh huong)
4. Nguyen nhan goc (vi sao ke tan cong vao duoc va len root duoc)
5. Hanh dong da lam (cach ly - go bo - hardening - luat moi)
6. Bai hoc & khuyen nghi (ky thuat + quy trinh)
```

### Phản tư & kết thúc (≈5')

`~/phan-tu.txt`: so `du-doan.txt` với timeline và bản đồ phủ thật. Điền `SAU_B=`, `SAU_C=` trong `~/khao-sat.txt` (cùng câu hỏi). → `checkwork` → `stoplab`.

---

## 8. Gợi ý theo 3 cấp

Như các bài 14–18: cấp 1 nằm trong `read_first.txt`; cấp 2 và 3 chỉ mở bằng lệnh `goi-y <pha> <cap>` trên defender (công cụ dùng chung, ghi nhật ký pha, cấp, thời điểm). Gợi ý không trừ điểm; số lần mở là số liệu đồ án.

**Cấp 1 — định hướng**

- Cảnh báo bạn có là **cái đuôi**. Hỏi hai câu: *"Ngay trước đó là gì?"* và *"Ngay sau đó là gì?"* — rồi hỏi lại với câu trả lời.
- Kẻ tấn công lấy được mật khẩu bằng cách nào đó trước khi đăng nhập thành công.
- Cài cửa sau rồi thì sẽ dùng. Có dấu hiệu nào cho thấy cửa sau **đã** được dùng?
- Vá đúng lỗ đã bị chui là gỡ bỏ. Hardening là tìm những lỗ **cùng loại** chưa bị chui.

**Cấp 2 — chỉ chỗ**

- **Trước truy cập:** lọc `auth.log` / dashboard theo IP kẻ tấn công, **bỏ** điều kiện "thành công"; đếm số user **khác nhau**.
- **Trinh sát:** sudo ghi cả lần người dùng **liệt kê** quyền, không chỉ lần chạy lệnh.
- **Thu thập:** FIM giám sát `/tmp`; tìm file mới xuất hiện **giữa** leo quyền và cài persistence.
- **Quay lại:** đăng nhập thành công của **root** từ IP kẻ tấn công, phương thức **không** phải mật khẩu.
- **Bản đồ phủ:** lọc `rule.level >= 10` trong cửa sổ của từng giai đoạn.
- **Hardening:** ngoài bit SUID, Linux còn một cơ chế cấp quyền theo từng khả năng cho file thực thi. Quy tắc sudo nằm ở nhiều file. `sshd` có một tùy chọn riêng cho root.

**Cấp 3 — gần như lời giải**

- **Timeline** (đều từ `auth.log` trừ `TIME_CRED` lấy từ FIM):
  - `TIME_SPRAY` = `Failed password` đầu tiên từ `.5`;
  - `TIME_DISCOVERY` = dòng sudo của tài khoản bị chiếm có `COMMAND=list`;
  - `TIME_CRED` = FIM `added` trong `/tmp` (file ẩn, nội dung giống `/etc/shadow`);
  - `TIME_REENTRY` = `Accepted publickey for root from 172.20.0.5`.
- **MITRE:** 1110, 1548, 1003, 1136, 1021.
- **Bản đồ phủ:** chỉ giai đoạn 5 có cảnh báo ≥ 10.
- **L1:** `frequency` ≥ 5, `timeframe` ≥ 600 (đợt dò kéo dài vài phút), `same_srcip` + `different_user` trên luật nền "đăng nhập thất bại" (sshd đặt tên tài khoản vào `dstuser`, nên `different_srcuser` không đếm được). Lưu ý: bộ phát lại gửi cả kịch bản (cửa sổ 600 giây) gần như cùng lúc trong một phiên (Bài 16 mục 4.4), nên `timeframe` dài không làm chậm việc chấm.
- **L2:** con của **cả hai** luật sudo thành công ("sudo tới root" và "lần đầu user chạy sudo" — hai luật anh em, không lồng nhau) + CDB list trên trường `sudo.program` (level 12); **mỗi cặp user–lệnh đã duyệt** là một luật con level 0 của L2, khớp **đồng thời** tên user trên dòng log và `sudo.program` (một luật chỉ khớp user sẽ bỏ qua mọi lệnh nguy hiểm khác của user đó — tập kiểm tra có đúng kịch bản này).
- **L3:** con của luật "đăng nhập SSH thành công" với `dstuser` = `root`; CDB list IP máy chủ quản trị (chỉ dòng `approved`) tra theo kiểu "không có trong list" trên `srcip`.
- **Hardening:** liệt kê capability của file thực thi và gỡ capability đổi UID; gỡ riêng dòng sudo tới trình soạn thảo của `deploy`; đặt `PermitRootLogin no` rồi nạp lại `sshd` (L3 phát hiện, H3 ngăn chặn — hai lớp cho cùng một đường).
- **Dọn tạo tác:** xóa bản chép của file shadow trong `/tmp`.

---

## 9. Tiêu chí hoàn thành & cách chấm

### 9.1 Ánh xạ 3 lớp chất lượng

| Lớp chuẩn | Hiện thực |
|---|---|
| SIEM phát hiện | 3 luật lấp lỗ hổng, chấm trên tập kiểm tra ẩn bằng `replay.py` |
| Hành vi điều tra | Timeline 7 mốc khớp giờ thật ±1'; MITRE; bản đồ phủ; IOC (gốc) |
| End-state | Cách ly + gỡ bỏ (gốc) + dọn tạo tác + hardening 3 điểm |

### 9.2 Goal gốc — **giữ nguyên**

`reported_iocs`, `timeline_reconstructed` (3 mốc), `contained`, `suid_fixed`, `sudo_fixed`, `persistence_removed`, `foothold_locked`, `incident_resolved`. `target/_bin/prestop` gốc không bị sửa dòng nào; phần mới chỉ **nối thêm** vào cuối.

### 9.3 Goal mới

| Goal | Nguồn | Đạt khi | Bắt buộc? |
|---|---|---|---|
| `timeline_full` | target prestop | ≥ 6/7 mốc (3 gốc + 4 mới) khớp giờ thật ±1', và các mốc đã điền **đúng thứ tự** | ✔ |
| `spray_scope` | target prestop | `SO_TAI_KHOAN_BI_DO` đúng | ✔ |
| `mitre_ok` | target prestop | ≥ 4/5 số hiệu MITRE đúng | ✔ |
| `coverage_ok` | target prestop (so ý đồ thiết kế) ∧ siem xác nhận môi trường thật khớp thiết kế (`COVER_DESIGN_OK`) | ≥ 6/7 `COVER_*` đúng | ✔ |
| `rule_l1_ok`, `rule_l2_ok`, `rule_l3_ok` | siem prestop (`replay.py --mode grade`) | recall 100% và ≤ 1 FP trên tập kiểm tra ẩn | ✔ |
| `hardening_ok` | target prestop | H1, H2, H3 đều đạt (mục 6.3) **và** quyền sudo đã duyệt của `deploy` còn nguyên | ✔ |
| `artifact_removed` | target prestop | bản chép file shadow trong `/tmp` (tên random, GT trong `/root/.soc_truth`) đã bị xóa | ✔ |
| **`bai17_pass`** | — | `incident_resolved` (gốc) ∧ `reported_iocs` (gốc) ∧ mọi goal mới ở trên (gồm `artifact_removed`) | **Đạt bài** |
| `pred_*`, số lần `kiem-thu-luat`, `HARDEN_*` từng điểm | — | — | số liệu |

**Vì sao như vậy:**

- `timeline_full` cho phép trượt 1/7 mốc: 7 mốc khớp ±1' là đòi hỏi cao. Mốc sai thường là dấu hiệu nhầm sự kiện, không phải lười.
- Luật lấp lỗ hổng đòi **recall 100%**: một luật "lấp lỗ" mà vẫn bỏ sót kịch bản độc thì lỗ vẫn còn.
- `hardening_ok` có **điều kiện không phá quyền hợp lệ**: hardening làm hỏng vận hành cũng là thất bại.

### 9.4 Dữ liệu chấm mới

- **`target:prestop`** (nối thêm vào cuối bản gốc):
  - GT bổ sung trong `/root/.soc_truth`: `CRED_TIME`, `CRED_FILE`, `N_SPRAY` — attacker ghi khi thực hiện. Các mốc còn lại lấy từ `auth.log` như cách lab gốc làm.
  - In `TIME_SPRAY_OK`, `TIME_DISC_OK`, `TIME_CRED_OK`, `TIME_REENTRY_OK`, `TIMELINE_FULL_OK`, `SPRAY_N_OK`, `MITRE_<x>_OK`, `HARDEN_CAP_OK`, `HARDEN_SUDO_OK`, `HARDEN_SSH_OK`, `DEPLOY_SUDO_INTACT`, `SHADOW_COPY_PRESENT`.
  - Giữ nguyên nguyên tắc gốc: chỉ in cờ, không in tên/giờ.
- **`siem:prestop`**: `replay.py --mode grade` → `L1_TP/FP/FN`, `L2_…`, `L3_…`; `GT_COVER_0..6`.
- **`defender:prestop`**: in thô `du-doan.txt`, `hardening.txt`, `bao-cao-ir.md`, `phan-tu.txt`, `khao-sat.txt`; nhật ký `goi-y`; mốc bắt đầu ca và mốc `stoplab` (thời gian làm bài).

### 9.5 Rubric chấm tay `bao-cao-ir.md` (GV)

| Mục | 0 | 1 | 2 |
|---|---|---|---|
| Tóm tắt cho ban giám đốc | thiếu / đầy thuật ngữ | có, còn thuật ngữ | rõ, không thuật ngữ, nêu tác động và việc cần quyết |
| Timeline | < 5 giai đoạn | 5–6 giai đoạn | đủ 7, có bằng chứng và MITRE |
| Phạm vi & tác động | thiếu | nêu tài khoản bị ảnh hưởng | nêu cả **dữ liệu đã bị lấy** (file shadow → mọi mật khẩu trên máy coi như lộ) |
| Nguyên nhân gốc | thiếu | nêu 1 nguyên nhân | nêu chuỗi: mật khẩu yếu + cấu hình sudo/SUID sai + root đăng nhập bằng key |
| Bài học & khuyến nghị | chung chung | có kỹ thuật **hoặc** quy trình | có cả kỹ thuật lẫn quy trình (vd đổi mật khẩu toàn bộ user trên máy, rà soát sudo định kỳ, luật mới đưa vào kiểm thử) |

### 9.6 Gợi ý `checkwork` (thay các gợi ý gốc có lộ lệnh/đường dẫn)

| Khi | Gợi ý (ASCII) |
|---|---|
| `!contained` | Chua cach ly: ke tan cong van co the ket noi lai tu mang. Cat o tang mang truoc khi don dep. |
| `SUIDBD_PRESENT` | Van con mot file chay voi quyen root bat thuong. Ra soat MOI file co bit dac quyen, khong chi file ke tan cong dung de leo quyen. |
| `!timeline_full` | Timeline chua du/chua khop. Lui ve TRUOC lan dang nhap thanh cong va tien ve SAU luc cai persistence. |
| `!coverage_ok` | Ban do phu chua dung. Chi tinh canh bao level >= 10 cua luat NGUYEN TRANG trong cua so tung giai doan. |
| `!rule_l1_ok` | Luat do mat khau: phan biet 1 nguoi go nham nhieu lan voi 1 IP thu NHIEU TAI KHOAN, rai cham trong nhieu phut. |
| `!rule_l3_ok` | Luat root dang nhap tu xa: chi may chu quan tri CON HIEU LUC moi duoc ngoai le. |
| `!hardening_ok` | Con duong leo quyen/duy tri ke tan cong CHUA dung. Ra soat: co che cap quyen ngoai SUID; sudo cua MOI user; dang nhap tu xa cua root. |
| `!DEPLOY_SUDO_INTACT` | Ban da xoa ca quyen sudo HOP LE cua deploy. Chi go dong nguy hiem. |
| `SHADOW_COPY_PRESENT` | Ke tan cong con de lai mot ban sao du lieu nhay cam tren may. Tim theo moc thoi gian giai doan thu thap. |

---

## 10. "Trong thực tế SOC"

- **Cảnh báo đầu tiên hiếm khi là bước đầu tiên.** Trong đa số vụ thật, SIEM chỉ bắt được giai đoạn giữa hoặc cuối; điều tra phải lùi lại trong log để tìm cách kẻ tấn công vào.
- **Dò mật khẩu kiểu rải, chậm** (một mật khẩu, nhiều tài khoản, cách nhau xa) được dùng rộng rãi vì mỗi tài khoản chỉ lỗi một lần (né khóa tài khoản) và tần suất thấp (né luật brute-force theo cửa sổ ngắn). Phát hiện nó cần cửa sổ dài và đếm số tài khoản khác nhau.
- **"Đã lấy gì đi"** quyết định nghĩa vụ thông báo và mức độ nghiêm trọng. File `/etc/shadow` bị lấy nghĩa là phải coi **mọi** mật khẩu trên máy đã lộ.
- **Gỡ bỏ ≠ hardening.** Sau sự cố, các đội trưởng thành làm *variant analysis*: lỗ này thuộc loại nào, còn chỗ nào cùng loại.
- **Bản đồ phủ phát hiện** (thường vẽ trên ma trận MITRE ATT&CK) là cách SOC biến một sự cố thành danh sách việc cho Detection Engineering.
- **Báo cáo IR** theo NIST SP 800-61 (chuẩn bị → phát hiện & phân tích → ngăn chặn, loại bỏ, khôi phục → hoạt động sau sự cố) là khung phổ biến; phần "bài học" là phần hay bị bỏ qua nhất.

---

## 11. Thời lượng ước tính

| Pha | Phút |
|---|---|
| ① Nhận vụ việc + dự đoán | 10 |
| ② Cách ly, timeline 7 giai đoạn, gỡ bỏ | 50 |
| ③ Bản đồ phủ + 3 luật | 35 |
| ④ Hardening | 25 |
| Báo cáo IR + phản tư + checkwork | 25 |
| **Tổng** | **~145–150** (chia 2 buổi: ①② / ③④ + báo cáo) |
| *Chưa tính* | *~17' chờ chuỗi tấn công chạy xong (mục 4.2) — dùng để đọc manual và tài liệu nền* |

---

## 12. Cá nhân hóa & chống chép

- **Giữ từ lab gốc:** `EMPNUM` → tên tài khoản bị chiếm và backdoor; giờ thật của từng giai đoạn (timeline khớp ±1').
- **Thêm mới, random theo SV:**
  - `N_SPRAY` (10–14) và danh sách tài khoản mồi;
  - khoảng cách giữa các lần dò → giờ `TIME_SPRAY`;
  - tên file chứa shadow bị chép;
  - **H1:** trình thông dịch mang capability (chọn 1 trong `python3` / `perl`);
  - **H2:** trình soạn thảo trong quy tắc sudo của `deploy` (chọn 1 trong `vim` / `nano` / `less`);
  - tập kiểm tra ẩn của L1–L3 (IP, user, số lượng).
- **Đáp án giống nhau cho mọi SV — chấp nhận có ý thức:** MITRE (5 số), bản đồ phủ (7 số). Đây là **kiến thức** ta muốn SV nhớ, không phải dữ liệu riêng. Nếu chỉ chép, SV vẫn trượt timeline (giờ riêng), hardening (H1/H2 khác nhau) và luật (tập kiểm tra riêng).
- **Lỗ đã biết từ lab gốc:** `/root/.soc_truth` nằm trên target, analyst có sudo. Không sửa trong bản bọc (giữ logic gốc); đáp án **mới** quan trọng đặt trên siem ẩn.

---

## 13. Độ lệch so với nguyên tắc "[Tái dùng]"

Lộ trình định nghĩa bài tái dùng là *"bọc thêm phiếu điều tra & xếp mạch, giữ nguyên logic chấm"*. Bản này **giữ nguyên logic chấm**, nhưng **mở rộng chuỗi tấn công** (thêm 4 giai đoạn). Lý do: với 3 giai đoạn gốc, vi-kỹ năng "timeline toàn cảnh" của chính dòng lộ trình bài 17 không thể dạy được — không có gì trước cảnh báo để lùi về, không có gì sau để tiến tới.

**Quyết định:** dùng chuỗi đầy đủ 7 giai đoạn. Giai đoạn 4 (chép shadow) trả lời câu hỏi IR "đã lấy gì đi" và tạo ra tạo tác phải dọn; bỏ nó thì phần phạm vi & tác động của báo cáo IR chỉ còn "đã quay lại". Giai đoạn 2 (trinh sát) giữ timeline liền mạch giữa truy cập và leo thang, và cho SV thấy sudo ghi cả lần **liệt kê** quyền — dấu hiệu sớm mà L2 chưa bắt.

---

## 14. Rủi ro kỹ thuật & spike

| # | Rủi ro | Cách kiểm | Dự phòng |
|---|---|---|---|
| **S1** | Thêm giai đoạn làm chuỗi dài ~16–18', mốc gần nhau | Mỗi giai đoạn cách nhau ≥ 2'; đo log thật | Rút khoảng cách giữa các giai đoạn mới còn ≥ 90 giây (dung sai timeline ±1' vẫn tách bạch) |
| **S2** | Mức luật mặc định của Wazuh cho từng giai đoạn (bản đồ phủ) | Chạy chuỗi trên VM, đọc `rule.level` | Chấm không vỡ vì `GT_COVER_*` tính từ cảnh báo thật (mục 6.2); chỉ cần chỉnh seed nếu muốn giữ đúng thông điệp "6/7 giai đoạn không có cảnh báo" |
| **S3** | `sudo -l` có ghi `COMMAND=list` vào `auth.log` trên ảnh target | Thử trên ảnh `labtainer.base2` | Giai đoạn 2 đổi sang một lệnh để lại dấu vết chắc chắn (vd đọc `/etc/sudoers.d` qua sudo bị từ chối → dòng `command not allowed`) |
| **S4** | Đổi `siem` sang ảnh chung + `TERMINALS 0` làm vỡ hướng dẫn gốc (đọc mật khẩu admin trên siem) | Cập nhật manual: mật khẩu cố định như các bài trên `main` | — |
| **S5** | `PermitRootLogin no` + nạp lại `sshd` không làm mất phiên `analyst` | Thử trên ảnh target | — |
| **S6** | Capability `cap_setuid` trên ảnh target (cần `setcap`, hệ thống file hỗ trợ xattr trong container) | Thử `setcap`/`getcap` trong container Labtainers | Thay H1 bằng một file SUID thứ hai **nằm trong baseline gói** nhưng không nên có SUID (vd một công cụ ít dùng) |
| **S7** | Đáp án gốc nằm ở `/root/.soc_truth` trên target, analyst có sudo (G7) | — | Chấp nhận như lab gốc; đáp án **mới** quan trọng (bản đồ phủ, tập kiểm tra luật) nằm trên siem ẩn |
| **S8** | Decoder con `sudo-prog` tách được `sudo.program` từ dòng `sudo` của ảnh target (cả dòng có và không có tham số) | `wazuh-logtest` với 6 dòng mẫu (`awk`, `vim file`, `systemctl restart x`, `-l`) | Bỏ CDB list ở L2, dùng `<field name="command" type="pcre2">` với danh sách chương trình viết trong regex |

---

## 15. Ràng buộc với các bài khác

- **Bài ➕ (kể cả Bài 15):** Bài 17 không phụ thuộc. Câu ràng buộc về Bài 17 trong kịch bản Bài 15 đã được sửa cho khớp chuỗi 7 giai đoạn (không có di chuyển ngang).
- **Bài 16:** dùng lại `replay.py`, `kiem-thu-luat`, `thu-dong`, quy ước đếm theo kịch bản và dải ID. Dải 100270–100299 dành cho Bài 17.
- **Bài 18:** bài 17 là "điều tra trọn vẹn không áp lực thời gian"; bài 18 là "ca trực có áp lực thời gian". Bài 18 không lặp lại hardening.

---

## 16. Danh sách file thay đổi / thêm (`labs/soc-privesc/`)

| File | Thay đổi |
|---|---|
| `attacker/attack.sh` | thêm giai đoạn 0 (dò mật khẩu), 2 (liệt kê sudo), 4 (chép shadow + ghi `CRED_TIME`), 6 (quay lại bằng key, kéo file); ghi `N_SPRAY` vào truth; ghi `/var/run/soc-ca-truc` khi xong |
| `attacker/plant.sh` | **không đổi** |
| `target/_bin/fixlocal.sh` | thêm ~12 tài khoản `emp*` mồi; nhiễu lành (mục 6.1); H1–H3; khung `findings.txt` mở rộng (giữ nguyên các khóa gốc) |
| `target/_bin/prestop` | **nối thêm** khối chấm mới vào cuối, không sửa dòng gốc |
| `siem/*`, `dockerfiles/Dockerfile.soc-privesc.siem.student` | chuyển sang ảnh chung `soc-wazuh`; thêm `replay.py`, tập kiểm tra ẩn L1–L3, `GT_COVER`; `prestop` |
| `defender/*` | công cụ Bài 16; `goi-y` (dùng chung); `~/luat/`, `~/dev/`, `~/sudo-da-duyet.csv`, `~/admin-hosts.csv`, khung `du-doan.txt`, `hardening.txt`, `bao-cao-ir.md`, `phan-tu.txt`, `khao-sat.txt`; `prestop` |
| `siem/decoders/sudo-prog.xml` | decoder con tách `sudo.program` (mục 6.4) |
| `config/start.config` | `GRADE_CONTAINER` vẫn là `target` (goal gốc đọc từ đây); siem `TERMINALS 0` |
| `instr_config/results.config`, `goals.config` | giữ toàn bộ dòng gốc; nối thêm phần mới; thay các `#CHECK_*` gốc có lộ lệnh/đường dẫn (mục 9.6) |
| `docs/read_first.txt` | viết lại theo chuẩn (mục 7, 8; chỉ gợi ý cấp 1) |
| `tools/goi-y/bai17.txt` | nội dung gợi ý cấp 2, 3 cho công cụ `goi-y` dùng chung |
| `docs/giai-mau-soc-privesc-ir.md` | **local**, không commit |
