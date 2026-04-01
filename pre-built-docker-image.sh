#!/usr/bin/env bash
set -Eeuo pipefail

docker build . -t openwrt-build:24.04
