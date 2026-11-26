#!/bin/bash
# fixlocal defender (Bai 18) - chay bang user (SV khong co root; moi thu can root cai luc BUILD qua _system/).
# Chi them hook nhac gio vao .bashrc + UTF-8 de doc SOP co dau.
grep -q CA_TRUC_NHAC ~/.bashrc 2>/dev/null || cat >> ~/.bashrc <<'RC'
# --- Bai 18: nhac cua ca truc (watcher ghi ~/.ca-truc-nhac) --- CA_TRUC_NHAC
export LANG=C.UTF-8 LC_ALL=C.UTF-8
_ca_truc_nhac() {
  local f=~/.ca-truc-nhac s=~/.ca-truc-nhac.seen n m
  [ -f "$f" ] || return
  n=$(wc -l < "$f"); m=$(cat "$s" 2>/dev/null || echo 0)
  if [ "$n" -gt "$m" ]; then tail -n $((n - m)) "$f" | sed 's/^/\x1b[1;33m>> /;s/$/\x1b[0m/'; echo "$n" > "$s"; fi
}
PROMPT_COMMAND="_ca_truc_nhac${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
RC
exit 0
