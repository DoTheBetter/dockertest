# 构建阶段：安装编译环境和构建NUT
FROM alpine:3.21

# 安装编译依赖
RUN apk add --no-cache --virtual .build-deps \
        build-base linux-headers autoconf automake \
        wget tar tree

RUN apk add --no-cache \
        libtool hidapi eudev openssl-dev libmodbus-dev libusb-dev net-snmp-dev \
        neon-dev nss-dev nss_wrapper-dev gd-dev avahi-dev i2c-tools-dev

# 下载并编译安装
RUN wget -q https://github.com/networkupstools/nut/releases/download/v2.8.2/nut-2.8.2.tar.gz -O /tmp/nut.tar.gz \
    && tar -zxvf /tmp/nut.tar.gz -C /tmp \
    && cd /tmp/nut-2.8.2 \
    && CFLAGS="$CFLAGS -flto=auto" \
    && ./configure \
        --build=$CBUILD \
        --host=$CHOST \
        --enable-static \
        --enable-shared \
        --prefix=/usr/local/ups \
        --with-user=root \
        --with-group=root \
        --with-nss \
        --with-openssl \
        --with-all \
        --with-cgi \
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
RUN echo "/usr/local/ups目录结构：" \
    && tree /usr/local/ups \
    && echo "NUT components version:" \
    && /usr/local/ups/sbin/upsd -h \
    && /usr/local/ups/bin/upsc -h \
    && /usr/local/ups/bin/nut-scanner -h \
    && /usr/local/ups/sbin/upsd -V \
    && /usr/local/ups/bin/upsc -V \
    && /usr/local/ups/bin/nut-scanner -V

#验证是否为静态
RUN for f in /usr/local/ups/sbin/*; do \
        echo "Checking $f:"; \
        file "$f"; \
        ldd "$f"; \
        echo "-----------------------------"; \
    done \
    && echo "Checking /usr/local/ups/bin/upsc:" \
    && file /usr/local/ups/bin/upsc \
    && ldd /usr/local/ups/bin/upsc \
    && echo "-----------------------------" \
    && echo "Checking /usr/local/ups/bin/nut-scanner:" \
    && file /usr/local/ups/bin/nut-scanner \
    && ldd /usr/local/ups/bin/nut-scanner

# 验证阶段（添加库存在性检查）
RUN echo "关键共享库验证：" \
    && ls -l /usr/lib/libupsclient.so*