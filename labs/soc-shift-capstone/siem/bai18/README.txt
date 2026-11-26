Bai 18 - siem (/home/ubuntu/bai18). Moi thu chay ROOT qua systemd; SV khong co terminal tren siem.
  seed18.py        seed-bai18.service (oneshot, 1 lan): Wazuh (localfile, list, luat san xuat + khung),
                   user API soc-tool, ctx-*, nen, tap AN + tap phat trien, dat T0 (-> /root/.bai18/)
  lich-ca.py       lich-ca.service: phat ticket/yeu cau/bao theo T0 (phat bu khi khoi dong lai),
                   /srv/shiftd/{shift.json,yeu-cau/,chuan-bi.json,canh-bao.json} (khong dap an)
  grade18.py       rules (grade-bai18.path: moi lan doi local_rules.xml) | print (prestop) | live
                   | mau / mau-nap (giai mau - phat trien) | cached | print --cache | print --all (phat trien)
  reset-ca.py      CHI PHAT TRIEN: bat dau lai ca khong rebuild (xem docs/bai18-trien-khai.md)
  bai18_prod_rules.xml, local_rules_khung.xml   luat san xuat 100310-319 + khung SV (R-A 100330-339, R-B 100340-349)
  lib/             ban chep labs/_shared/socq + soc-tools/{wzapi,replay}.py
                   -> sua o labs/_shared roi: bash labs/_shared/sync-soc-tools.sh soc-shift-capstone --socq --system
Che do nhanh (phat trien): echo 0.1667 > /root/.bai18/scale  (ca 15') roi reset-ca.py. Khong co file = ca 90'.
