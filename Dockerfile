FROM alpine:3.21 AS builder

ARG VLMCSD_VER=1113

RUN apk add --no-cache make build-base \
	&& wget https://github.com/Wind4/vlmcsd/archive/refs/tags/svn${VLMCSD_VER}.tar.gz \
	&& tar -zxf svn${VLMCSD_VER}.tar.gz \
	&& cd /vlmcsd-svn${VLMCSD_VER} \
	&& make \
# 显示版本
	&& /vlmcsd-svn${VLMCSD_VER}/bin/vlmcsd -h


FROM alpine:3.21

ARG S6_VER=3.2.0.2
ARG VLMCSD_VER=1113

ENV TZ=Asia/Shanghai \
	WEB=true

COPY --chmod=755 rootfs /
COPY --from=builder --chmod=755 /vlmcsd-svn${VLMCSD_VER}/bin/vlmcsd /usr/bin/vlmcsd

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
