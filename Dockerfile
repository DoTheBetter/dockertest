FROM alpine:latest

# 安装必要的依赖
RUN apk add --no-cache \
    openssl-dev libmodbus-dev libusb-dev net-snmp-dev neon-dev nss-dev \
    libtool autoconf automake make gcc g++ musl-dev curl python3 \
    avahi-dev

# 下载并安装 Powerman
RUN curl -LO https://github.com/chaos/powerman/releases/download/v2.4.4/powerman-2.4.4.tar.gz && \
    tar -xzf powerman-2.4.4.tar.gz && \
    cd powerman-2.4.4 && \
    ./configure && \
    make && \
    make install

# 下载并解压NUT源码
RUN curl -LO https://github.com/networkupstools/nut/archive/refs/tags/v2.8.2.tar.gz && \
    tar -xzf v2.8.2.tar.gz && \
    mv nut-2.8.2 /nut

# 进入源码目录
WORKDIR /nut

# 设置 Python 环境变量
ENV PYTHON=python3

# 生成配置脚本
RUN ./autogen.sh

# 显示 ./configure --help 的内容
RUN ./configure --help

# 配置并编译NUT
RUN ./configure --with-all --with-cgi --with-user=nut --with-group=nut --with-openssl && \
    make && \
    make install

# 检查NUT版本信息
RUN upsdrvctl -V