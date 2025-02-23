FROM alpine:latest

# 安装必要的依赖
RUN apk add --no-cache \
    openssl-dev libmodbus-dev libusb-dev net-snmp-dev neon-dev nss-dev \
    libtool autoconf automake make gcc musl-dev curl

# 下载并解压NUT源码
RUN curl -LO https://github.com/networkupstools/nut/archive/refs/tags/v2.8.2.tar.gz && \
    tar -xzf v2.8.2.tar.gz && \
    mv nut-2.8.2 /nut

# 进入源码目录
WORKDIR /nut

# 生成配置脚本
RUN ./autogen.sh

# 配置并编译NUT
RUN ./configure --with-all --with-cgi --with-user=nut --with-group=nut && \
    make && \
    make install

# 检查NUT版本信息
RUN upsdrvctl -V