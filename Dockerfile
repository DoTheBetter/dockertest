# 第一阶段：构建环境
FROM alpine:latest AS builder

# 安装构建依赖
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    make \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    openssl-dev \
    libusb-dev \
    net-snmp-dev \
    ipmitool-dev \
    pcre-dev \
    linux-headers \
    libcap-dev \
    wget \
    bash

# 下载源码
ENV NUT_VERSION=2.8.2
WORKDIR /tmp
RUN wget https://networkupstools.org/source/${NUT_VERSION}/nut-${NUT_VERSION}.tar.gz \
    && tar -xzf nut-${NUT_VERSION}.tar.gz \
    && rm nut-${NUT_VERSION}.tar.gz

# 编译安装
WORKDIR /tmp/nut-${NUT_VERSION}
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/nut \
    --with-all \
    --with-openssl \
    --with-snmp \
    --with-pcre \
    --with-usb \
    --with-ipmi \
    --with-wrap \
    --with-cgi \
    --with-dev \
    && make -j$(nproc) \
    && make install DESTDIR=/tmp/install

# 第二阶段：运行时环境
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache \
    libusb \
    pcre \
    libcap \
    net-snmp-libs \
    openssl \
    libgcc \
    # 可选：CGI支持需要
    bash \
    lighttpd

# 从构建阶段复制必要文件
COPY --from=builder /tmp/install/usr/sbin/ /usr/sbin/
COPY --from=builder /tmp/install/usr/lib/ /usr/lib/
COPY --from=builder /tmp/install/etc/nut/ /etc/nut/

# 创建运行时目录
RUN mkdir -p /var/run/nut && \
    # 添加用户/组（保持与默认配置一致）
    addgroup nut && \
    adduser -D -G nut nut && \
    # 设置权限
    chown -R nut:nut /var/run/nut /etc/nut

# 验证安装
RUN /usr/sbin/upsc --version && \
    ldd /usr/sbin/upsdrvctl | grep -q "not found" || echo "All dependencies satisfied"

# 清理文档
RUN rm -rf /usr/share/doc/nut

# 暴露默认端口
EXPOSE 3493

# 启动命令（示例）
CMD ["upsdrvctl", "start"]