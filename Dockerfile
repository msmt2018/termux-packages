FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    sudo git wget curl python3 python3-pip xz-utils \
    build-essential bison flex libssl-dev bc zip debootstrap \
    && rm -rf /var/lib/apt/lists/*

# 安装 musl 交叉编译器
RUN wget https://musl.cc && \
    tar -xzf aarch64-linux-musl-cross.tgz -C /opt && rm aarch64-linux-musl-cross.tgz
ENV PATH="/opt/aarch64-linux-musl-cross/bin:${PATH}"

RUN useradd -m builder && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER builder
WORKDIR /home/builder

# 预准备 termux-packages 仓库
RUN git clone https://github.com && \
    cd termux-packages && ./scripts/setup-ubuntu.sh

WORKDIR /home/builder/termux-packages
