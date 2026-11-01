#!/bin/bash
# soc-secrets-leak - siem: cai decoder + rule NEN cho log cua web app (rule id 199xxx).
# Chay bang ROOT, o nen (goi tu fixlocal.sh). Log: /var/log/lab_rules.log
# QUY UOC: id 199000-199999 danh cho lab. Rule cua sinh vien phai dung id 100000-198999.
LOG=/var/log/lab_rules.log
echo "[lab_rules] bat dau $(date)" > "$LOG"

# 1) Cho Wazuh da san sang (thu muc rules/decoders co san), toi da ~5 phut
for i in $(seq 1 60); do
  [ -f /var/ossec/etc/rules/local_rules.xml ] && [ -f /var/ossec/etc/decoders/local_decoder.xml ] && break
  sleep 5
done
if [ ! -f /var/ossec/etc/rules/local_rules.xml ]; then
  echo "[lab_rules] LOI: khong thay /var/ossec/etc/rules/local_rules.xml" >> "$LOG"; exit 1
fi
# cho analysisd chay (khong bat buoc, toi da ~2 phut)
for i in $(seq 1 24); do
  /var/ossec/bin/wazuh-control status 2>/dev/null | grep -q "wazuh-analysisd is running" && break
  sleep 5
done

# 2) Decoder: dong log dang syslog "Oct 30 12:34:56 target corpportal: ACTION user=<ten> ip=<ip> [rows=N]"
#    Ten chuong trinh 'corpportal' phai KHONG trung decoder co san (da gap: 'webapp' bi decoder Barracuda chiem;
#    dong bat dau bang ngay YYYY-MM-DD thi bi 'windows-date-format' chiem).
cat > /var/ossec/etc/decoders/199_webapp_decoder.xml <<'XML'
<decoder name="corpportal">
  <program_name>^corpportal$</program_name>
</decoder>

<decoder name="corpportal-auth">
  <parent>corpportal</parent>
  <regex>^(\w+) user=(\S+) ip=(\S+)</regex>
  <order>action,srcuser,srcip</order>
</decoder>
XML

# 3) Rule nen (id 199001-199003)
cat > /var/ossec/etc/rules/199_webapp_rules.xml <<'XML'
<group name="local,webapp,">
  <rule id="199001" level="3">
    <decoded_as>corpportal</decoded_as>
    <match>LOGIN_OK</match>
    <description>Webapp: dang nhap thanh cong</description>
  </rule>

  <rule id="199002" level="5">
    <decoded_as>corpportal</decoded_as>
    <match>LOGIN_FAIL</match>
    <description>Webapp: dang nhap that bai</description>
  </rule>

  <rule id="199003" level="7">
    <decoded_as>corpportal</decoded_as>
    <match>EXPORT</match>
    <description>Webapp: xuat du lieu khach hang</description>
  </rule>
</group>
XML

# 4) Quyen file giong file local mac dinh (manager phai doc duoc)
for f in /var/ossec/etc/rules/199_webapp_rules.xml:/var/ossec/etc/rules/local_rules.xml \
         /var/ossec/etc/decoders/199_webapp_decoder.xml:/var/ossec/etc/decoders/local_decoder.xml; do
  new="${f%%:*}"; ref="${f##*:}"
  chown --reference="$ref" "$new" 2>/dev/null || chown wazuh:wazuh "$new" 2>/dev/null || true
  chmod --reference="$ref" "$new" 2>/dev/null || chmod 660 "$new"
done

# 4b) Tat SCA (Security Configuration Assessment) tren manager: sinh hang tram alert 19xxx lam nhieu dashboard
sed -i '/<sca>/,/<\/sca>/ s#<enabled>yes</enabled>#<enabled>no</enabled>#' /var/ossec/etc/ossec.conf 2>>"$LOG"

# 5) Nap lai
systemctl restart wazuh-manager >> "$LOG" 2>&1 || service wazuh-manager restart >> "$LOG" 2>&1 || true
echo "[lab_rules] xong $(date)" >> "$LOG"
