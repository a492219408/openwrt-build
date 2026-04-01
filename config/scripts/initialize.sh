#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/openwrt/openwrt.git"
REPO_BRANCH="v25.12.2"
OFFICIAL_FEEDS_VERSION=";openwrt-25.12"

apply_official_suffix() {
  local f="$1" name url
  [ -n "${OFFICIAL_FEEDS_VERSION:-}" ] || return 0
  case "$OFFICIAL_FEEDS_VERSION" in
  ';'* | '^'*) SUFFIX="$OFFICIAL_FEEDS_VERSION" ;;
  *) SUFFIX=";$OFFICIAL_FEEDS_VERSION" ;;
  esac
  for name in packages luci routing telephony video; do
    url="$(awk -v n="$name" '$1=="src-git" && $2==n {u=$3; sub(/[;^].*$/,"",u); print u; exit}' "$f")"
    [ -n "$url" ] || continue
    sed -i -E "s|^([[:space:]]*src-git[[:space:]]+$name[[:space:]]+)[^;^[:space:]]+([;^][^[:space:]]*)?|\1${url}${SUFFIX}|" "$f"
  done
}

# 克隆openwrt仓库
if [ ! -d "openwrt" ]; then
  git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" openwrt
else
  echo "目录 openwrt 已存在,跳过克隆"
fi
cd openwrt || {
  echo "错误: 无法进入 openwrt 目录,脚本终止" >&2
  exit 1
}

# 修改官方feeds分支
cp -f feeds.conf.default feeds.conf
apply_official_suffix feeds.conf


# 手动添加第三方feeds
cd package

if [ ! -d "luci-theme-argon" ]; then
  git clone --single-branch --depth=1 https://github.com/jerrykuku/luci-theme-argon.git luci-theme-argon --branch v2.4.3
fi

if [ ! -d "luci-app-argon-config" ]; then
  git clone --single-branch --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git luci-app-argon-config --branch v0.9
fi

if [ ! -d "luci-app-openclash" ]; then
  git clone --single-branch --depth=1 https://github.com/vernesong/OpenClash.git OpenClash-temp --branch v0.47.075
  mv ./OpenClash-temp/luci-app-openclash ./
  rm -rf ./OpenClash-temp
fi

if [ ! -d "luci-app-wolplus" ]; then
  git clone --single-branch --depth=1 https://github.com/sundaqiang/openwrt-packages.git luci-app-wolplus-temp
  mv ./luci-app-wolplus-temp/luci-app-wolplus ./
  rm -rf ./luci-app-wolplus-temp
#  find ./luci-app-wolplus/ -mindepth 1 ! -name 'luci-app-wolplus' -exec rm -rf {} +
fi

cd ..

# 复制files文件夹到构建目录（若目标已存在则先删除）
if [ -d "/config/files" ]; then
  if [ -d "./files" ]; then
    rm -rf ./files
  fi
  cp -r /config/files ./
fi

# 下载Clash内核
#CLASH_CORE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/refs/heads/core/master/meta/clash-linux-amd64-v1.tar.gz"
#CLASH_CORE_DEST_PATH="./files/etc/openclash/core/clash_meta"
#TMP_DIR="$(mktemp -d)"
#ARCHIVE="$TMP_DIR/clash-linux-amd64-v1.tar.gz"
#echo "下载 Clash 核心: $CLASH_CORE_URL"
##curl -L --fail -o "$ARCHIVE" "$CLASH_CORE_URL"
#wget -O "$ARCHIVE" "$CLASH_CORE_URL"
#echo "解压并覆盖到: $CLASH_CORE_DEST_PATH"
#tar -xzf "$ARCHIVE" -C "$TMP_DIR"
#SRC_BIN="$(find "$TMP_DIR" -type f -name clash -print -quit || true)"
#if [ -z "$SRC_BIN" ]; then
#  echo "错误: 未在归档中找到 'clash' 文件" >&2
#  exit 1
#fi
#mkdir -p "$(dirname "$CLASH_CORE_DEST_PATH")"
#cp -f "$SRC_BIN" "$CLASH_CORE_DEST_PATH"
#chmod 0755 "$CLASH_CORE_DEST_PATH"

# 下载Clash mihomo内核
# 统一检测系统架构，并将 x86_64 规范化为 amd64
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
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    armv7l|armv7|armhf) echo armv7 ;;
    armv6l|armv6) echo armv6 ;;
    i386|i686|x86) echo 386 ;;
    mips64) echo mips64 ;;
    mips64le) echo mips64le ;;
    mipsle) echo mipsle ;;
    mips) echo mips ;;
    riscv64) echo riscv64 ;;
    ppc64le|ppc64el) echo ppc64le ;;
    s390x) echo s390x ;;
    *) echo "$arch" ;;
  esac
}
CLASH_CORE_URL="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
CLASH_CORE_DEST_PATH="./files/etc/openclash/core/clash_meta"
CLASH_CORE_VERSION="$(
  curl -fsSL "$(curl -fsSL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest \
  | grep browser_download_url\
  | cut -d'"' -f4\
  | grep version.txt)"
)"
CLASH_CORE_DOWNLOAD_URL="$(
  curl -fsSL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest \
  | grep browser_download_url \
  | cut -d'"' -f4 \
  | grep -i "mihomo-$(uname)-$(detect_arch)-v1-$CLASH_CORE_VERSION.gz"
)"
TMP_DIR="$(mktemp -d)"
ARCHIVE="$TMP_DIR/clash.gz"
echo "下载 Clash 核心: $CLASH_CORE_DOWNLOAD_URL"
curl -fsSL -o "$ARCHIVE" "$CLASH_CORE_DOWNLOAD_URL"
echo "版本: $CLASH_CORE_VERSION"
echo "解压并覆盖到: $CLASH_CORE_DEST_PATH"
gunzip -c "$ARCHIVE" > "$TMP_DIR/$(basename "${ARCHIVE%.gz}")"
SRC_BIN="$(find "$TMP_DIR" -type f -name clash -print -quit || true)"
if [ -z "$SRC_BIN" ]; then
  echo "错误: 未在归档中找到 'clash' 文件" >&2
  exit 1
fi
mkdir -p "$(dirname "$CLASH_CORE_DEST_PATH")"
cp -f "$SRC_BIN" "$CLASH_CORE_DEST_PATH"
chmod 0755 "$CLASH_CORE_DEST_PATH"


# 复制.config文件到构建目录
if [ -f "/config/.config" ]; then
  cp -f /config/.config ./
fi

# 更新所有 feed 源索引，拉取最新的包列表
./scripts/feeds update -a
# 安装所有 feed 包到本地 package 索引（准备符号链接，便于后续选择/编译）
./scripts/feeds install -a

# 修正 rust 构建参数，避免下载 CI LLVM
RUST_MAKEFILE="feeds/packages/lang/rust/Makefile"
if [ -f "$RUST_MAKEFILE" ]; then
  if grep -q -- '--set=llvm.download-ci-llvm=' "$RUST_MAKEFILE"; then
    sed -i 's/--set=llvm\.download-ci-llvm=[^[:space:]\\]*/--set=llvm.download-ci-llvm=false/g' "$RUST_MAKEFILE"
    echo "提示: 已强制将 $RUST_MAKEFILE 中的 llvm.download-ci-llvm 设为 false"
  else
    echo "提示: $RUST_MAKEFILE 中未发现 llvm.download-ci-llvm 配置，跳过"
  fi
else
  echo "提示: 未找到 $RUST_MAKEFILE，跳过 Rust LLVM 下载配置修正"
fi
