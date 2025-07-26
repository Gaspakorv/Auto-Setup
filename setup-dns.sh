#!/bin/bash

# ========================================
# DNS Auto-Setup Script for Ubuntu
# Domain: techinnovate.dpdns.org
# Name Servers: ns1 & ns2 (same IP)
# ========================================

DOMAIN="techinnovate.dpdns.org"
NS1="ns1.${DOMAIN}"
NS2="ns2.${DOMAIN}"
VPS_IP="50.116.10.187"
ZONE_DIR="/etc/bind/zones"
ZONE_FILE="${ZONE_DIR}/db.${DOMAIN}"
SERIAL=$(date +%Y%m%d01)

echo "🚀 Starting DNS setup for ${DOMAIN}..."

# --- Check for root ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo"
  exit 1
fi

# --- Update & Install BIND9 ---
echo "📦 Installing BIND9..."
apt update -qq && apt install bind9 bind9utils -y -qq || {
  echo "❌ Failed to install BIND9"
  exit 1
}

# --- Set hostname ---
hostnamectl set-hostname "$NS1"
echo "🔧 Hostname set to $NS1"

# --- Create zone directory ---
mkdir -p "$ZONE_DIR"

# --- Configure zone: db.techinnovate.dpdns.org ---
cat > "$ZONE_FILE" << EOF
\$TTL    86400
@       IN      SOA     ${NS1}. admin.${DOMAIN}. (
                        ${SERIAL}       ; Serial
                        3600            ; Refresh
                        1800            ; Retry
                        604800          ; Expire
                        86400 )         ; Negative Cache TTL

; Name Servers
@       IN      NS      ${NS1}.
@       IN      NS      ${NS2}.

; A records for name servers
ns1     IN      A       ${VPS_IP}
ns2     IN      A       ${VPS_IP}

; A records for domain
@       IN      A       ${VPS_IP}
www     IN      A       ${VPS_IP}
EOF
echo "✅ Zone file created: $ZONE_FILE"

# --- Add zone to BIND config ---
cat > /etc/bind/named.conf.local << EOF
zone "${DOMAIN}" {
    type master;
    file "${ZONE_FILE}";
};
EOF
echo "✅ Zone added to BIND config"

# --- Secure BIND options (disable recursion) ---
cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    recursion no;
    allow-transfer { none; };
    allow-query { any; };
    dnssec-validation auto;
    listen-on { any; };
    listen-on-v6 { any; };
};
EOF
echo "✅ BIND options configured (authoritative-only)"

# --- Test config ---
echo "🔍 Testing configuration..."
named-checkconf || { echo "❌ named.conf error"; exit 1; }
named-checkzone "$DOMAIN" "$ZONE_FILE" || { echo "❌ Zone file error"; exit 1; }

# --- Restart BIND ---
systemctl reload-or-restart bind9
systemctl enable bind9 2>/dev/null || true
echo "✅ BIND9 restarted and enabled"

# --- Open firewall (UFW) ---
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
  ufw allow 53 >/dev/null 2>&1 && echo "🔐 UFW: Port 53 (DNS) allowed"
fi

# --- Final Instructions ---
echo ""
echo "🎉 SUCCESS! DNS Server Setup Complete"
echo ""
echo "📌 NEXT STEPS (Manual - REQUIRED):"
echo "1. Go to https://dpdns.org and log in"
echo "2. Register Glue Records (Custom Nameservers):"
echo "   - Host: ns1.techinnovate.dpdns.org → IP: 50.116.10.187"
echo "   - Host: ns2.techinnovate.dpdns.org → IP: 50.116.10.187"
echo "3. Set your domain nameservers to:"
echo "   - ns1.techinnovate.dpdns.org"
echo "   - ns2.techinnovate.dpdns.org"
echo ""
echo "🔍 Test DNS after setup:"
echo "   dig @ns1.techinnovate.dpdns.org techinnovate.dpdns.org"
echo "   dig @ns2.techinnovate.dpdns.org techinnovate.dpdns.org"