#!/bin/sh

# 获取当前物理网口数量 (ethX / ensX 等)
#iface_count=$(ip link show | grep -E "^[0-9]+: (eth|ens)[0-9]" | wc -l)
iface_count=$(ip link show | grep -cE "^[0-9]+: (eth|ens)[0-9]")

if [ "$iface_count" -eq 1 ]; then
  # 确认 dhcp.lan 配置存在
  #    if uci get dhcp.lan &>/dev/null; then
  if uci get dhcp.lan >/dev/null 2>&1; then
    echo "Detected single interface, disabling DHCP server..."
    uci set dhcp.lan.ignore='1'
    uci del dhcp.lan.ra
    uci del dhcp.lan.ra_flags
    uci del dhcp.lan.dhcpv6
    uci commit dhcp
  fi
fi

exit 0
