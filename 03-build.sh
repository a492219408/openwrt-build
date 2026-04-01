#!/usr/bin/env bash
set -Eeuo pipefail

# 放到仓库根目录的 ./logs 下
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

TS="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="$LOG_DIR/build-$TS.log"

# 生成类似 2023-04-24T14:04:54.9017916Z 的时间戳（UTC，7位小数）
iso_ts() {
  # 需要 GNU date；Ubuntu/Debian 自带
  local d
  d="$(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")" # 先拿到 9 位纳秒
  # 把 9 位截成 7 位：XXXXXXXXXZ -> XXXXXXXZ
  printf '%s\n' "$(sed -E 's/([0-9]{7})[0-9]{2}Z/\1Z/' <<<"$d")"
}

# 后台启动一次性容器（不占用前台），禁用伪终端避免花哨前缀，退出后自动删除
CID="$(docker compose run -d -T --rm builder /config/scripts/build.sh)"
echo "$CID" >"$LOG_FILE.cid" # 记录本次运行的容器ID，便于之后定位

# 把容器输出流进文件并加时间戳；跟随进程会在容器退出时自动结束
# stdbuf 保证按行刷新，避免卡在缓冲里
(
  stdbuf -oL -eL docker logs -f "$CID" 2>&1 |
    while IFS= read -r line; do
      printf '%s %s\n' "$(iso_ts)" "$line"
    done >>"$LOG_FILE"
) &
disown

# 等待容器结束，记录退出码到日志末行（也带时间戳）
(
  code="$(docker wait "$CID")"
  printf '%s EXIT CODE: %s\n' "$(iso_ts)" "$code" >>"$LOG_FILE"
) &
disown

echo "Build started at $TS"
echo "Container: $CID"
echo "File log: $LOG_FILE"
echo
echo "Follow logs:"
#echo "  docker compose logs -f builder         # 按服务看（可能包含同服务其它运行）"
echo "  docker logs -f $CID                    # 只看本次容器"
