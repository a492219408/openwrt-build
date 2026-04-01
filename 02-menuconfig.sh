#!/usr/bin/env bash
set -Eeuo pipefail

docker compose run --rm builder /config/scripts/menuconfig.sh