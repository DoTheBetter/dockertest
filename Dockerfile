FROM alpine:3.21 AS builder

WORKDIR /root

COPY --chmod=755 backupfiles/ /root/

# 安装依赖（包括交叉编译工具）
RUN apk add --no-cache p7zip coreutils make build-base gcc musl-dev

# 检查 SHA256 值，不匹配则退出并输出错误信息
RUN sha256_actual=$(sha256sum /root/vlmcsd-1113-2020-03-28-Hotbird64.7z | awk '{print $1}') \
    && sha256_expected=$(cat /root/SHA256.txt) \
    && if [ "$sha256_actual" != "$sha256_expected" ]; then \
        echo "Error: SHA256 checksum mismatch! Actual: $sha256_actual, Expected: $sha256_expected"; \
        exit 1; \
    fi

# 解压文件
RUN mkdir -p /root/vlmcsd \
    && 7z x /root/vlmcsd-1113-2020-03-28-Hotbird64.7z -o/root/vlmcsd -p2020

# 根据目标平台设置交叉编译工具链
ARG TARGETARCH
ARG TARGETVARIANT
RUN case "${TARGETARCH}-${TARGETVARIANT}" in \
      "amd64-") export CC=gcc ;; \
      "arm64-") export CC=aarch64-linux-musl-gcc ;; \
      "arm-v7") export CC=arm-linux-gnueabihf-gcc ;; \
      *) echo "Unsupported platform: ${TARGETARCH}-${TARGETVARIANT}"; exit 1 ;; \
    esac

# 编译
RUN cd /root/vlmcsd \
    && make CC=$CC \
    && echo "Make completed successfully" \
    || { echo "Make failed"; exit 1; }

# 复制二进制文件并设置权限
RUN cp /root/vlmcsd/bin/vlmcsd /usr/bin/vlmcsd \
    && chmod +x /usr/bin/vlmcsd

# 测试二进制文件
RUN vlmcsd -h


FROM alpine:3.21

ARG S6_VER=3.2.0.2

ENV TZ=Asia/Shanghai \
	WEB=true

COPY --chmod=755 rootfs /
COPY --from=builder --chmod=755 /root/vlmcsd/bin/vlmcsd /usr/bin/vlmcsd

RUN set -ex \
# 安装应用
	&& apk add --no-cache ca-certificates tzdata darkhttpd \
# 安装s6-overlay	
	&& if [ "$(uname -m)" = "x86_64" ];then s6_arch=x86_64;elif [ "$(uname -m)" = "aarch64" ];then s6_arch=aarch64;elif [ "$(uname -m)" = "armv7l" ];then s6_arch=arm; fi \
	&& wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-noarch.tar.xz \
	&& tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
	&& wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-${s6_arch}.tar.xz \
	&& tar -C / -Jxpf /tmp/s6-overlay-${s6_arch}.tar.xz \
# 创建kms用户组,创建无密码、无登录权限的用户
	&& addgroup kms \
	&& adduser -D -H -G kms -s /sbin/nologin kms \
# 创建http用户及组
	&& addgroup http \
	&& adduser -D -H -G http -s /sbin/nologin http \
# 清除缓存
	&& rm -rf /var/cache/apk/* \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /tmp/* \
	&& rm -rf /var/tmp/* \
	&& rm -rf $HOME/.cache

EXPOSE 1688 8080
ENTRYPOINT [ "/init" ]
