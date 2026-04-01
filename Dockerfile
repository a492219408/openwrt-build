FROM buildpack-deps:24.04-curl
ENV DEBIAN_FRONTEND=noninteractive

# 更改时区到Asia/Shanghai
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ >/etc/timezone

# 更改apt为清华镜像源
RUN set -eux; \
    cat >/etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: https://mirrors4.tuna.tsinghua.edu.cn/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors4.tuna.tsinghua.edu.cn/ubuntu
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

# 安装构建时所需依赖
RUN apt-get update && apt-get install -y \
    build-essential clang flex bison g++ gawk \
    gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
    python3-setuptools rsync swig unzip zlib1g-dev file wget \
    qemu-utils ccache genisoimage

RUN rm -rf /var/lib/apt/lists/*

# 留一个默认用户（运行时会被 compose 的 user 覆盖为宿主 UID/GID）
#RUN useradd -m -u 1000 -s /bin/bash builder || true

WORKDIR /workspace

# 常驻（方便 host 侧用 docker compose exec/shell）
CMD ["bash", "-lc", "sleep infinity"]
