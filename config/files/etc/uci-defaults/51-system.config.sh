#!/bin/sh

# 设置系统时区
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci set system.ntp.server="192.168.1.1 $(uci get system.ntp.server)"
uci commit system

# 重启系统服务，使配置生效
/etc/init.d/system restart

uci set uhttpd.main.redirect_https=1
uci commit uhttpd
service uhttpd reload

exit 0
