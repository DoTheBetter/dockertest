# 构建阶段：安装编译环境和构建NUT
FROM alpine:3.21

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
    i2c-tools-dev \
    wget \
    tar

# 创建nut用户/组
RUN addgroup -S nut && adduser -S -D -G nut nut

# 下载并解压指定版本源码
RUN wget -q https://github.com/networkupstools/nut/releases/download/v2.8.2/nut-2.8.2.tar.gz -O /tmp/nut.tar.gz \
    && tar -zxvf /tmp/nut.tar.gz -C /tmp


# 配置和编译安装
WORKDIR /tmp/nut-2.8.2
RUN CFLAGS="$CFLAGS -flto=auto" \
    && ./configure \
        --enable-static \
        --disable-shared \
		--prefix=/usr \
		--libexecdir=/usr/lib/nut \
		--with-drvpath=/usr/lib/nut \
		--datadir=/usr/share/nut \
		--sysconfdir=/etc/nut \
		--with-statepath=/var/run/nut \
		--with-altpidpath=/var/run/nut \
		--with-udev-dir=/usr/lib/udev \
        --with-user=nut \
        --with-group=nut \
        --with-openssl \
        --with-all \
        --with-cgi \
        --with-cgipath=/usr/share/nut/cgi-bin \
        --without-gpio \
        --without-powerman \
        --without-ipmi \
        --without-freeipmi \
    && make -j$(nproc) \
    && make install


# 验证安装结果（输出关键组件版本） 
RUN echo "NUT components version:" && \
    ls -l /etc/nut && \
    upsd -h && \
    upsc -h && \
    nut-scanner -h && \
    echo "CGI tools check:" && \
    ls -l /usr/share/nut/cgi-bin/*.cgi



# 安装运行时依赖和lighttpd
RUN apk add --no-cache \
    lighttpd

# 配置lighttpd
RUN mkdir -p /var/www/localhost/cgi-bin && \
    cp /usr/share/nut/cgi-bin/*.cgi /var/www/localhost/cgi-bin/ && \
    chmod +x /var/www/localhost/cgi-bin/*.cgi

COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

# 设置权限
RUN chown -R nut:nut /etc/nut /var/www/localhost && \
    chmod 755 /var/www/localhost/cgi-bin/*.cgi

EXPOSE 80

CMD sh -c "upsdrvctl start && \
           upsd && \
           lighttpd -D -f /etc/lighttpd/lighttpd.conf"
