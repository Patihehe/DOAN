#!/bin/bash
# ============================================================================
# Chuyen siem cua MOT lab sang dung image nen soc-wazuh (tiet kiem dung luong):
#  - Dockerfile: FROM localhost:5000/soc-wazuh  (Wazuh da cai san)
#  - ENTRYPOINT (qua /entrypoint.sh): KHOI PHUC QUYEN cac user Wazuh bi reset ve root
#    trong luc layer image chung, chay o PID 1 TRUOC systemd (OpenSearch chua chay ->
#    chown /var/lib an toan, khong hong node.lock), roi exec /sbin/init de systemd
#    khoi dong DAY DU indexer + manager + dashboard + filebeat.
#  - fixlocal: khong chown gi (viec do da lam o entrypoint truoc init).
# Co sao luu ban cu (.bak) de revert.
#
# Dung:  bash apply-shared-siem.sh [ten-lab]      (mac dinh: soc-ssh-defense)
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co \$LABTAINER_DIR"; exit 1; fi
LABNAME="${1:-soc-ssh-defense}"
LAB="$LABTAINER_DIR/labs/$LABNAME"
DF="$LAB/dockerfiles/Dockerfile.$LABNAME.siem.student"
FX="$LAB/siem/_bin/fixlocal.sh"
[ -f "$DF" ] || { echo "LOI: khong thay $DF"; exit 1; }

echo ">> Lab: $LABNAME"
echo ">> Sao luu ban GOC (.bak) - chi khi CHUA co (chay lai nhieu lan khong de len ban goc)"
[ -f "$DF.bak" ] || cp "$DF" "$DF.bak" 2>/dev/null || true
[ -f "$FX.bak" ] || cp "$FX" "$FX.bak" 2>/dev/null || true

cat > "$DF" <<'SIEM_DF'
#
# siem - dung image nen soc-wazuh (Wazuh cai san). Entrypoint khoi phuc quyen Wazuh truoc init.
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
# Cho prestop doc alerts + agent_control khong can mat khau (de cham diem detection)
RUN echo 'ubuntu ALL=(ALL) NOPASSWD: /bin/cat /var/ossec/logs/alerts/alerts.log, /usr/bin/cat /var/ossec/logs/alerts/alerts.log, /var/ossec/bin/agent_control' > /etc/sudoers.d/labtainer-wazuh \
    && chmod 440 /etc/sudoers.d/labtainer-wazuh
#
# === Dong bo mui gio voi VM (ICT = UTC+7). Doi TZ neu VM dung mui gio khac ===
ENV TZ=Asia/Ho_Chi_Minh
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* || true
#
# === Entrypoint: khoi phuc quyen cac user Wazuh (bi reset ve root khi layer image chung).
#     Chay o PID 1 TRUOC systemd -> OpenSearch chua chay -> chown /var/lib an toan (khong hong node.lock),
#     roi exec /sbin/init -> systemd khoi dong day du indexer + manager + dashboard + filebeat. ===
RUN printf '%s\n' \
  '#!/bin/bash' \
  '# Khoi phuc quyen cac user Wazuh truoc khi systemd start cac service.' \
  'for u in wazuh-indexer wazuh-dashboard; do' \
  '  id "$u" >/dev/null 2>&1 || continue' \
  '  chown -R "$u:$u" /usr/share/$u /var/lib/$u /var/log/$u /etc/$u /run/$u 2>/dev/null' \
  'done' \
  '# filebeat + wazuh-manager chay root -> khong can chown' \
  '# Don trang thai agent cu tu anh nen (counter rids + client.keys) -> agent enroll lai sach,' \
  '# tranh loi "counter mismatch" lam agent Disconnected khi dung image chung.' \
  'rm -f /var/ossec/queue/rids/* /var/ossec/etc/client.keys /var/ossec/queue/agents-timestamp 2>/dev/null' \
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
CMD ["/entrypoint.sh"]
SIEM_DF

cat > "$FX" <<'SIEM_FIX'
#!/bin/bash
# soc-wazuh da cai san Wazuh. Quyen cac user Wazuh duoc khoi phuc o /entrypoint.sh (PID 1, TRUOC systemd),
# nen o day KHONG chown gi (chown /var/lib luc dang chay se hong node.lock cua OpenSearch).
# systemd tu khoi dong indexer/manager/filebeat/dashboard luc boot.
exit 0
SIEM_FIX

chmod +x "$FX"
sed -i 's/\r$//' "$FX" "$DF"
echo ">> Done. Da doi siem cua '$LABNAME' -> FROM soc-wazuh + entrypoint khoi phuc quyen (ban cu luu *.bak)."
echo ">> Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild $LABNAME"
echo ">> Revert neu can:  mv $DF.bak $DF ; mv $FX.bak $FX"
