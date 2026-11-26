# Kịch bản lab: Bài 18 — `soc-shift-capstone` — Ca trực mô phỏng (capstone)

> Tài liệu mô tả kịch bản để nhóm/GVHD **duyệt TRƯỚC khi code** (được commit).
> Giải mẫu: `docs/giai-mau-soc-shift-capstone.md` (chỉ để local, không commit).
> Nguồn: **[Mới]** — Chặng 4, bài lõi ⭐, capstone. **Không dựng hạ tầng mới:** ghép `cases.py` + watcher thời gian của Bài 14 với `replay.py` + `kiem-thu-luat` của Bài 16.

---

## 0. Tóm tắt một trang

| Mục | Nội dung |
|---|---|
| Vị trí lộ trình | **Bài 18 — Chặng 4 (Tổng hợp)**, Khó nhất, lõi ⭐, capstone |
| Vi-kỹ năng chính (theo lộ trình) | **D: triage + viết rule nhanh, chấm theo chính xác + thời gian + chất lượng rule** |
| Vòng lặp | Cả 4 mắt xích, **chạy song song và lặp lại** trong một ca: ① ticket đến → ② triage/điều tra → ③ viết luật khi IR yêu cầu → ④ dập bão cảnh báo mà không mù |
| Điểm mới so với trước | Bài 14: hàng đợi có sẵn, chỉ một P1 chen ngang. Bài 16: sửa luật không giới hạn thời gian. Bài 17: điều tra trọn vẹn không áp lực. **Bài 18: việc đến theo thời gian thực, nhiều loại việc tranh nhau, một chiến dịch rải qua nhiều ticket, một bão cảnh báo che giấu tấn công, và kết thúc bằng bàn giao ca.** |
| Lặp xoắn ốc | Chỉ dùng họ của bài **lõi**: 3, 4, 5, 7, 10, 11, 14, 16, 17. Không có hardening (đã ở Bài 17). **Không phụ thuộc bài ➕ nào** (kể cả Bài 15). Chuỗi tấn công trong ca **phát lại chiến dịch xuyên suốt** (Bài 5 → 7 → 10 → 11) trong nhiễu, đúng mục 10 của lộ trình. |
| Khái niệm chiều sâu | (1) **Ưu tiên giữa các việc khác loại** (P1 > bão cảnh báo > yêu cầu luật > hàng đợi thường) — và **vì sao**. (2) **Bão cảnh báo có thể là màn khói**: tấn công trộn trong bão; dập bão bằng cách tắt luật là mù đúng lúc nguy hiểm nhất. (3) **"Đủ tốt, kịp lúc"**: luật triển khai trong 20' với P/R 0,9 có giá trị hơn luật hoàn hảo sau ca trực. (4) **Bàn giao ca** là một phần của ứng phó: việc dở dang không được rơi giữa hai ca. |
| Topology | 2 container như Bài 14/16: `siem` (ẩn; seed + lịch phát sự kiện + bộ phát lại) + `defender` (làm bài, nơi chấm) |
| Chấm | **3 cổng bắt buộc** (không bỏ sót P1; luật bị bão không được "tắt"; luật săn được triển khai) + **điểm tổng 100** = chính xác 40 + thời gian 30 + chất lượng luật 30. Đạt khi qua 3 cổng **và** điểm ≥ 60. Xuất thêm 3 chỉ số **cùng tên với Bài 0/19** (thời gian triage, độ chính xác phân loại, số tấn công phát hiện) cho số liệu đồ án (mục 9.6). |
| Thời lượng | **90 phút ca trực cố định** + 10' đọc SOP trước ca + 10' bàn giao & phản tư = ~110' |

---

## 1. Bối cảnh (câu chuyện tại Công ty X)

> **Ca đêm thứ Sáu, 22:00.** Đây là ca trực đầu tiên bạn **một mình** chịu trách nhiệm hàng đợi Tier 1, kiêm luôn việc sửa luật khẩn — trưởng ca chỉ trả lời tin nhắn.
>
> Bàn giao từ ca chiều (`~/ban-giao-ca-truoc.txt`):
>
> *"(1) Từ 21:00 DevOps triển khai agent sao lưu mới lên toàn bộ máy chủ, có CHG. (2) `web-shop` có vài request lạ lúc chiều, chưa kịp xem. (3) Luật tiến trình đã sửa tuần trước, ổn định."*
>
> Trưởng ca nhắn trước khi đi:
>
> *"Đêm nay cậu là SOC. Hàng đợi, sự cố, và nếu IR cần luật gấp thì cậu viết. P1 thì báo ngay. Hết ca nhớ bàn giao đầy đủ — sáng mai tôi đọc bàn giao trước khi đọc bất cứ thứ gì."*

Không ai nói trước rằng: (2) là bước đầu của một cuộc tấn công sẽ diễn ra **ngay trong ca** — nhóm APT của chiến dịch xuyên suốt quay lại, lần này đi trọn chuỗi từ khai thác web tới đưa dữ liệu ra ngoài — và (1) sẽ sinh ra một bão cảnh báo đúng lúc kẻ tấn công cần màn khói.

---

## 2. Mục tiêu học tập

Sau bài này, người học có thể:

1. **Triage liên tục** một hàng đợi có ticket đến theo thời gian, giữ MTTA thấp mà không hy sinh độ chính xác (Bài 14).
2. **Ưu tiên giữa các việc khác loại** cùng lúc: P1, bão cảnh báo, yêu cầu luật khẩn, ticket thường — và giải thích được thứ tự.
3. **Nhận ra một chiến dịch** rải qua nhiều ticket trong ca — gồm cả các bước **không** có ticket — và gom chúng thành **một sự cố** (Bài 14, 17).
4. **Viết luật săn trong 20 phút** từ mô tả hành vi của IR, triển khai bản "đủ tốt" trước rồi cải thiện (Bài 10, 11, 16).
5. **Dập bão cảnh báo không làm mù**: phân biệt BTP hàng loạt (đợt triển khai có CHG) với tấn công trộn trong bão; sửa luật bằng ngoại lệ có căn cứ, giữ recall (Bài 14, 16).
6. **Bàn giao ca**: tổng hợp sự cố đang mở, việc dở dang, luật đã đổi, rủi ro cho ca sau.

**Ánh xạ bản đồ năng lực:** D (triage dưới áp lực thời gian, ưu tiên nhiều việc, vận hành ca trực) ✔ chính · B (phân loại, pivot, leo thang, gom sự cố) ✔ · C (viết luật nhanh, tinh chỉnh) ✔.

---

## 3. Kiến thức cần có trước

Bài 18 **không dạy kỹ năng mới**; nó kiểm tra việc phối hợp các kỹ năng đã có dưới áp lực.

| Cần | Học ở |
|---|---|
| Triage TP/BTP/FP, ma trận ưu tiên, bằng chứng E, ghi chú leo thang | Bài 14 |
| Dấu vết SQLi, webshell + FIM, implant/beacon `netmon`, DNS exfil | Bài 5, 7, 10, 11 |
| Viết luật, `thu-dong`, `kiem-thu-luat`, precision/recall, CDB list ngoại lệ, luật con level 0 | Bài 10, 11, 16 |
| Timeline chuỗi tấn công, gom giai đoạn | Bài 17 |

**Kiến thức nền mới** (manual giải thích ngắn):

- **Quản lý ca trực**: SOC thật đo MTTA (thời gian xác nhận) và MTTR, và có thứ tự ưu tiên giữa các *loại* việc, không chỉ giữa các ticket.
- **Bão cảnh báo**: hàng trăm cảnh báo của một luật trong vài phút, thường do thay đổi hợp lệ. Hai sai lầm kinh điển: (a) để bão ngập hàng đợi, bỏ lỡ việc khác; (b) tắt luật cho yên, mù luôn tấn công thật.
- **Luật khẩn (emergency detection)**: khi IR thấy kỹ thuật mới đang được dùng, Detection Engineer viết luật trong vài chục phút, triển khai, rồi tinh chỉnh sau.
- **Bàn giao ca**: tài liệu ngắn, có cấu trúc; ca sau phải hành động được mà không cần gọi lại.

---

## 4. Môi trường

### 4.1 Topology và công cụ

| Container | Vai trò |
|---|---|
| `siem` (172.20.0.20, **TERMINALS 0**) | Wazuh (ảnh chung `soc-wazuh`). `seed-bai18.py`: nạp nền + ngữ cảnh `ctx-*` lúc boot. `lich-ca.py`: **bộ lập lịch** phát ticket / sự kiện / bão / yêu cầu theo thời gian tương đối từ lúc ca bắt đầu (mục 5). Chứa `replay.py` + tập kiểm tra ẩn của 2 luật + đáp án. Lưu lượng của chiến dịch **thật sự đi qua bộ máy luật** (ghi vào log được chính manager đọc — spike S2) để luật SV viết nổ trực tiếp trong ca. |
| `defender` (172.20.0.30) | Firefox + terminal. `~/SOP-ca-truc.txt` (SOP Bài 14 + mục thứ tự ưu tiên việc). Phiếu `~/triage.txt` (định dạng Bài 14), `~/su-co.txt`, `~/leo-thang/`, `~/ban-giao.txt`, `~/phan-tu.txt`. Công cụ Bài 16: `thu-dong`, `kiem-thu-luat`. Watcher Bài 14 (mốc `READY`, lần đầu thấy từng ticket, lần đầu ghi từng dòng phiếu, mỗi lần nạp luật). **GRADE_CONTAINER.** |

### 4.2 Bắt đầu và kết thúc ca

- **Bắt đầu ca** = `READY` (dashboard sẵn sàng **và** seed xong — cơ chế Bài 14). Đồng hồ ca 90' chạy từ đây; `lich-ca.py` dùng cùng mốc.
- **Kết thúc ca** = `READY + 90'`. Sau mốc này:
  - lịch ngừng phát;
  - watcher **đóng băng** phiếu: mọi thay đổi của `triage.txt`, `su-co.txt`, `leo-thang/` sau mốc không được tính;
  - SV còn 10' để viết `ban-giao.txt` và `phan-tu.txt`.
- Nhắc nhở hiển thị trên terminal defender ở phút 60, 80, 90.

---

## 5. Kịch bản ca trực (lịch phát sự kiện)

Mốc tính theo phút từ lúc bắt đầu ca. Mỗi mốc có độ lệch ngẫu nhiên ±2' theo SV; **thứ tự** giữa các sự kiện có quan hệ nhân quả được giữ nguyên.

### 5.1 Ba luồng chạy song song

**Luồng A — Hàng đợi thường (9 ticket).** Rút từ thư viện `cases.py` của Bài 14 (T/B/F/X1, chỉ họ lõi), đến theo 3 đợt:

| Đợt | Phút | Số ticket |
|---|---|---|
| 1 | 0–5 | 4 (có sẵn lúc đầu ca, kể cả 1 ticket tồn từ ca chiều) |
| 2 | 25–40 | 3 |
| 3 | 55–70 | 2 |

Cơ cấu random theo ràng buộc chống suy luận cấu trúc của Bài 14 (4.4). Mỗi đợt có ≥ 1 BTP hoặc FP. Như Bài 14, **không** dùng hàng C của ma trận ưu tiên, và TP của hàng đợi thường **không bao giờ là P1** (chỉ rơi vào các ô A × Thấp = P2, B × TB = P2, B × Thấp = P3 của ma trận): mọi P1 trong ca đều thuộc chuỗi tấn công, để cổng `gate_no_missed_p1` đo đúng ý đồ. Hàng đợi có thể có một ticket **giống** bước chuỗi (vd beacon trên máy khác) để kiểm tra việc gom sự cố.

**Luồng B — Chiến dịch trên `web-shop` (6 bước, 4 bước có ticket).**

| Phút | Sự kiện | Hiện ra như thế nào | Sự thật |
|---|---|---|---|
| 8 | **C1** SQLi thành công: một IP ngoài nhận phản hồi `200` lớn | ticket level 12 | TP, A × Cao = **P1** |
| 18 | **C2** File `.phtml` mới trong `uploads/` của `web-shop` | ticket FIM level 12 | TP, **P1**; cùng sự cố với C1 |
| 30 | **C3** Webshell bắt đầu được gọi lệnh — **nhưng** kẻ tấn công dùng tham số khác (không phải `cmd=`) → luật hiện tại **không** nổ | **không có ticket**; xuất hiện **yêu cầu luật khẩn** (luồng C, R-A) | lỗ hổng phát hiện |
| 45 | **C4** Implant ngụy trang trên `web-shop` beacon ra ngoài mỗi 30s (họ Bài 10) | ticket level 13 | TP, **P1**; cùng sự cố |
| 50–65 | **C5** Từ `web-shop` quét nội bộ (kết nối tới nhiều máy, nhiều cổng) | **trộn trong bão cảnh báo** (luồng C, R-B); không có ticket riêng | tấn công bị che |
| ~72 | **C6** Đưa dữ liệu khách hàng ra ngoài qua DNS từ `web-shop` (họ Bài 11) | ticket level 12 | TP, **P1**; cùng sự cố |

Sau C3, lịch tiếp tục phát lệnh webshell mỗi 3–5' tới hết ca → luật R-A của SV, nếu đúng, **nổ trực tiếp** trên dashboard.

**Về C5:** hành vi quét gần với Bài 6 (➕), nhưng SV **không** cần kỹ năng phân tích quét: luật phát hiện có sẵn, SV chỉ cần nhận ra **máy nguồn** của cảnh báo còn lại sau khi khoanh vùng bão là `web-shop` (Top values — Bài 1; gom sự cố — Bài 14). Bài vẫn không phụ thuộc bài ➕.

**Luồng C — Hai việc kỹ nghệ phát hiện.**

| Phút | Việc | Mô tả cho SV | Hạn |
|---|---|---|---|
| ~32 | **R-A: Yêu cầu luật khẩn của IR** (`~/yeu-cau/R-A/`) | *"Kẻ tấn công đang gọi lệnh qua webshell trên `web-shop`, tham số đổi liên tục. Cần luật bắt **mọi** lệnh gọi qua script trong thư mục upload, không phụ thuộc tên tham số. Triển khai trong 20 phút."* Kèm tập phát triển nhỏ có nhãn. | 20' kể từ khi xuất hiện |
| ~48 | **R-B: Bão cảnh báo** | Luật "một máy kết nối tới nhiều đích nội bộ trong thời gian ngắn" (dải ID 100340–100349) bắt đầu nổ hàng trăm lần do **agent sao lưu mới** (CHG trong `ctx-changes`) — trưởng ca nhắn: *"Dashboard đang ngập. Xử lý đi, nhưng đừng để mù."* Bão **không sinh ticket** (không ngập `triage.txt`), chỉ ngập dashboard và che các cảnh báo khác; việc xử lý bão được chấm qua R-B. Kèm tập phát triển nhỏ. | 20' kể từ khi xuất hiện |

### 5.2 Ý đồ của từng thiết kế

- **C1, C2, C4, C6 là P1 rải đều** (phút 8, 18, 45, ~72): đo phản hồi P1 nhiều lần, không chỉ một lần như Bài 14. C6 đến cuối ca, khi SV đã mệt và đang dồn ticket thường — đúng lúc dễ bỏ sót nhất.
- **C3 không có ticket**: SV chỉ biết qua yêu cầu IR → luyện "luật khẩn". Lệnh webshell tiếp tục chạy → SV thấy luật của mình hoạt động (phản hồi tức thì, tạo động lực).
- **C5 trong bão**: tấn công thật dùng đúng kỹ thuật mà luật bị bão phát hiện. SV dập bão bằng cách tắt luật, nâng ngưỡng tần suất, hoặc loại trừ quá rộng (vd mọi máy chủ, cả dải nội bộ) sẽ **không thấy C5**; loại trừ theo cổng (vd mọi kết nối cổng 22) làm luật mù với các kịch bản quét SSH của tập kiểm tra ẩn và chỉ còn thấy C5 một phần. SV dập bão bằng ngoại lệ có căn cứ (máy nguồn = máy chủ sao lưu đã duyệt **và** cổng của agent) sẽ thấy cảnh báo C5 nổi lên **từ `web-shop`** ngay sau khi nạp luật.
- **Bàn giao ca trước có mồi**: mục (2) là manh mối thật; mục (3) "luật tiến trình ổn định" là thông tin đúng nhưng vô dụng — SV không cần làm gì.
- **Va chạm thời gian có chủ đích**: R-A (phút ~32) và đợt 2 (25–40) chồng nhau; R-B (~48) và C4 (45) chồng nhau → SV **phải** chọn thứ tự. Đây là **thiết kế, không phải lỗi lịch**: khi chạy thử, nhóm không được giãn các mốc này ra; nếu tải quá nặng thì giảm số ticket thường (S6).

---

## 6. SOP ca trực (`~/SOP-ca-truc.txt`, UTF-8 có dấu)

SOP triage của Bài 14 (định nghĩa TP/BTP/FP, quy tắc khớp ngữ cảnh, ma trận ưu tiên, bằng chứng E), **cộng thêm**:

```
7. THỨ TỰ ƯU TIÊN GIỮA CÁC LOẠI VIỆC (cao → thấp)
   (1) Ticket P1 mới: xác nhận + leo thang trong ≤ 10 phút.
   (2) Bão cảnh báo: KHOANH VÙNG trong ≤ 20 phút. Bão vừa làm ngập dashboard,
       vừa có thể CHE một tấn công thật.
       CẤM tắt luật hoặc hạ luật xuống dưới mức cảnh báo để dập bão.
   (3) Yêu cầu luật khẩn của IR: triển khai bản "đủ tốt" trong ≤ 20 phút,
       tinh chỉnh sau.
   (4) Ticket thường: mục tiêu ≤ 5 phút/ticket.
   Đang làm việc (3)/(4) mà có việc (1)/(2) mới → dừng, chuyển sang.

8. GOM SỰ CỐ
   Nhiều ticket thuộc cùng một chuỗi tấn công → ghi thành MỘT sự cố trong ~/su-co.txt.
   Mỗi sự cố chỉ cần MỘT ghi chú leo thang, cập nhật khi có ticket mới của chuỗi.

9. BÀN GIAO CA (~/ban-giao.txt) — điền đủ các trường, viết cho người KHÔNG ở trong ca.
```

---

## 7. Nhiệm vụ (khung `read_first.txt` — ASCII, không spoil)

### Trước ca (≈10', ngoài 90')

- Đọc SOP ca trực và bàn giao ca trước.
- **Kế hoạch ca** (`~/ke-hoach.txt`, không chấm, dùng cho phản tư): bạn sẽ làm gì khi hai việc đến cùng lúc?
- **Khảo sát trước** (`~/khao-sat.txt`, dòng `TRUOC=1..5`): *"Tôi tự tin xử lý một ca trực có nhiều loại việc đến cùng lúc mà không bỏ sót sự cố."*

### Trong ca (90')

Manual **không** liệt kê sự kiện sẽ đến. Chỉ mô tả các **loại việc** và **sản phẩm** cần có:

**1. Triage** — mỗi ticket một dòng trong `~/triage.txt`, định dạng Bài 14: `INC-xxx=V,P,E`.

**2. Gom sự cố** — `~/su-co.txt`:

```
SC1=INC-xxx,INC-yyy,...     # cac ticket cung mot chuoi tan cong
SC1_HOST=                   # may trung tam cua su co
SC1_GIAI_DOAN=              # so giai doan cua chuoi XAY RA TRONG CA (tinh ca giai doan khong co ticket;
                            # khong tinh hoat dong truoc ca, vd do tham luc chieu)
```

**3. Leo thang** — mỗi sự cố (không phải mỗi ticket) một file `~/leo-thang/SC1.txt`, khung Bài 14 (`TICKET`, `HOST`, `ASSET_LEVEL`, `STAGE`, `MITRE`, `IOC_C2`, `LIEN_QUAN`, `DE_XUAT`, `TOM_TAT`), **cập nhật** khi chuỗi có bước mới. Watcher ghi lại mỗi lần sửa.

**4. Luật khẩn và bão cảnh báo** — khi có yêu cầu trong `~/yeu-cau/`:
- Viết luật trong dải ID được giao, kiểm thử bằng `thu-dong` / `sudo kiem-thu-luat` (tập phát triển kèm yêu cầu), triển khai.
- Ràng buộc chung của Bài 16: level ≥ 10 cho cảnh báo, có `<mitre>`, ngoại lệ dựa trên trường và danh mục có căn cứ.

### Sau ca (≈10')

**Bàn giao** — `~/ban-giao.txt`:

```
SU_CO_DANG_MO=        # so luong su co chua dong
SC_CHINH=             # ten su co chinh (vd SC1) va may trung tam
LUAT_DA_THAY_DOI=     # dai ID cac luat ban da them/sua trong ca
TICKET_CHUA_XU_LY=    # cac ticket chua co dong trong triage.txt (neu co)
RUI_RO_CHO_CA_SAU=    # 2-3 cau: dieu ca sau phai theo doi ngay
VIEC_CAN_QUYET=       # 1-2 cau: quyet dinh can truong ca / IR dua ra
```

**Phản tư** — `~/phan-tu.txt`: so `ke-hoach.txt` với thứ tự bạn thực sự đã làm (watcher có nhật ký); lúc nào bạn chọn sai việc?

**Khảo sát sau** — `~/khao-sat.txt` dòng `SAU=` (cùng câu hỏi).

---

## 8. Gợi ý theo 3 cấp

Như các bài 14–17: cấp 1 nằm trong `read_first.txt`; cấp 2 và 3 chỉ mở bằng lệnh `goi-y <muc> <cap>` (công cụ dùng chung, mỗi lần mở được ghi nhật ký: mục, cấp, thời điểm). Trong ca có giới hạn thời gian; manual dặn: *"Gợi ý cấp 3 tốn thời gian đọc — chỉ dùng khi bế tắc."* Gợi ý **không** trừ điểm; số lần dùng là số liệu đồ án.

**Cấp 1 — định hướng**

- Một ticket lạ trên một máy đã từng có ticket trong ca: đó có phải bước tiếp theo không?
- Yêu cầu khẩn của IR nói về **hành vi**, không về một chuỗi cụ thể.
- Bão cảnh báo luôn có nguyên nhân. Nguyên nhân hợp lệ giải thích được **phần lớn** — nhưng có giải thích được **tất cả** không?

**Cấp 2 — chỉ chỗ**

- Gom sự cố: lọc mọi cảnh báo của `web-shop` trong ca, sắp theo thời gian. Một ticket trông giống bước của chuỗi nhưng nằm trên **máy khác** có thuộc sự cố này không?
- R-A: thư mục upload chỉ nên phục vụ ảnh/tài liệu; *mọi* request tới script trong đó có đáng ngờ không? Có script hợp lệ nào nằm trong đó theo danh mục dịch vụ đã duyệt?
- R-B: CHG của đợt triển khai ghi máy nguồn nào, cổng nào? Top values `data.srcip` của bão: có máy nguồn nào **không** nằm trong CHG?

**Cấp 3 — gần như lời giải**

- **R-A:** luật con của luật nền web; `url` khớp `^/uploads/[^?]*\.(php|phtml|phar)\?` (có query string); loại trừ script đã duyệt bằng **luật con level 0** khớp đường dẫn của nó (không dùng CDB list `match_key`: trường `url` chứa cả query string nên khớp nguyên giá trị không bao giờ trúng); level 12; MITRE T1505.003.
- **R-B:** giữ luật tần suất; thêm luật con level 0 cho **sự kiện kết nối** (trước khi bị đếm) **chỉ** khi (máy nguồn thuộc list máy chủ sao lưu của CHG) **và** (cổng đích thuộc các cổng CHG ghi). Sau khi nạp, cảnh báo còn lại từ `web-shop` chính là C5.
- **Thứ tự hợp lý:** C1 → C2 → (đợt 2) → R-A ngay khi đến → C4 (dừng R-A nếu chưa xong) → R-B → phần còn lại của hàng đợi, xen C6 ngay khi đến; cập nhật `leo-thang/SC1.txt` sau mỗi bước chuỗi.

---

## 9. Chấm điểm

### 9.1 Ba cổng bắt buộc

| Cổng | Đạt khi | Lý do |
|---|---|---|
| `gate_no_missed_p1` | C1, C2, C4, C6 (mọi P1 của ca) đều được ghi verdict **TP** với ưu tiên **P1** trong `triage.txt` trước khi hết ca | Bỏ sót P1 trong ca thật là sự cố nghiêm trọng, không bù được bằng điểm khác |
| `gate_storm_not_blind` | Luật dải 100340–100349 đang nạp có **recall ≥ 0,9** trên tập kiểm tra ẩn (gồm kịch bản quét kiểu C5) | Cấm "dập bão bằng cách tắt luật" (SOP 7.2) |
| `gate_ra_deployed` | Có ≥ 1 luật level ≥ 10 trong dải R-A được nạp **trước khi hết ca** | Yêu cầu khẩn của IR không được bỏ qua |

### 9.2 Điểm tổng (100)

| Nhóm | Điểm | Thành phần | Cách tính |
|---|---|---|---|
| **Chính xác** | 40 | Verdict hàng đợi | 15 × (số verdict đúng / tổng ticket) |
| | | Bằng chứng E | 10 × (số E đúng / tổng ticket) |
| | | Ưu tiên các TP | 5 × (số P đúng / số TP) |
| | | Gom sự cố | `SC1` đúng tập {C1, C2, C4, C6}: 3 (thiếu/thừa 1 ticket: 1) · `SC1_HOST` = `web-shop`: 1 · `SC1_GIAI_DOAN` = 6 (C1–C6 trong ca, gồm 2 giai đoạn không có ticket): 1 |
| | | Ghi chú leo thang SC1 | 5 × (số trường định lượng đúng / 7) — `TICKET` (bất kỳ ticket nào trong chuỗi), `HOST`, `ASSET_LEVEL`, `STAGE`, `MITRE`, `IOC_C2`, `DE_XUAT` |
| **Thời gian** | 30 | MTTA của từng P1 | 3 điểm mỗi P1 (C1, C2, C4, C6): đủ 3 nếu ≤ 10', 1,5 nếu ≤ 15', 0 nếu hơn |
| | | MTTA trung vị ticket thường | 8 nếu ≤ 5', tuyến tính về 0 tại 15': điểm = 8 × (15 − t) / 10, cắt trong [0, 8] |
| | | Thời gian triển khai R-A | 5 nếu ≤ 20', 2 nếu ≤ 30' |
| | | Thời gian khoanh vùng R-B (lần nạp đầu tiên làm số cảnh báo bão giảm ≥ 80%) | 5 nếu ≤ 20', 2 nếu ≤ 30' |
| **Chất lượng luật** | 30 | R-A trên tập kiểm tra ẩn | 15 × (P + R) / 2 |
| | | R-B trên tập kiểm tra ẩn | 10 × (P + R) / 2 |
| | | C5 lộ ra | 5 nếu luật R-B cuối cùng nổ trên kịch bản quét từ `web-shop` trong lưu lượng thật của ca (`alerts.json`) |

**Đạt bài** = 3 cổng **và** điểm ≥ 60.

**Vì sao cấu trúc như vậy:**

- Lộ trình yêu cầu chấm theo *chính xác + thời gian + chất lượng rule* → ba nhóm điểm tương ứng.
- **Chính xác nặng nhất** (40): nhanh mà sai là tệ hơn chậm mà đúng. Nhưng thời gian (30) đủ nặng để SV pivot lan man không thể đạt cao.
- **Cổng tách khỏi điểm**: có những lỗi điểm số không được phép bù (bỏ sót P1, mù luôn tấn công).
- Thang thời gian **bậc thang** (đủ / một nửa / 0) thay vì trừ theo giây: đúng tinh thần SLA của SOC.

### 9.3 Cách tính — ai tính phần nào

Labtainers chỉ có goal boolean/value. Bài này:

1. **Cổng và các thành phần** → goal (boolean) hoặc `value` trong `goals.config`, như các bài trước.
2. **Điểm tổng** → script `tools/score-bai18.py` đọc kết quả `gradelab` (CSV) của cả lớp, áp bảng 9.2, xuất điểm và bảng số liệu đồ án.

Dữ liệu cần:

| Nguồn | In ra |
|---|---|
| `defender:prestop` | phiếu thô (đã đóng băng tại hết ca); nhật ký watcher: mốc xuất hiện từng ticket/yêu cầu, mốc ghi dòng phiếu đầu tiên của từng ticket, mốc mỗi lần `kiem-thu-luat` (kèm có luật dải R-A hay không); nhật ký `goi-y`; `khao-sat.txt` |
| `siem:prestop` | GT từng ticket; GT chuỗi; `replay.py --mode grade` cho R-A và R-B; số cảnh báo dải R-B mỗi phút trong ca (để tính mốc khoanh vùng bão); `C3_SEEN` (luật dải R-A đã nổ trên lệnh webshell thật của ca), `C5_SEEN` |

**MTTA** = (lần đầu dòng `INC-xxx=` xuất hiện trong `triage.txt`) − (lần đầu ticket đó hiện trên dashboard). Cả hai mốc đo trên defender — dùng lại cơ chế đo `INC-113` của Bài 14 (spike S3 của Bài 14).

### 9.4 Gợi ý `checkwork`

Vì bài có thời gian cố định, `checkwork` **trong ca** chỉ báo trạng thái, không báo đúng/sai (tránh "dò đáp án"):

```
Ticket da xuat hien: 12   Da co dong trong triage.txt: 9
Yeu cau dang mo: R-A (con 7 phut)
Luat dai R-A da nap: co   Luat dai R-B da nap: chua
```

`checkwork` **sau ca** báo đủ các cổng và điểm thành phần.

### 9.5 Rubric chấm tay `ban-giao.txt` (GV, ngoài điểm tổng — dùng cho điểm quá trình)

| Ý | 0 | 1 | 2 |
|---|---|---|---|
| Sự cố đang mở | thiếu | có, chưa nêu máy/trạng thái | đủ: SC1, `web-shop`, đang ở giai đoạn nào, đã leo thang chưa |
| Luật đã thay đổi | thiếu | liệt kê | liệt kê + rủi ro (vd ngoại lệ R-B cần gỡ khi đợt triển khai xong) |
| Rủi ro cho ca sau | chung chung | có, cụ thể 1 ý | cụ thể, hành động được ngay (vd "theo dõi kết nối từ `web-shop` tới nội bộ; C2 vẫn có thể sống nếu chưa cô lập") |
| Việc cần quyết | thiếu | có | có, đúng người (trưởng ca / IR / DevOps) |

### 9.6 Số liệu cho đồ án (so với Bài 0/19)

Lộ trình (mục 7) so **Bài 0** với **capstone/đầu ra (#18–19)** trên 3 chỉ số. Phép đo chính vẫn là Bài 19 (cùng dạng mini-triage với Bài 0); Bài 18 xuất **cùng 3 chỉ số, cùng tên** làm dữ liệu phụ, đo trong điều kiện khó hơn (nhiều loại việc, nhiễu, bão):

| Chỉ số (tên chung 0/18/19) | Ở Bài 18 |
|---|---|
| `TRIAGE_TIME_MEDIAN` | MTTA trung vị của **mọi** ticket trong ca (phút) |
| `VERDICT_ACCURACY` | số verdict đúng / số ticket |
| `ATTACKS_DETECTED` | số bước của chuỗi C1–C6 mà SV phát hiện: C1, C2, C4, C6 = có verdict TP; C3 = luật R-A nổ trên lưu lượng thật của ca; C5 = `C5_SEEN` (tối đa 6) |

Cùng các số liệu bổ trợ của lộ trình: `TRUOC`/`SAU` trong `khao-sat.txt`, số lần mở gợi ý theo cấp, thời lượng ca (cố định 90') và thời gian bàn giao. `score-bai18.py` xuất các cột này cạnh điểm tổng.

---

## 10. "Trong thực tế SOC"

- **Ca trực thật không có hàng đợi xếp sẵn**: việc đến lúc nào cũng được, nhiều loại cùng lúc. Kỹ năng phân biệt analyst giỏi là **chọn việc**, không chỉ làm việc.
- **Bão cảnh báo trùng thời điểm tấn công** không hiếm: kẻ tấn công có kinh nghiệm chọn lúc hệ thống đang thay đổi (bảo trì, triển khai) vì biết SOC sẽ "dập" cảnh báo.
- **Luật khẩn** là chuyện hằng ngày ở các đội phản ứng: IR thấy kỹ thuật mới → Detection Engineering có luật trong một giờ → tinh chỉnh dần.
- **MTTA/MTTR** là chỉ số vận hành SOC phổ biến nhất; SLA theo mức ưu tiên (vd P1 ≤ 10–15') có trong hầu hết hợp đồng MSSP.
- **Bàn giao ca** là điểm rơi rớt thông tin kinh điển. Nhiều sự cố kéo dài vì ca sau không biết ca trước đã thấy gì.

---

## 11. Thời lượng

| Phần | Phút |
|---|---|
| Trước ca: SOP + bàn giao ca trước + kế hoạch | 10 |
| **Ca trực** (cố định) | **90** |
| Bàn giao + phản tư + checkwork | 10 |
| **Tổng** | **~110** |
| *(GV) Buổi chữa bài* | *20, ngoài giờ lab* |

**Ước lượng tải** (ca được thiết kế vừa khít 90'):

| Việc | Số lượng × phút | Tổng |
|---|---|---|
| Ticket thường | 9 × ~4' | 36' |
| P1 (xác nhận + cập nhật leo thang) | 4 × ~5' | 20' |
| R-A | ~15' | 15' |
| R-B | ~12' | 12' |
| Gom sự cố, đệm | — | ~7' |
| **Tổng** | | **~90'** |

Tải được thiết kế **vừa đủ chật**: SV làm đúng thứ tự sẽ xong; SV pivot lan man hoặc chọn sai thứ tự sẽ thiếu giờ.

---

## 12. Rủi ro kỹ thuật & spike

| # | Rủi ro | Cách kiểm | Dự phòng |
|---|---|---|---|
| **S1** | `lich-ca.py` trên siem phát sự kiện đúng mốc tương đối với `READY`; sống qua `stoplab`/`startlab` | Chạy thử 3 lần, so mốc trong `alerts.json` | Seed toàn bộ với timestamp tương lai (Discover chỉ hiện khi tới giờ) cho luồng A, B; luồng C (bão, lệnh webshell) vẫn cần bộ lập lịch |
| **S2** | Lưu lượng chiến dịch phải đi qua bộ máy luật để luật SV nổ trực tiếp | `lich-ca.py` ghi dòng log (web, kết nối, DNS) vào một file được khai báo `<localfile>` trên chính manager; kiểm: dòng ghi vào → cảnh báo xuất hiện trong ≤ 10 s, máy nguồn nằm ở trường `srcip` (không phải agent), luật SV vừa nạp nổ trên dòng kế tiếp | Bỏ phản hồi trực tiếp; `C5_SEEN` và C3 tính bằng `replay.py` trên đúng các dòng log của ca |
| **S3** | Đo MTTA cho ~13 ticket cần defender truy vấn indexer | Dùng lại spike S3 Bài 14 | Đo MTTA theo mốc lịch phát của siem (in trong prestop) thay vì mốc hiện trên dashboard; sai số ≤ 1' |
| **S4** | Bão ~300 cảnh báo trong 10' làm chậm dashboard | Đo trên VM | Giảm còn ~150 |
| **S5** | Đóng băng phiếu tại hết ca | Watcher chụp bản sao phiếu ở `READY + 90'` sang thư mục `chmod 444`; prestop đọc bản chụp | — |
| **S6** | **Tải 90' có khả thi không** | Chạy thử với 2–3 thành viên nhóm (một người đã làm Bài 14–17, một người chưa) | Giảm ticket thường từ 9 xuống 7, hoặc kéo ca thành 100' |
| **S7** | `score-bai18.py` đọc đúng định dạng xuất của `gradelab` | Thử với 3 bộ bài làm giả | — |
| **S8** | Cú pháp luật nền R-B và luật mẫu: `<different_dstip />`, `<dstport>` (trường tĩnh), `<url type="pcre2">` trên bản Wazuh của ảnh chung | `wazuh-logtest` với 5 dòng mẫu | Đổi sang `<different_field>` / `<field>` nếu bản Wazuh dùng tên trường động |

---

## 13. Cá nhân hóa & chống chép

- **Random theo SV:**
  - ticket hàng đợi (cơ cấu, giá trị — cơ chế Bài 14);
  - độ lệch mốc thời gian ±2';
  - IP kẻ tấn công, IP C2, domain exfil, tên file webshell, tên tham số lệnh;
  - máy chủ sao lưu trong CHG và cổng agent;
  - tập phát triển và tập kiểm tra ẩn của R-A, R-B.
- **Thời gian thực** là lớp chống chép tự nhiên: MTTA và mốc triển khai không chép được.
- siem ẩn; đáp án và tập kiểm tra không truy cập được.

---

## 14. Ràng buộc với các bài khác

- **Bài 14:** dùng `cases.py`, SOP, định dạng phiếu, watcher. Bài 18 thêm mục 7–9 vào SOP.
- **Bài 16:** dùng `replay.py`, `kiem-thu-luat`, `thu-dong`, quy ước đếm theo kịch bản. Dải ID: R-A 100330–100339, R-B 100340–100349.
- **Bài 17:** không lặp hardening, không lặp timeline 7 giai đoạn có chấm giờ; Bài 18 chỉ yêu cầu `SC1_GIAI_DOAN` (đếm số giai đoạn).
- **Bài 19 (đo đầu ra):** phép đo chính dùng định dạng mini-triage của Bài 14 (mục 13). Bài 18 **không thay** Bài 19 (quá dài, có yếu tố luật) nhưng xuất cùng 3 chỉ số, cùng tên (mục 9.6) để đồ án so được Bài 0 ↔ 18 ↔ 19.
- **Bài ➕ (6, 8, 9, 12, 15):** không phụ thuộc. Mọi cơ chế mượn (S2, ngữ cảnh `ctx-*`) được mô tả đầy đủ trong bài này.
- **Dải ID luật Chặng 3–4:** Bài 16: 100210–100269 · Bài 17: 100270–100299 · **100300: luật sản xuất của Bài 17 (tài khoản UID 0 mới); 100301–100329: dự phòng** · Bài 18: R-A 100330–100339, R-B 100340–100349. (Bài 15 ➕ dùng 100150–100159.)

---

## 15. Danh sách file cần tạo (`labs/soc-shift-capstone/`)

| File | Ghi chú |
|---|---|
| `config/start.config` | 2 container, `GRADE_CONTAINER defender`, siem `TERMINALS 0` |
| `config/parameter.config` | rỗng có chủ đích |
| `siem/seed-bai18.py` | nền, `ctx-*` (gồm CHG đợt triển khai agent sao lưu, danh mục script hợp lệ trong `uploads/`), GT |
| `siem/lich-ca.py` + unit systemd | bộ lập lịch 3 luồng (mục 5); đọc mốc `READY` |
| `siem/families/{webshell_cmd,lateral_scan}.py` | sinh kịch bản cho R-A, R-B (dùng chung định dạng `replay.py`); C6 dùng lại bộ sinh DNS exfil của Bài 16 |
| `siem/_bin/prestop` | GT; `replay.py --mode grade`; đường cong số cảnh báo R-B; `C3_SEEN`, `C5_SEEN` |
| `defender/SOP-ca-truc.txt`, `defender/ban-giao-ca-truoc.txt` | UTF-8 có dấu |
| `defender/watcher.sh` | mở rộng từ Bài 14: mọi ticket, mọi yêu cầu, mỗi lần `kiem-thu-luat`, đóng băng phiếu ở phút 90, nhắc giờ |
| `defender/yeu-cau/` | gói R-A, R-B (tập phát triển sinh lúc boot, mở khóa khi yêu cầu xuất hiện) |
| `defender/_bin/prestop`, `fixlocal.sh`, `student_startup.sh` | như Bài 14/16 |
| `instr_config/{results,goals}.config` | sinh bằng `gen-grading.py` (mở rộng từ Bài 14) |
| `tools/score-bai18.py` | điểm tổng + bảng số liệu đồ án (mục 9.6) |
| `tools/goi-y/bai18.txt` | nội dung gợi ý cấp 2, 3 cho công cụ `goi-y` dùng chung (dựng ở Bài 14) |
| `docs/read_first.txt` | ASCII |
| `docs/giai-mau-soc-shift-capstone.md` | **local** |
