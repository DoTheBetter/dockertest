# 构建阶段：安装编译环境和构建NUT
FROM alpine:3.21 AS builder

# 安装编译依赖
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    autoconf \
    automake \
    libtool \
    linux-headers \
    openssl-dev \
    libmodbus-dev \
    libusb-dev \
    net-snmp-dev \
    neon-dev \
    nss-dev \
    nss_wrapper-dev \
    gd-dev \
    avahi-dev \
    libgpiod \
    libgpiod-dev \
    wget \
    tar

# 创建nut用户/组
RUN addgroup -S nut && adduser -S -D -G nut nut

# 下载并解压指定版本源码
RUN wget -q https://github.com/networkupstools/nut/releases/download/v2.8.2/nut-2.8.2.tar.gz -O /tmp/nut.tar.gz \
    && tar -zxvf /tmp/nut.tar.gz -C /tmp

# 配置和编译安装
WORKDIR /tmp/nut-2.8.2
RUN ./configure \
        --prefix=/usr \
        --sysconfdir=/etc/nut \
        --with-user=nut \
        --with-group=nut \
        --with-openssl \
        --with-all \
        --without-powerman \
        --without-ipmi \
        --without-freeipmi \
    && make -j$(nproc) \
    && make install


# 验证安装结果（输出关键组件版本） 
RUN echo "NUT components version:" && \
    upsd --version && \
    upsc --version && \
    nut-scanner --version && \
    echo "CGI tools check:" && \
    ls -l /usr/share/nut/cgi-bin/*.cgi

# 运行时阶段：使用lighttpd作为Web服务器
FROM alpine:3.21

# 安装运行时依赖和lighttpd
RUN apk add --no-cache \
    openssl \
    libusb \
    gd \
    net-snmp \
    nss_wrapper \
    lighttpd


# 从构建阶段复制安装内容
COPY --from=builder /usr/ /usr/
COPY --from=builder /etc/nut /etc/nut

# 配置lighttpd
RUN mkdir -p /var/www/localhost/cgi-bin && \
    cp /usr/share/nut/cgi/*.cgi /var/www/localhost/cgi-bin/ && \
    chmod +x /var/www/localhost/cgi-bin/*.cgi

COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

# 重建运行时用户/组
RUN addgroup -S -g $(id -g nut) nut && \
    adduser -S -D -G nut -u $(id -u nut) nut

# 设置权限
RUN chown -R nut:nut /etc/nut /var/www/localhost && \
    chmod 755 /var/www/localhost/cgi-bin/*.cgi

EXPOSE 80

CMD sh -c "upsdrvctl start && \
           upsd && \
           lighttpd -D -f /etc/lighttpd/lighttpd.conf"
