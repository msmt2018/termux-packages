FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
# 安装基础构建工具
RUN apt-get update && apt-get install -y \
    sudo git wget curl python3 python3-pip xz-utils \
    build-essential bison flex libssl-dev bc zip \
    && rm -rf /var/lib/apt/lists/*

# 安装 musl 交叉编译器 (aarch64)
RUN wget https://musl.cc && \
    tar -xzf aarch64-linux-musl-cross.tgz -C /opt && \
    rm aarch64-linux-musl-cross.tgz
ENV PATH="/opt/aarch64-linux-musl-cross/bin:${PATH}"

# 创建用户并配置权限
RUN useradd -m builder && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER builder
WORKDIR /home/builder

# 预克隆仓库并初始化 (加速 Actions 运行)
RUN git clone https://github.com && \
    cd termux-packages && ./scripts/setup-ubuntu.sh

WORKDIR /home/builder/termux-packages
