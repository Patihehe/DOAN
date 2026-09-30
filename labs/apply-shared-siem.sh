#!/bin/bash
# ============================================================================
# Chuyen siem cua soc-ssh-defense sang dung image nen soc-wazuh:
#  - Dockerfile: FROM localhost:5000/soc-wazuh (Wazuh da cai san)
#  - fixlocal: chi chown thu muc CAN GHI (nho) + restart (khong chown /usr/share)
# Co sao luu ban cu (.bak) de revert neu can.
#
# Dung:  bash apply-shared-siem.sh
# ============================================================================
set -e
if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co \$LABTAINER_DIR"; exit 1; fi
LAB=$LABTAINER_DIR/labs/soc-ssh-defense
DF="$LAB/dockerfiles/Dockerfile.soc-ssh-defense.siem.student"
FX="$LAB/siem/_bin/fixlocal.sh"

echo ">> Sao luu ban cu (.bak)"
cp "$DF" "$DF.bak" 2>/dev/null || true
cp "$FX" "$FX.bak" 2>/dev/null || true

cat > "$DF" <<'SIEM_DF'
#
# siem - dung image nen soc-wazuh (Wazuh cai san, /usr/share world-readable)
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
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
SIEM_DF

cat > "$FX" <<'SIEM_FIX'
#!/bin/bash
# soc-wazuh da cai san Wazuh + /usr/share, /etc world-readable (doc duoc du owner=root).
# /var/lib van owner wazuh-indexer (ghi duoc) -> KHONG chown gi.
# TUYET DOI khong chown /var/lib luc dang chay: se lam hong node.lock cua OpenSearch.
# systemd tu khoi dong indexer/manager/filebeat/dashboard luc boot.
exit 0
SIEM_FIX

chmod +x "$FX"
sed -i 's/\r$//' "$FX" "$DF"
echo ">> Done. Da doi siem -> FROM soc-wazuh (ban cu luu o *.bak)."
echo ">> Tiep theo:  cd \$LABTAINER_DIR/scripts/labtainer-student && rebuild soc-ssh-defense"
echo ">> Revert neu can:  mv $DF.bak $DF ; mv $FX.bak $FX"
