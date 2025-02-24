# 第一阶段：构建环境
FROM debian:bookworm-slim AS builder

# 安装编译依赖
RUN apt-get update && \
    apt-get install -y \
    wget build-essential autoconf automake libtool \
    pkg-config libssl-dev libwrap0-dev libcgicc-dev \
    libneon27-dev libavahi-client-dev --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# 下载指定版本源码
WORKDIR /tmp
RUN wget https://github.com/networkupstools/nut/releases/download/v2.8.2/nut-2.8.2.tar.gz && \
    tar xzf nut-2.8.2.tar.gz && \
    mv nut-2.8.2 nut

# 配置编译参数
WORKDIR /tmp/nut
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/nut \
    --with-all \
    --with-cgi \
    --with-user=nut \
    --with-group=nut \
    --with-openssl \
    --with-dev \
    --without-doc

# 编译安装
RUN make -j$(nproc) && \
    make install && \
    strip /usr/lib/nut/*.so && \
    strip /usr/bin/nutcgi

# 第二阶段：运行时环境
FROM debian:bookworm-slim

# 安装运行时依赖和微型HTTP服务
RUN apt-get update && \
    apt-get install -y \
    libssl3 libwrap0 libcgicc3 libneon27 libavahi-client3 \
    busybox --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* /usr/share/man/*

# 复制构建产物
COPY --from=builder /usr/ /usr/
COPY --from=builder /etc/nut/ /etc/nut/

# 创建nut用户和运行目录
RUN groupadd -r nut && \
    useradd -r -g nut -d /var/lib/nut nut && \
    mkdir -p /var/run/nut /var/www/nut && \
    chown -R nut:nut /var/run/nut /etc/nut

# 配置HTTP服务
COPY --from=builder /usr/share/nut/www/* /var/www/nut/
RUN chmod +x /var/www/nut/*.cgi && \
    echo "httpd -p 8080 -h /var/www/nut" > /start-httpd.sh && \
    chmod +x /start-httpd.sh

# 复合启动脚本
RUN echo "#!/bin/sh\n\
/start-httpd.sh &\n\
upsd -D\n\
wait" > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 暴露端口
EXPOSE 3493 8080

# 启动服务
USER nut
ENTRYPOINT ["/entrypoint.sh"]
