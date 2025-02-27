# 第一阶段：构建NUT（保持原样不变）
FROM alpine:3.21 AS builder

RUN apk add --no-cache --virtual .build-deps \
        build-base linux-headers autoconf automake \
        wget tar tree

RUN apk add --no-cache \
        libtool hidapi eudev openssl-dev libmodbus-dev libusb-dev net-snmp-dev \
        neon-dev nss-dev nss_wrapper-dev gd-dev avahi-dev i2c-tools-dev

RUN wget -q https://github.com/networkupstools/nut/releases/download/v2.8.2/nut-2.8.2.tar.gz -O /tmp/nut.tar.gz \
    && tar -zxvf /tmp/nut.tar.gz -C /tmp \
    && cd /tmp/nut-2.8.2 \
    && CFLAGS="$CFLAGS -flto=auto" \
    && ./configure \
        --build=$CBUILD \
        --host=$CHOST \
        --disable-static \
        --enable-strip \
        --prefix=/nut \
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
        --without-doc \
    && make -j$(nproc) \
    && make install

RUN echo "/nut目录结构：" \
    && tree /nut \
    && echo "NUT components version:" \
    && /nut/sbin/upsd -h \
    && /nut/bin/upsc -h \
    && /nut/bin/nut-scanner -h \
    && /nut/sbin/upsd -V \
    && /nut/bin/upsc -V \
    && /nut/bin/nut-scanner -V

RUN for f in /nut/sbin/*; do \
        echo "Checking $f:"; \
        file "$f"; \
        ldd "$f"; \
        echo "-----------------------------"; \
    done \
    && echo "Checking /nut/bin/upsc:" \
    && file /nut/bin/upsc \
    && ldd /nut/bin/upsc \
    && echo "-----------------------------" \
    && echo "Checking /nut/bin/nut-scanner:" \
    && file /nut/bin/nut-scanner \
    && ldd /nut/bin/nut-scanner

# 第二阶段：运行环境
FROM alpine:3.21
COPY --from=builder /nut /nut

# 设置环境变量（修复LD_LIBRARY_PATH定义）
ENV PATH="/nut/bin:/nut/sbin:${PATH}" \
    LD_LIBRARY_PATH="/nut/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

RUN apk add --no-cache \
        lighttpd \
        nss openssl musl libgcc libusb libmodbus neon \
        avahi eudev net-snmp-tools perl

# 验证步骤（增强环境变量检查）
RUN echo "验证环境变量配置：" \
    && echo "PATH=${PATH}" \
    && echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" \
    && echo -n "upsc路径：" && which upsc \
    && echo -n "upsd路径：" && which upsd \
    && echo "upsd库依赖：" && ldd $(which upsd) | grep -E 'nut/lib|not found' \
    && upsd -h \
    && upsc -h \
    && nut-scanner -h

# 配置lighttpd（Alpine无需单独安装mod_cgi）
RUN echo "server.document-root = \"/nut/html\"" > /etc/lighttpd/lighttpd.conf \
    && echo "server.port = 80" >> /etc/lighttpd/lighttpd.conf \
    && echo "server.modules += ( \"mod_cgi\" )" >> /etc/lighttpd/lighttpd.conf \
    && echo "cgi.assign = ( \".cgi\" => \"\" )" >> /etc/lighttpd/lighttpd.conf \
    && echo "index-file.names += ( \"index.html\" )" >> /etc/lighttpd/lighttpd.conf \
    && mkdir -p /var/run/lighttpd \
    && chmod 755 /nut/cgi-bin/*.cgi \
    && sed -i 's|#!/usr/bin/perl|#!/usr/bin/env perl|' /nut/cgi-bin/*.cgi

# 验证步骤
RUN echo "验证关键组件：" \
    && which lighttpd && lighttpd -v \
    && echo "CGI脚本权限：" \
    && ls -l /nut/cgi-bin/*.cgi \
    && echo "测试CGI执行：" \
    && echo "Status: 200 OK\nContent-type: text/html\n\n" > /tmp/test.html \
    && SCRIPT_NAME=/upsstats.cgi SERVER_PORT=80 /nut/cgi-bin/upsstats.cgi >> /tmp/test.html \
    && grep "UPS" /tmp/test.html

EXPOSE 80
CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]