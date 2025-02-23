FROM alpine:latest

# 安装所有编译依赖（新增linux-headers和pkgconf）
RUN apk add --no-cache \
    openssl-dev libmodbus-dev libusb-dev net-snmp-dev neon-dev nss-dev \
    libtool autoconf automake make gcc g++ musl-dev curl python3 \
    avahi-dev freeipmi-dev libgpiod-dev linux-headers pkgconf \
    # 补充运行时依赖库
    libgpiod libgcc libstdc++ \
    # 系统工具
    shadow

# 下载并解压NUT源码
RUN curl -LO https://github.com/networkupstools/nut/archive/refs/tags/v2.8.2.tar.gz && \
    tar -xzf v2.8.2.tar.gz && \
    mv nut-2.8.2 /nut

WORKDIR /nut

# 创建专用用户/组（参考文档建议）
RUN groupadd -r nut && \
    useradd -r -g nut -s /bin/false nut

ENV PYTHON=python3

# 生成配置脚本
RUN ./autogen.sh

# 配置编译参数（显式指定gpiod路径）
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/nut \
    --with-user=nut \
    --with-group=nut \
    --with-all \
    --with-cgi \
    --with-openssl \
    --with-gpiod=auto \
    --without-powerman

# 编译安装（优化编译参数）
RUN make -j$(nproc) && \
    make install

# 验证安装
RUN upsdrvctl -V