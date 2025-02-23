# 基于Alpine最新版构建，兼顾轻量化与安全性 
FROM alpine:latest AS builder

# 安装编译依赖（包含基础工具链、开发库和CGI支持）
RUN apk update && apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    openssl-dev \
    libusb-dev \
    gd-dev \
    linux-headers \
    net-snmp-dev \
    neon-dev \
    wget \
    && rm -rf /var/cache/apk/* 

# 创建专用用户/组（遵循最小权限原则） 
RUN addgroup -S nut && \
    adduser -D -S -G nut nut

# 下载并解压NUT源码（以v2.8.2为例） 
WORKDIR /tmp
RUN wget https://networkupstools.org/source/2.8/nut-2.8.2.tar.gz && \
    tar xzf nut-2.8.2.tar.gz && \
    cd nut-2.8.2

# 配置编译参数（启用全功能并指定用户权限） 
WORKDIR /tmp/nut-2.8.2
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/nut \
    --with-all \
    --with-cgi \
    --with-user=nut \
    --with-group=nut \
    --with-openssl \
    --with-snmp \
    --with-neon \
    --with-usb=libusb-1.0 \
    --without-wrap

# 编译与安装（优化多核编译效率）
RUN make -j$(nproc) && \
    make install && \
    make install-initscript

# 生成最终镜像（分离构建阶段以减小体积）
FROM alpine:latest
COPY --from=builder /usr/ /usr/
COPY --from=builder /etc/nut/ /etc/nut/

# 安装运行时依赖 
RUN apk update && apk add --no-cache \
    libssl3 \
    libusb \
    gd \
    net-snmp-libs \
    neon \
    && rm -rf /var/cache/apk/*

# 验证安装结果（输出关键组件版本） 
CMD echo "NUT components version:" && \
    upsd --version && \
    upsc --version && \
    nut-scanner --version && \
    echo "CGI tools check:" && \
    ls -l /usr/share/nut/cgi-bin/*.cgi
