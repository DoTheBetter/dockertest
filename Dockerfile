# 使用 Alpine Linux 作为基础镜像
FROM alpine:latest AS builder

# 安装必要的依赖
RUN apk add --no-cache build-base git autoconf automake libtool gettext-dev \
    libssh2-dev zlib-dev c-ares-dev libxml2-dev sqlite-dev openssl-dev \
    nettle-dev gmp-dev expat-dev

# 安装交叉编译工具链
RUN apk add --no-cache crossbuild-essential-amd64 crossbuild-essential-arm64 crossbuild-essential-armhf

# 克隆 aria2 源代码
RUN git clone https://github.com/aria2/aria2.git /aria2
WORKDIR /aria2

# 自动判断系统类型并设置交叉编译环境
ARG TARGETARCH
RUN case "$TARGETARCH" in \
    "amd64") \
        export CC=x86_64-alpine-linux-musl-gcc \
        export CXX=x86_64-alpine-linux-musl-g++ \
        export AR=x86_64-alpine-linux-musl-ar \
        export RANLIB=x86_64-alpine-linux-musl-ranlib \
        export LD=x86_64-alpine-linux-musl-ld \
        ;; \
    "arm64") \
        export CC=aarch64-alpine-linux-musl-gcc \
        export CXX=aarch64-alpine-linux-musl-g++ \
        export AR=aarch64-alpine-linux-musl-ar \
        export RANLIB=aarch64-alpine-linux-musl-ranlib \
        export LD=aarch64-alpine-linux-musl-ld \
        ;; \
    "arm") \
        export CC=armv7-alpine-linux-musleabihf-gcc \
        export CXX=armv7-alpine-linux-musleabihf-g++ \
        export AR=armv7-alpine-linux-musleabihf-ar \
        export RANLIB=armv7-alpine-linux-musleabihf-ranlib \
        export LD=armv7-alpine-linux-musleabihf-ld \
        ;; \
    *) \
        echo "Unsupported architecture: $TARGETARCH" && exit 1 \
        ;; \
    esac

# 配置和编译 aria2
RUN autoreconf -i && \
    ./configure --host=$TARGETARCH-alpine-linux-musl --prefix=/usr/local --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make -j$(nproc) && \
    make install DESTDIR=/output

# 最终阶段：创建一个轻量级的镜像
FROM alpine:latest

# 复制编译好的 aria2 二进制文件
COPY --from=builder /output/usr/local/bin/aria2c /usr/local/bin/aria2c

# 设置 CA 证书
RUN apk add --no-cache ca-certificates

# 验证 aria2 是否正常工作
RUN aria2c --version

# 设置默认命令
CMD ["aria2c"]