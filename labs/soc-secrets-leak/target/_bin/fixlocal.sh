#!/bin/bash
# target (web + MariaDB, lo .git/backup), chay lan dau voi quyen 'ubuntu'. $1 = mat khau sudo.
PW="$1"
S(){ echo "$PW" | sudo -S "$@"; }

# 1) Dung toan bo app bang root (setup_app.sh nam o /home/ubuntu). Log de debug: /tmp/setup_app.log
S bash /home/ubuntu/setup_app.sh > /tmp/setup_app.log 2>&1

# 2) Wazuh agent: doc auth.log cua app (+ access.log neu cau hinh chua co), bat FIM, tat SCA
CONF=/var/ossec/etc/ossec.conf
LF_ACC='<localfile><log_format>apache</log_format><location>/var/log/apache2/access.log</location></localfile>'
LF_AUTH='<localfile><log_format>syslog</log_format><location>/var/log/webapp/auth.log</location></localfile>'
FIM='<directories realtime="yes" check_all="yes">/var/www/html,/var/www/app</directories>'
LF="$LF_AUTH"
S grep -q 'apache2/access.log' "$CONF" || LF="${LF_ACC}${LF_AUTH}"
# ossec.conf co the co NHIEU khoi </ossec_config>: chi chen vao khoi DAU TIEN (0,/re/) de khong bi trung
S sed -i "0,/<\/ossec_config>/ s#</ossec_config>#${LF}</ossec_config>#" "$CONF" >> /tmp/agent_cfg.log 2>&1
S sed -i "s#<syscheck>#<syscheck>\n    ${FIM}#" "$CONF" >> /tmp/agent_cfg.log 2>&1
S sed -i '/<sca>/,/<\/sca>/ s#<enabled>yes</enabled>#<enabled>no</enabled>#' "$CONF" >> /tmp/agent_cfg.log 2>&1
S systemctl restart wazuh-agent >> /tmp/agent_cfg.log 2>&1 || S service wazuh-agent restart >> /tmp/agent_cfg.log 2>&1 || true
