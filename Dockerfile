# 第一阶段：构建环境
FROM alpine:latest AS builder

# 安装必要的依赖
RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    libusb-dev \
    openssl-dev \
    libwrap-dev \
    libgd-dev \
    net-snmp-dev \
    linux-headers \
    curl \
    git \
    make

# 下载并解压NUT源码
RUN curl -LO https://github.com/networkupstools/nut/archive/refs/tags/v2.8.2.tar.gz && \
    tar -xzf v2.8.2.tar.gz && \
    mv nut-2.8.2 /nut

# 进入源码目录
WORKDIR /nut

# 生成配置脚本
RUN ./autogen.sh

# 显示 ./configure --help 的内容
RUN ./configure --help

# 编译NUT
RUN ./configure --with-all --with-cgi --with-user=nut --with-group=nut && \
    make && \
    make install

# 第二阶段：运行环境
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache \
    libusb \
    openssl \
    libwrap \
    libgd \
    net-snmp \
    bash \
    lighttpd \
    lighttpd-mod_auth \
    lighttpd-mod_cgi

# 从构建阶段复制已编译的NUT
COPY --from=builder /usr/local/ /usr/local/

# 复制CGI脚本
COPY --from=builder /nut/scripts/cgi/ /usr/local/share/nut/cgi/

# 配置lighttpd以支持CGI
RUN echo 'server.modules += ( "mod_cgi" )' >> /etc/lighttpd/lighttpd.conf && \
    echo 'cgi.assign = ( ".cgi" => "" )' >> /etc/lighttpd/lighttpd.conf && \
    echo 'server.document-root = "/usr/local/share/nut/cgi"' >> /etc/lighttpd/lighttpd.conf

# 暴露端口
EXPOSE 80

# 启动lighttpd和NUT
CMD ["sh", "-c", "lighttpd -D -f /etc/lighttpd/lighttpd.conf & upsdrvctl start && wait"]