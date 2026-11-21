#!/bin/sh

CONFIG_DIR="/etc/wdtt"
WDTT_SUBNET="10.66.66.0/24"
RAW_SUBNET="10.70.0.0/16"
mkdir -p "$CONFIG_DIR" /etc/wdtt-xray /var/log/wdtt-xray

# Создание стартового пользователя при первом запуске на пустой базе
if [ ! -f "$CONFIG_DIR/panel.db" ] && [ ! -f "$CONFIG_DIR/passwords.json" ]; then
    PASS="${START_PASSWORD:-StartPass123}"
    cat << EOM > "$CONFIG_DIR/passwords.json"
{
  "passwords": {
    "$PASS": {
      "password": "$PASS",
      "active": true
    }
  }
}
EOM
fi

# Параметры ядра для форвардинга и прозрачного перенаправления в Xray
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
sysctl -w net.ipv4.conf.all.route_localnet=1 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.route_localnet=1 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true

# Перехват сигнала остановки контейнера (кнопка Stop в MikroTik)
RUNNING=1
trap 'RUNNING=0; killall -TERM wdtt-app xray 2>/dev/null; exit 0' TERM INT

# Автозапуск Xray при старте контейнера (если установлен)
/usr/bin/systemctl start xray

# Цикл работы и перезапуска сервера при нажатии "Перезапуск VPN" в панели
while [ "$RUNNING" -eq 1 ]; do
    ip link show wdtt0 >/dev/null 2>&1 && ip link del wdtt0 2>/dev/null || true
    ip link show wdtt-raw >/dev/null 2>&1 && ip link del wdtt-raw 2>/dev/null || true

    # Правила NAT и MSS для классического режима WDTT (10.66.66.0/24)
    iptables -t nat -C POSTROUTING -s "$WDTT_SUBNET" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$WDTT_SUBNET" -j MASQUERADE
    iptables -t mangle -C FORWARD -s "$WDTT_SUBNET" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    iptables -t mangle -A FORWARD -s "$WDTT_SUBNET" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

    # Правила NAT, FORWARD и MSS для режима RAW (10.70.0.0/16)
    iptables -t nat -C POSTROUTING -s "$RAW_SUBNET" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$RAW_SUBNET" -j MASQUERADE
    iptables -C FORWARD -i wdtt-raw -j ACCEPT 2>/dev/null || iptables -I FORWARD -i wdtt-raw -j ACCEPT
    iptables -C FORWARD -o wdtt-raw -j ACCEPT 2>/dev/null || iptables -I FORWARD -o wdtt-raw -j ACCEPT
    iptables -t mangle -C FORWARD -s "$RAW_SUBNET" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    iptables -t mangle -A FORWARD -s "$RAW_SUBNET" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

    /usr/local/bin/wdtt-app -config-dir "$CONFIG_DIR" &
    APP_PID=$!
    wait "$APP_PID"

    [ "$RUNNING" -eq 0 ] && break
    sleep 1
done
