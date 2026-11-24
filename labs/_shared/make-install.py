#!/usr/bin/env python3
# Sinh labs/install-<lab>.sh (dang heredoc nhu cac file install-* hien co) tu thu muc labs/<lab>/.
# Dung:  python3 labs/_shared/make-install.py soc-privesc "mo ta 1 dong"
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
lab, desc = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
root = os.path.join(HERE, "..", lab)
MARK = "__EOF_LAB_%s__" % lab.replace("-", "_").upper()
out = ["#!/bin/bash",
       "# " + "=" * 76,
       "# %s %s" % (lab, ("- " + desc) if desc else ""),
       "# Chay tren VM:  bash install-%s.sh ; roi rebuild %s" % (lab, lab),
       "# (File sinh tu dong boi labs/_shared/make-install.py - sua ma nguon trong labs/%s/ roi sinh lai.)" % lab,
       "# " + "=" * 76,
       "set -e",
       'if [ -z "$LABTAINER_DIR" ]; then echo "LOI: chua co bien LABTAINER_DIR"; exit 1; fi',
       "LAB=$LABTAINER_DIR/labs/%s" % lab,
       'echo ">> Tao thu muc lab tai $LAB"; rm -rf "$LAB"; mkdir -p "$LAB"']
execs = []
for dp, dn, fn in os.walk(root):
    dn.sort()
    if "__pycache__" in dp:
        continue
    for f in sorted(fn):
        p = os.path.join(dp, f)
        rel = os.path.relpath(p, root)
        if f.endswith((".bak", ".pyc")) or rel.startswith("docs/giai-mau"):
            continue
        txt = open(p, encoding="utf-8").read()
        assert MARK not in txt
        out.append('mkdir -p "$LAB/%s"' % (os.path.dirname(rel) or "."))
        out.append("cat > \"$LAB/%s\" <<'%s'" % (rel, MARK))
        out.append(txt.rstrip("\n"))
        out.append(MARK)
        if os.access(p, os.X_OK) or "/_bin/" in "/" + rel or rel.endswith(".sh"):
            execs.append(rel)
out.append('echo ">> Cap quyen thuc thi + chuan hoa EOL (LF)"')
for r in execs:
    out.append('chmod +x "$LAB/%s"' % r)
out.append("find \"$LAB\" -type f -exec sed -i 's/\\r$//' {} +")
out.append('echo ">> XONG. Tiep theo:  cd \\$LABTAINER_DIR/scripts/labtainer-student && rebuild %s"' % lab)
open(os.path.join(HERE, "..", "install-%s.sh" % lab), "w").write("\n".join(out) + "\n")
print("Da sinh install-%s.sh (%d file, %d file thuc thi)" % (lab, sum(1 for l in out if l.startswith("cat >")), len(execs)))
