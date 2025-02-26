# 构建阶段：安装编译环境和构建NUT
FROM alpine:3.21

# 合并所有安装步骤到单个RUN指令（减少镜像层）
RUN apk add --no-cache --virtual .build-deps \
        build-base linux-headers autoconf automake \
        wget tar libtool hidapi eudev openssl-dev \
        libmodbus-dev libusb-dev net-snmp-dev neon-dev \
        nss-dev nss_wrapper-dev gd-dev avahi-dev i2c-tools-dev \
   # 显式安装运行时库（避免后续删除）
    && apk add --no-cache \
        libltdl openssl nss nss_wrapper neon libmodbus libusb \
        net-snmp-libs gd avahi-libs \
    # 下载并解压源码（带自动清理）
    && wget -q https://github.com/networkupstools/nut/releases/download/v2.8.2/nut-2.8.2.tar.gz -O /tmp/nut.tar.gz \
    && tar -zxvf /tmp/nut.tar.gz -C /tmp \
    && cd /tmp/nut-2.8.2 \
    # 配置和编译安装
    && CFLAGS="$CFLAGS -flto=auto" ./configure \
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
    && make install \
    # 清理步骤
    && make clean \
    && apk del .build-deps \
    && rm -rf \
        /tmp/* \
        /var/cache/apk/* \
        /usr/share/man/* \
        /usr/include/* \
        /var/lib/apk/lists/*

# 精简版验证（移除tree依赖）
RUN echo "NUT components version:" \
    && upsd -V \
    && upsc -V \
    && nut-scanner -V

# 应用权限配置
USER nut:nut
EXPOSE 3493
CMD ["upsd", "-D"]