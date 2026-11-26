#!/usr/bin/env python3
# ============================================================================
# gen-grading18.py - sinh instr_config/results.config + goals.config cho Bai 18 (P5).
#   python3 labs/soc-shift-capstone/tools/gen-grading18.py      (roi sinh lai install-soc-shift-capstone.sh)
#
# Nguyen tac (kich ban muc 9, lo trinh P5):
#   - Ticket so k = thu tu PHAT. defender in INC_k / ANS_*_k, siem in GT_*_k CUNG thu tu
#     -> so tung cap bang matchany + result._gt_* (cach da chay o soc-baseline).
#   - CHI dung integer_equal: tap so -> ma "1"+so dem 0 (canon), ten may -> crc32 (ca hai phia tinh giong nhau).
#   - siem CHI in dap an / tap an SAU HET CA (SHIFT_END=Y) -> checkwork giua ca khong lo dap an,
#     moi goal ra N; hint #CHECK_TRUE bao "ca chua ket thuc".
#   - Diem tong 100 do tools/score-bai18.py tinh (bang 9.2); goals chi la cong + thanh phan.
# ============================================================================
import os

NSLOT = 13                       # moi seed deu 13 ticket (socq.ca; test_socq kiem)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "instr_config")

D, S = "defender:prestop.stdout", "siem:prestop.stdout"


def grp(name, cont, regex):
    return "%-16s = %s : GROUP : 1 : REGEX : %s" % (name, cont, regex)


def rx(name, cont, regex):
    return "%-16s = %s : FILE_REGEX : %s" % (name, cont, regex)


def results():
    r = ["# results.config - Bai 18 - SINH TU DONG boi tools/gen-grading18.py (KHONG sua tay).",
         "# defender: phieu da DONG BANG (bai18-thu-thap) ; siem: dap an + tap an + luong that (grade18 print, chi sau het ca).",
         "",
         rx("_def_marker", D, "DEFENDER18_MARKER"),
         rx("_siem_marker", S, "SIEM18_MARKER"),
         rx("_frozen", D, r"\bSHIFT_FROZEN\b"),
         rx("_siem_end", S, "SHIFT_END=Y"),
         "",
         "# --- hang doi: tung ticket theo thu tu phat ---"]
    for k in range(1, NSLOT + 1):
        r += [grp("_ans_inc_%d" % k, D, r"\bINC_%d=([0-9]+)" % k),
              grp("_ans_v_%d" % k, D, r"\bANS_V_%d=([0-9]+)" % k),
              grp("_ans_p_%d" % k, D, r"\bANS_P_%d=([0-9]+)" % k),
              grp("_ans_e_%d" % k, D, r"\bANS_E_%d=([0-9]+)" % k),
              grp("_gt_inc_%d" % k, S, r"\bGT_INC_%d=([0-9]+)" % k),
              grp("_gt_v_%d" % k, S, r"\bGT_V_%d=([0-9]+)" % k),
              grp("_gt_p_%d" % k, S, r"\bGT_P_%d=([0-9]+)" % k),
              grp("_gt_e_%d" % k, S, r"\bGT_E_%d=([0-9]+)" % k),
              grp("_gt_isp1_%d" % k, S, r"\bGT_ISP1_%d=([0-9]+)" % k)]
    r += ["",
          "# --- gom su co SC1 (su-co.txt) ---",
          grp("_ans_sc_tk", D, r"\bANS_SC_TK_C=([0-9]+)"),
          grp("_gt_sc_tk", S, r"\bGT_SC_TK_C=([0-9]+)"),
          grp("_ans_sc_host", D, r"\bANS_SC_HOST_C=([0-9]+)"),
          grp("_gt_sc_host", S, r"\bGT_SC_HOST_C=([0-9]+)"),
          grp("_gt_sc_hostip", S, r"\bGT_SC_HOSTIP_C=([0-9]+)"),
          grp("_ans_sc_gd", D, r"\bANS_SC_GIAI_DOAN=([0-9]+)"),
          grp("_gt_sc_gd", S, r"\bGT_SC_GIAI_DOAN=([0-9]+)"),
          "",
          "# --- ghi chu leo thang SC1 (leo-thang/SC1.txt), 7 truong dinh luong ---",
          grp("_lt_ticket", D, r"\bLT_TICKET=([0-9]+)")]
    r += [grp("_gt_sc_t%d" % i, S, r"\bGT_SC_T%d=([0-9]+)" % i) for i in range(1, 5)]
    r += [grp("_lt_host", D, r"\bLT_HOST_C=([0-9]+)"),
          grp("_lt_asset", D, r"\bLT_ASSET_LEVEL=([0-9]+)"),
          grp("_gt_sc_asset", S, r"\bGT_SC_ASSET=([0-9]+)"),
          grp("_lt_stage", D, r"\bLT_STAGE=([0-9]+)"),
          grp("_gt_sc_stage", S, r"\bGT_SC_STAGE=([0-9]+)"),
          grp("_lt_mitre", D, r"\bLT_MITRE_C=([0-9]+)"),
          grp("_gt_sc_mitre", S, r"\bGT_SC_MITRE_C=([0-9]+)"),
          grp("_lt_ioc", D, r"\bLT_IOC_C2=([0-9]+)"),
          grp("_gt_sc_ioc", S, r"\bGT_SC_IOC_C2=([0-9]+)"),
          grp("_lt_dx", D, r"\bLT_DE_XUAT_C=([0-9]+)"),
          grp("_gt_sc_dx", S, r"\bGT_SC_DE_XUAT_C=([0-9]+)"),
          "",
          "# --- luat (tap AN, luat dang nap cuoi ca) + luong that cua ca (siem) ---",
          rx("_rules_valid", S, "RULES_VALID=Y"),
          rx("_rb_not_blind", S, r"\bRB_NOT_BLIND\b"),
          rx("_ra_deployed", S, r"\bGATE_RA_DEPLOYED\b"),
          rx("_ra_p90", S, r"\bRA_P100=(9[0-9]|100)\b"),
          rx("_ra_r90", S, r"\bRA_R100=(9[0-9]|100)\b"),
          rx("_rb_p90", S, r"\bRB_P100=(9[0-9]|100)\b"),
          rx("_rb_r90", S, r"\bRB_R100=(9[0-9]|100)\b"),
          rx("_c3", S, r"\bC3_SEEN\b"),
          rx("_c5", S, r"\bC5_SEEN\b"),
          rx("_rb_contain20", S, r"\bRB_CONTAIN_MIN=([0-9]|1[0-9]|20)\b"),
          rx("_live_gap", S, r"\bLIVE_GAP\b"),
          "",
          "# --- sau ca ---",
          rx("_bg_full", D, r"\bBAN_GIAO_FILLED=[4-9]\b"),
          rx("_ks_truoc", D, r"\bKS_TRUOC=[1-5]"),
          rx("_ks_sau", D, r"\bKS_SAU=[1-5]"),
          "",
          "# --- Goi y checkwork (KHONG lo dap an) ---",
          "#CHECK_TRUE: Ca truc chua ket thuc - moi muc deu N cho toi khi het ca (phieu dong bang). Xem: trang-thai",
          rx("cw_ca_xong", D, r"\bSHIFT_FROZEN\b"),
          "#CHECK_TRUE: Yeu cau R-A cua IR chua duoc trien khai truoc khi het ca (can >= 1 luat canh bao trong dai R-A, nap bang kiem-thu-luat).",
          rx("cw_ra", S, r"\bGATE_RA_DEPLOYED\b"),
          "#CHECK_TRUE: Luat dai R-B dang nap bi MU tren tap kiem tra an (tat/ha luat hoac ngoai le qua rong). SOP muc 11.",
          rx("cw_rb", S, r"\bRB_NOT_BLIND\b"),
          "#CHECK_TRUE: ban-giao.txt chua dien du cac truong (SOP muc 12).",
          rx("cw_bangiao", D, r"\bBAN_GIAO_FILLED=[4-9]\b"),
          "#CHECK_TRUE: khao-sat.txt chua dien TRUOC= va SAU= (1-5).",
          rx("cw_khaosat", D, r"\bKS_SAU=[1-5]")]
    return "\n".join(r) + "\n"


def goals():
    g = ["# goals.config - Bai 18 - SINH TU DONG boi tools/gen-grading18.py (KHONG sua tay).",
         "# Cong (kich ban 9.1) + thanh phan. Diem tong 100: tools/score-bai18.py (bang 9.2).",
         "# Giua ca siem khong in dap an -> moi goal N.",
         "",
         "lab_ready = boolean : ( _siem_marker and _def_marker )",
         "",
         "# --- hang doi: v/p/e tung ticket; isp1 = ticket do la P1 cua chuoi ---"]
    for k in range(1, NSLOT + 1):
        g += ["v_%d = matchany : integer_equal : _ans_v_%d : result._gt_v_%d" % (k, k, k),
              "p_%d = matchany : integer_equal : _ans_p_%d : result._gt_p_%d" % (k, k, k),
              "e_%d = matchany : integer_equal : _ans_e_%d : result._gt_e_%d" % (k, k, k),
              "isp1_%d = matchany : integer_equal : _gt_isp1_%d : answer=1" % (k, k),
              "p1ok_%d = boolean : ( v_%d and p_%d ) or_not isp1_%d" % (k, k, k, k)]
    g += ["",
          "# --- 3 cong bat buoc ---",
          "gate_no_missed_p1 = boolean : ( _frozen and _siem_end and %s )" % " and ".join("p1ok_%d" % k for k in range(1, NSLOT + 1)),
          "gate_storm_not_blind = boolean : ( _siem_end and _rb_not_blind )",
          "gate_ra_deployed = boolean : ( _siem_end and _ra_deployed )",
          "bai18_gates = boolean : ( gate_no_missed_p1 and gate_storm_not_blind and gate_ra_deployed )",
          "",
          "# --- gom su co SC1 ---",
          "sc1_tickets = matchany : integer_equal : _ans_sc_tk : result._gt_sc_tk",
          "sc1_host_ten = matchany : integer_equal : _ans_sc_host : result._gt_sc_host",
          "sc1_host_ip = matchany : integer_equal : _ans_sc_host : result._gt_sc_hostip",
          "sc1_host = boolean : ( sc1_host_ten or sc1_host_ip )",
          "sc1_giai_doan = matchany : integer_equal : _ans_sc_gd : result._gt_sc_gd",
          "",
          "# --- ghi chu leo thang SC1: TICKET = bat ky ticket nao cua chuoi ---"]
    g += ["lt_ticket_%d = matchany : integer_equal : _lt_ticket : result._gt_sc_t%d" % (i, i) for i in range(1, 5)]
    g += ["lt_ticket = boolean : ( lt_ticket_1 or lt_ticket_2 or lt_ticket_3 or lt_ticket_4 )",
          "lt_host_ten = matchany : integer_equal : _lt_host : result._gt_sc_host",
          "lt_host_ip = matchany : integer_equal : _lt_host : result._gt_sc_hostip",
          "lt_host = boolean : ( lt_host_ten or lt_host_ip )",
          "lt_asset = matchany : integer_equal : _lt_asset : result._gt_sc_asset",
          "lt_stage = matchany : integer_equal : _lt_stage : result._gt_sc_stage",
          "lt_mitre = matchany : integer_equal : _lt_mitre : result._gt_sc_mitre",
          "lt_ioc_c2 = matchany : integer_equal : _lt_ioc : result._gt_sc_ioc",
          "lt_de_xuat = matchany : integer_equal : _lt_dx : result._gt_sc_dx",
          "",
          "# --- chat luong luat (tap an, P va R >= 0.9) + luong that ---",
          "ra_quality = boolean : ( _siem_end and _rules_valid and _ra_p90 and _ra_r90 )",
          "rb_quality = boolean : ( _siem_end and _rules_valid and _rb_p90 and _rb_r90 )",
          "c3_seen = boolean : ( _siem_end and _c3 )",
          "c5_seen = boolean : ( _siem_end and _c5 )",
          "storm_contained = boolean : ( _siem_end and _rb_contain20 )",
          "",
          "# --- sau ca ---",
          "ban_giao = boolean : ( _frozen and _bg_full )",
          "khao_sat = boolean : ( _ks_truoc and _ks_sau )"]
    return "\n".join(g) + "\n"


def main():
    open(os.path.join(OUT, "results.config"), "w").write(results())
    open(os.path.join(OUT, "goals.config"), "w").write(goals())
    print("Da sinh results.config + goals.config (%d ticket)" % NSLOT)


if __name__ == "__main__":
    main()
