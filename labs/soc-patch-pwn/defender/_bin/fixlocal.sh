#!/bin/bash
# Defender: tao san wordlist de crack MD5 cua admin (he B) - gom nhieu mat khau pho bien + mat khau that.
# SV crack vd: while read p; do echo "$(printf %s "$p"|md5sum|cut -d' ' -f1) $p"; done < wordlist.txt | grep <hash>
cat > /home/ubuntu/wordlist.txt <<'WL'
123456
password
admin
admin123
root
toor
qwerty
letmein
welcome
monkey
dragon
iloveyou
sunshine
password1
123456789
football
abc123
111111
princess
flower
hottie
loveme
zaq1zaq1
password123
qwerty123
secret
baseball
superman
trustno1
whatever
letmein99
hunter2
changeme
P@ssw0rd
summer2024
spring2024
WL
chmod 644 /home/ubuntu/wordlist.txt 2>/dev/null || true
exit 0
