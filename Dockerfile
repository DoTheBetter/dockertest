FROM alpine:3.21 AS builder

ARG NUT_VERSION=2.8.2

RUN apk add --no-cache --virtual .build-deps \
    build-base linux-headers autoconf automake \
    libtool hidapi eudev openssl-dev libmodbus-dev libusb-dev net-snmp-dev \
    neon-dev nss-dev nss_wrapper-dev gd-dev avahi-dev i2c-tools-dev \
    wget tar tree

RUN wget -q https://github.com/networkupstools/nut/releases/download/v${NUT_VERSION}/nut-${NUT_VERSION}.tar.gz -O /tmp/nut.tar.gz \
    && tar -zxvf /tmp/nut.tar.gz -C /tmp \
    && cd /tmp/nut-${NUT_VERSION} \
    && CFLAGS="$CFLAGS -flto=auto" \
    && ./configure \
        --build=$CBUILD \
        --host=$CHOST \
        --disable-static \
        --enable-strip \
        --prefix=/nut \
		--with-statepath=/var/run/nut \
		--with-altpidpath=/var/run/nut \
		--with-udev-dir=/usr/lib/udev \
        --with-user=nut \
        --with-group=nut \
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

RUN echo "/nut 目录结构：" \
    && tree /nut \
    && echo "NUT 文件版本:" \
    && /nut/bin/nut-scanner -h \
    && /nut/sbin/upsd -h \
    && /nut/sbin/upsdrvctl -h \
    && /nut/sbin/upsmon -h

FROM alpine:3.21
ARG S6_VER=3.2.0.2

ENV PATH="/nut/bin:/nut/sbin:${PATH}" \
    LD_LIBRARY_PATH="/nut/lib:/usr/lib:/lib:/usr/local/lib" \
    S6_VERBOSITY=1 \
    TZ=Asia/Shanghai \
    NUT_UID=1000 \
    NUT_GID=1000 \
    WEB=true

COPY --from=builder /nut /nut
COPY --chmod=755 rootfs /

RUN apk add --no-cache \
    tzdata ca-certificates lighttpd perl \
    libtool hidapi eudev openssl-dev libmodbus-dev libusb-dev net-snmp-dev \
    neon-dev nss-dev nss_wrapper-dev gd-dev avahi-dev i2c-tools-dev \
    # 安装s6-overlay
    && if [ "$(uname -m)" = "x86_64" ]; then s6_arch=x86_64; \
    elif [ "$(uname -m)" = "aarch64" ]; then s6_arch=aarch64; \
    elif [ "$(uname -m)" = "armv7l" ]; then s6_arch=arm; fi \
    && wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-${s6_arch}.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-${s6_arch}.tar.xz \
    # 清除缓存
    && rm -rf \
        /tmp/* \
        /var/cache/apk/* \
        /var/lib/apk/lists/* \
        /var/tmp/* \
        $HOME/.cache

RUN echo "版本验证：" \
    && upsd -V \
    && upsc -V \
    && nut-scanner -V \
    && upsdrvctl -V \
    && upsmon -V

WORKDIR /nut
EXPOSE 3493 80
ENTRYPOINT [ "/init" ]