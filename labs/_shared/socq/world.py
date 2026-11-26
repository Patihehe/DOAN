#!/usr/bin/env python3
# ============================================================================
# world.py - "the gioi" ca nhan hoa cua mot SV: may, IP, nhan su, ten file, cong...
# Moi gia tri ngau nhien deu lay tu rng (random.Random(seed)) -> tai lap duoc khi biet seed.
# Dung chung cho ctx.py, cases.py, chain.py va bo sinh tap kiem tra.
# ============================================================================
import random

HO = ["Nguyen", "Tran", "Le", "Pham", "Hoang", "Vu", "Vo", "Dang", "Bui", "Do", "Ngo", "Duong", "Ly"]
DEM = ["Van", "Thi", "Minh", "Duc", "Thanh", "Ngoc", "Quang", "Thu", "Hoai", "Gia", "Bao", "Anh"]
TEN = ["An", "Binh", "Chi", "Dung", "Giang", "Ha", "Hieu", "Hung", "Khanh", "Lam", "Linh", "Long",
       "Mai", "Nam", "Phong", "Phuc", "Quan", "Son", "Tam", "Thao", "Trang", "Tuan", "Viet", "Yen"]

# (ten, vai tro, muc quan trong) - web-shop co dinh la trung tam chuoi tan cong
HOSTS = [
    ("web-shop", "may chu web ban hang", "Cao"),
    ("db-core", "co so du lieu khach hang", "Cao"),
    ("ad-01", "may chu xac thuc", "Cao"),
    ("mail-01", "may chu thu", "TB"),
    ("file-01", "may chu file noi bo", "TB"),
    ("hr-app", "ung dung nhan su", "TB"),
    ("erp-01", "ung dung ke toan", "TB"),
    ("jump-01", "may trung gian quan tri", "TB"),
    ("web-staging", "moi truong thu nghiem web", "Thap"),
    ("ws-ketoan-03", "may tram ke toan", "Thap"),
    ("ws-kinhdoanh-07", "may tram kinh doanh", "Thap"),
    ("ws-nhansu-02", "may tram nhan su", "Thap"),
    ("ws-marketing-05", "may tram marketing", "Thap"),
    ("ws-kythuat-11", "may tram ky thuat", "Thap"),
    ("ws-cskh-04", "may tram cham soc khach hang", "Thap"),
    ("ws-kho-09", "may tram kho van", "Thap"),
    ("ws-phaply-06", "may tram phap ly", "Thap"),
    ("print-01", "may chu in", "Thap"),
]
INFRA = [("siem", "SIEM Wazuh", "Cao"), ("dns-01", "DNS noi bo", "Cao")]

WEBSHELL_NAMES = ["avatar_%d.phtml", "img_%d.phtml", "thumb_%d.phtml", "logo%d.phtml", "cache_%d.phtml"]
CMD_PARAMS = ["zq", "x", "p", "c0", "data", "q1", "_", "k", "act", "img"]   # KHONG dung 'cmd' (luat cu bat 'cmd=')
APPROVED_UPLOAD_SCRIPTS = ["resize.php", "thumb.php", "crop.php"]
BACKUP_PORTS = [9102, 9103, 8400, 10050]
EXFIL_SLD = ["cdn-sync", "img-cache", "telemetry-svc", "static-edge", "update-check"]
EXFIL_TLD = ["net", "info", "xyz", "top"]
AV_VENDORS = [("Bkav", "bkav-cloud.vn"), ("Kaspersky", "ksn-check.kaspersky.com"), ("ESET", "e5.sk.eset.com")]
MON_AGENTS = [("zabbix_agent2", "/opt/zabbix/bin/zabbix_agent2-sh-collector"),
              ("node_exporter", "/opt/prom/bin/node_exporter_shellcheck")]


class World:
    def __init__(self, rng):
        self.rng = rng
        self._used_last_octets = set()     # IOC so (E) phai DUY NHAT trong ca -> khong doan nham
        self._used_ips = set()
        self.subnet_srv = "10.%d.%d" % (rng.randint(10, 60), rng.randint(1, 50))
        self.subnet_ws = "10.%d.%d" % (rng.randint(61, 120), rng.randint(51, 99))
        self.hosts = {}
        for name, role, crit in HOSTS + INFRA:
            net = self.subnet_ws if name.startswith("ws-") or name == "print-01" else self.subnet_srv
            self.hosts[name] = {"name": name, "role": role, "crit": crit, "ip": self._new_ip(net)}
        self.ip2host = {h["ip"]: n for n, h in self.hosts.items()}
        # nhan su: emp#### duy nhat
        self.staff = []
        ids = rng.sample(range(1000, 9999), 40)
        for i in ids:
            self.staff.append({"user": "emp%d" % i, "id": i,
                               "name": "%s %s %s" % (rng.choice(HO), rng.choice(DEM), rng.choice(TEN))})
        # chuoi tan cong
        self.attacker_ip = self.new_ext_ip()      # IP ke tan cong (SQLi, webshell)
        self.c2_ip = self.new_ext_ip()
        self.c2_port = rng.choice([443, 8443, 4443, 9443])
        self.exfil_domain = "%s-%s.%s" % (rng.choice(EXFIL_SLD), "".join(rng.choice("abcdefghjkmnpqrstuvwxyz") for _ in range(4)), rng.choice(EXFIL_TLD))
        self.webshell = rng.choice(WEBSHELL_NAMES) % rng.randint(10, 99)
        self.cmd_params = rng.sample(CMD_PARAMS, 5)
        self.upload_dir = "/uploads/"
        self.approved_script = rng.choice(APPROVED_UPLOAD_SCRIPTS)
        # dot trien khai agent sao luu (nguyen nhan bao): 2-3 may sao luu, TAT CA nam trong CHG.
        # Nguon duy nhat cua bao KHONG nam trong CHG la web-shop (C5) - dung goi y cap 2 cua kich ban.
        self.backup_hosts = []
        for k in range(rng.randint(2, 3)):
            name = "bk-%02d" % (k + 1)
            self.hosts[name] = {"name": name, "role": "may chu sao luu", "crit": "TB", "ip": self._new_ip(self.subnet_srv)}
            self.backup_hosts.append(name)
        self.backup_port = rng.choice(BACKUP_PORTS)
        self.ip2host = {h["ip"]: n for n, h in self.hosts.items()}
        self.av = rng.choice(AV_VENDORS)
        self.mon = rng.choice(MON_AGENTS)

    # ---------------------------------------------------------------- IP
    def _new_ip(self, net):
        while True:
            o = self.rng.randint(11, 249)
            ip = "%s.%d" % (net, o)
            if ip not in self._used_ips and o not in self._used_last_octets:
                self._used_ips.add(ip)
                self._used_last_octets.add(o)
                return ip

    def new_ext_ip(self):
        """IP ngoai, octet cuoi DUY NHAT (dung lam bang chung E)."""
        while True:
            a = self.rng.choice([45, 91, 103, 141, 176, 185, 193, 212])
            ip = "%d.%d.%d.%d" % (a, self.rng.randint(1, 254), self.rng.randint(1, 254), self.rng.randint(11, 249))
            o = int(ip.rsplit(".", 1)[1])
            if ip not in self._used_ips and o not in self._used_last_octets:
                self._used_ips.add(ip)
                self._used_last_octets.add(o)
                return ip

    def octet(self, ip):
        return int(ip.rsplit(".", 1)[1])

    def ip(self, host):
        return self.hosts[host]["ip"]

    def crit(self, host):
        return self.hosts[host]["crit"]

    def hosts_by_crit(self, crit, exclude=()):
        return [n for n, h in self.hosts.items()
                if h["crit"] == crit and n not in exclude and n not in ("siem", "dns-01") and not n.startswith("bk-")]

    def pick_host(self, crits, exclude=()):
        """Chon may cho MOT ticket hang doi; moi may toi da 1 ticket (tranh 2 ban ghi ngu canh cung may)."""
        used = getattr(self, "_used_hosts", set())
        self._used_hosts = used
        cand = [h for c in crits for h in self.hosts_by_crit(c, exclude=tuple(exclude) + tuple(used))]
        h = self.rng.choice(cand)
        used.add(h)
        return h

    def take_staff(self):
        return self.staff.pop(self.rng.randrange(len(self.staff)))

    def internal_ips(self):
        return [h["ip"] for n, h in self.hosts.items() if n not in ("siem",)]

    def public(self):
        """Phan KHONG nhay cam (de ghi log seed / gui defender): khong co dap an."""
        return {"hosts": self.hosts, "backup_port": self.backup_port, "approved_script": self.approved_script}


def make(seed):
    return World(random.Random(seed))
