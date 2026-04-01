#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/openwrt/openwrt.git"
REPO_BRANCH="v25.12.2"
OFFICIAL_FEEDS_VERSION=";openwrt-25.12"
CLASH_CORE_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
CLASH_CORE_DEST_PATH="./files/etc/openclash/core/clash_meta"

log() {
  echo "[initialize] $*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "错误: 缺少命令 $cmd" >&2
    exit 1
  fi
}

apply_official_suffix() {
  local f="$1" name url suffix
  [ -n "${OFFICIAL_FEEDS_VERSION:-}" ] || return 0

  case "$OFFICIAL_FEEDS_VERSION" in
  ';'* | '^'*) suffix="$OFFICIAL_FEEDS_VERSION" ;;
  *) suffix=";$OFFICIAL_FEEDS_VERSION" ;;
  esac

  for name in packages luci routing telephony video; do
    url="$(awk -v n="$name" '$1=="src-git" && $2==n {u=$3; sub(/[;^].*$/,"",u); print u; exit}' "$f")"
    [ -n "$url" ] || continue
    sed -i -E "s|^([[:space:]]*src-git[[:space:]]+$name[[:space:]]+)[^;^[:space:]]+([;^][^[:space:]]*)?|\1${url}${suffix}|" "$f"
  done
}

clone_openwrt() {
  if [ ! -d "openwrt" ]; then
    git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" openwrt
  else
    log "目录 openwrt 已存在，跳过克隆"
  fi

  cd openwrt || {
    echo "错误: 无法进入 openwrt 目录，脚本终止" >&2
    exit 1
  }
}

prepare_feeds_conf() {
  cp -f feeds.conf.default feeds.conf
  apply_official_suffix feeds.conf
}

clone_repo_if_missing() {
  local url="$1" dest="$2" branch="$3"
  if [ -d "$dest" ]; then
    log "目录 $dest 已存在，跳过"
    return 0
  fi
  git clone --single-branch --depth=1 --branch "$branch" "$url" "$dest"
}

clone_subdir_if_missing() {
  local url="$1" branch="$2" subdir="$3" dest="$4"
  local tmp_dir

  if [ -d "$dest" ]; then
    log "目录 $dest 已存在，跳过"
    return 0
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  git clone --single-branch --depth=1 --branch "$branch" "$url" "$tmp_dir/repo"
  if [ ! -d "$tmp_dir/repo/$subdir" ]; then
    echo "错误: $url 中不存在子目录 $subdir" >&2
    return 1
  fi
  mv "$tmp_dir/repo/$subdir" "$dest"
}

install_third_party_packages() {
  cd package

  clone_repo_if_missing "https://github.com/jerrykuku/luci-theme-argon.git" "luci-theme-argon" "v2.4.3"
  clone_repo_if_missing "https://github.com/jerrykuku/luci-app-argon-config.git" "luci-app-argon-config" "v0.9"
  clone_subdir_if_missing "https://github.com/vernesong/OpenClash.git" "v0.47.075" "luci-app-openclash" "luci-app-openclash"
  clone_subdir_if_missing "https://github.com/sundaqiang/openwrt-packages.git" "master" "luci-app-wolplus" "luci-app-wolplus"

  cd ..
}

copy_custom_files() {
  if [ -d "/config/files" ]; then
    rm -rf ./files
    cp -r /config/files ./
  fi
}

detect_arch() {
  local arch
  if command -v dpkg >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture)"
  elif command -v apk >/dev/null 2>&1; then
    arch="$(apk --print-arch)"
  else
    arch="$(uname -m)"
  fi

  case "$arch" in
  x86_64 | amd64) echo amd64 ;;
  aarch64 | arm64) echo arm64 ;;
  armv7l | armv7 | armhf) echo armv7 ;;
  armv6l | armv6) echo armv6 ;;
  i386 | i686 | x86) echo 386 ;;
  mips64) echo mips64 ;;
  mips64le) echo mips64le ;;
  mipsle) echo mipsle ;;
  mips) echo mips ;;
  riscv64) echo riscv64 ;;
  ppc64le | ppc64el) echo ppc64le ;;
  s390x) echo s390x ;;
  *) echo "$arch" ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
  Linux) echo linux ;;
  Darwin) echo darwin ;;
  *) uname -s | tr '[:upper:]' '[:lower:]' ;;
  esac
}

download_mihomo_core() {
  local os arch release_json version_asset_url version asset_name asset_url tmp_dir archive decompressed

  os="$(detect_os)"
  arch="$(detect_arch)"

  release_json="$(curl -fsSL "$CLASH_CORE_API")"
  version_asset_url="$(jq -r '.assets[] | select(.name=="version.txt") | .browser_download_url' <<<"$release_json")"

  if [ -z "$version_asset_url" ] || [ "$version_asset_url" = "null" ]; then
    echo "错误: release 中未找到 version.txt" >&2
    return 1
  fi

  version="$(curl -fsSL "$version_asset_url")"
  asset_name="mihomo-${os}-${arch}-v1-${version}.gz"
  asset_url="$(jq -r --arg name "$asset_name" '.assets[] | select((.name | ascii_downcase) == ($name | ascii_downcase)) | .browser_download_url' <<<"$release_json")"

  if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
    echo "错误: 未找到匹配的 mihomo 资产: $asset_name" >&2
    return 1
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  archive="$tmp_dir/clash.gz"
  decompressed="$tmp_dir/clash"

  log "下载 Clash 核心: $asset_url"
  curl -fsSL -o "$archive" "$asset_url"
  gunzip -c "$archive" > "$decompressed"

  mkdir -p "$(dirname "$CLASH_CORE_DEST_PATH")"
  install -m 0755 "$decompressed" "$CLASH_CORE_DEST_PATH"
  log "已下载 mihomo 版本: $version"
}

copy_dotconfig() {
  if [ -f "/config/.config" ]; then
    cp -f /config/.config ./
  fi
}

update_feeds() {
  ./scripts/feeds update -a
}

patch_rust_ci_llvm() {
  local rust_makefile="feeds/packages/lang/rust/Makefile"

  if [ -f "$rust_makefile" ]; then
    if grep -q -- '--set=llvm.download-ci-llvm=' "$rust_makefile"; then
      sed -i 's/--set=llvm\.download-ci-llvm=[^[:space:]\\]*/--set=llvm.download-ci-llvm=false/g' "$rust_makefile"
      log "已强制将 $rust_makefile 中的 llvm.download-ci-llvm 设为 false"
    else
      log "$rust_makefile 中未发现 llvm.download-ci-llvm 配置，跳过"
    fi
  else
    log "未找到 $rust_makefile，跳过 Rust LLVM 下载配置修正"
  fi
}

install_feeds() {
  ./scripts/feeds install -a
}

main() {
  require_cmd git
  require_cmd curl
  require_cmd jq
  require_cmd gunzip

  clone_openwrt
  prepare_feeds_conf
  install_third_party_packages
  copy_custom_files
  download_mihomo_core
  copy_dotconfig
  update_feeds
  patch_rust_ci_llvm
  install_feeds
}

main "$@"
