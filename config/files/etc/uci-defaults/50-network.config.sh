#!/bin/sh

# 将 LAN 改为 DHCP 客户端
uci set network.lan.proto='dhcp'
uci del network.lan.ipaddr
uci del network.lan.netmask
uci del network.lan.ip6assign
uci commit network

exit 0
