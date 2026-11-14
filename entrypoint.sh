#!/bin/sh

CONFIG_DIR="/etc/wdtt"
WDTT_SUBNET="10.66.66.0/24"
mkdir -p "$CONFIG_DIR"

# Если база panel.db ещё не создана, создаём стартового пользователя из переменной START_PASSWORD
if [ ! -f "$CONFIG_DIR/panel.db" ] && [ ! -f "$CONFIG_DIR/passwords.json" ]; then
    PASS="${START_PASSWORD:-StartPass123}"
    cat << EOF > "$CONFIG_DIR/passwords.json"
{
  "passwords": {
    "$PASS": {
      "password": "$PASS",
      "active": true
    }
  }
}
EOF
fi

ip link show wdtt0 >/dev/null 2>&1 && ip link del wdtt0 2>/dev/null || true
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

iptables -t nat -C POSTROUTING -s "$WDTT_SUBNET" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s "$WDTT_SUBNET" -j MASQUERADE

iptables -t mangle -C FORWARD -s "$WDTT_SUBNET" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A FORWARD -s "$WDTT_SUBNET" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

exec /usr/local/bin/wdtt-app -config-dir "$CONFIG_DIR"
