#!/usr/bin/env python3

import os
import sys
import subprocess
from datetime import datetime

# Configuration
DOMAIN = "techinnovate.dpdns.org"
NS1 = f"ns1.{DOMAIN}"
NS2 = f"ns2.{DOMAIN}"
VPS_IP = "50.116.10.187"
ZONE_DIR = "/etc/bind/zones"
ZONE_FILE = f"{ZONE_DIR}/db.{DOMAIN}"
SERIAL = datetime.now().strftime("%Y%m%d01")

def run(cmd, desc):
    """Run shell command or exit."""
    print(f"🔧 {desc}...")
    result = subprocess.run(cmd, shell=True, text=True)
    if result.returncode != 0:
        print(f"❌ Failed: {cmd}")
        sys.exit(1)

def main():
    print("🚀 Starting DNS setup for", DOMAIN)

    # Check root
    if os.geteuid() != 0:
        print("❌ Please run as root or with sudo")
        sys.exit(1)

    # Update & Install BIND
    run("apt update -qq && apt install bind9 bind9utils -y -qq", "Install BIND9")

    # Set hostname
    run(f"hostnamectl set-hostname {NS1}", "Set hostname")

    # Create zone directory
    os.makedirs(ZONE_DIR, exist_ok=True)

    # Zone file content
    zone_content = f'''$TTL    86400
@       IN      SOA     {NS1}. admin.{DOMAIN}. (
                        {SERIAL}        ; Serial
                        3600            ; Refresh
                        1800            ; Retry
                        604800          ; Expire
                        86400 )         ; Negative Cache TTL

; Name Servers
@       IN      NS      {NS1}.
@       IN      NS      {NS2}.

; A records for name servers
ns1     IN      A       {VPS_IP}
ns2     IN      A       {VPS_IP}

; A records for domain
@       IN      A       {VPS_IP}
www     IN      A       {VPS_IP}
'''

    # Write zone file
    with open(ZONE_FILE, 'w') as f:
        f.write(zone_content)
    print(f"✅ Zone file created: {ZONE_FILE}")

    # Update named.conf.local
    conf_local = f'''
zone "{DOMAIN}" {{
    type master;
    file "{ZONE_FILE}";
}};
'''
    with open("/etc/bind/named.conf.local", 'w') as f:
        f.write(conf_local)
    print("✅ Zone added to BIND config")

    # BIND options
    options = '''
options {
    directory "/var/cache/bind";
    recursion no;
    allow-transfer { none; };
    allow-query { any; };
    dnssec-validation auto;
    listen-on { any; };
    listen-on-v6 { any; };
};
'''
    with open("/etc/bind/named.conf.options", 'w') as f:
        f.write(options)
    print("✅ BIND options configured")

    # Test config
    run("named-checkconf", "Check BIND config")
    run(f"named-checkzone {DOMAIN} {ZONE_FILE}", "Check zone syntax")

    # Restart BIND
    run("systemctl reload-or-restart bind9", "Restart BIND9")
    run("systemctl enable bind9", "Enable BIND on boot")

    # Firewall
    if os.system("ufw status | grep -q active") == 0:
        run("ufw allow 53", "Open DNS port (UFW)")

    # Final instructions
    print("\n" + "🎉 SUCCESS! DNS Server Setup Complete".center(60))
    print("\n📌 NEXT STEPS (Manual - REQUIRED):")
    print("1. Go to https://dpdns.org and log in")
    print("2. Register Glue Records:")
    print("   - ns1.techinnovate.dpdns.org → 50.116.10.187")
    print("   - ns2.techinnovate.dpdns.org → 50.116.10.187")
    print("3. Set domain nameservers to:")
    print("   - ns1.techinnovate.dpdns.org")
    print("   - ns2.techinnovate.dpdns.org")
    print("\n🔍 Test:")
    print("   dig @ns1.techinnovate.dpdns.org techinnovate.dpdns.org")
    print("   dig @ns2.techinnovate.dpdns.org techinnovate.dpdns.org")

if __name__ == "__main__":
    main()