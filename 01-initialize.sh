#!/usr/bin/env bash
set -Eeuo pipefail

docker compose run --rm builder /config/scripts/initialize.sh