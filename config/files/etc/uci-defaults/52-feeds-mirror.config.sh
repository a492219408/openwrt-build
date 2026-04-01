#!/bin/sh

# 使用清华大学开源软件镜像站的 OpenWrt 镜像源
sed -i 's_https\?://downloads.openwrt.org_https://mirrors.tuna.tsinghua.edu.cn/openwrt_' /etc/opkg/distfeeds.conf

exit 0