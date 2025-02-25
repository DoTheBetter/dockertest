# 构建阶段：安装编译环境和构建NUT
FROM alpine:3.21

# 安装编译依赖
RUN apk add --no-cache --virtual .build-deps \
    hidapi build-base autoconf automake libtool \
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
    tar \
    tree

RUN apk add --no-cache \
    hidapi-libs \
    eudev \
    udev-init-scripts-openrc \
    libmodbus \
    libusb \
    net-snmp \
    neon \
    nss \
    nss_wrapper \
    gd \
    avahi \
    i2c-tools

# 下载并解压指定版本源码
RUN wget -q https://github.com/networkupstools/nut/releases/download/v2.8.2/nut-2.8.2.tar.gz -O /tmp/nut.tar.gz \
    && tar -zxvf /tmp/nut.tar.gz -C /tmp

# 配置和编译安装
WORKDIR /tmp/nut-2.8.2
RUN CFLAGS="$CFLAGS -flto=auto" \
    && ./configure \
        --build=$CBUILD \
        --host=$CHOST \
        --disable-static \
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
        --with-nss \
        --with-openssl \
        --with-all \
        --with-cgi \
        --with-cgipath=/usr/share/nut/cgi-bin \
        --with-htmlpath=/usr/share/nut/html \
        --with-serial \
        --with-usb \
        --with-snmp \
        --with-neon \
        --with-modbus \
        --with-avahi \
        --with-libltdl \
        --without-gpio \
        --without-powerman \
        --without-ipmi \
        --without-freeipmi \
    && make -j$(nproc) \
    && make install

# 验证安装结果（输出关键组件版本）
RUN echo "NUT components version:" \
    && upsd -h \
    && upsc -h \
    && nut-scanner -h \
    && echo "/usr/share/nut目录结构：" \
    && tree -phugD --du /usr/share/nut \
    && echo "/usr/lib/nut目录结构：" \
    && tree -phugD --du /usr/lib/nut \
    && echo "/etc/nut目录结构：" \
    && tree -phugD --du /etc/nut

# 清理构建依赖和临时文件
RUN apk del .build-deps && \
    rm -rf /tmp/* /var/cache/apk/*

# 验证安装结果（输出关键组件版本）
RUN echo "++++++++++++++NUT components version:++++++++++++++" \
    && upsd -v \
    && upsc -v \
    && nut-scanner -v