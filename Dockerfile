ARG RSYNC_VER=3.4.1

FROM alpine:3.21
ARG S6_VER=3.2.0.2

ENV TZ=Asia/Shanghai \
	SSH=false \
	CRON=false \
	RSYNC=false \
	LSYNCD=false \
	S6_VERBOSITY=1

COPY --chmod=755 rootfs /

# 关闭调试输出
RUN set +ex \
# 安装应用
	&& apk add --no-cache tzdata lsyncd openssh openrc \
	&& apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main rsync \
# 安装s6-overlay	
	&& if [ "$(uname -m)" = "x86_64" ];then s6_arch=x86_64;elif [ "$(uname -m)" = "aarch64" ];then s6_arch=aarch64;elif [ "$(uname -m)" = "armv7l" ];then s6_arch=arm; fi \
	&& wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-noarch.tar.xz \
	&& tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
	&& wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-${s6_arch}.tar.xz \
	&& tar -C / -Jxpf /tmp/s6-overlay-${s6_arch}.tar.xz \
# sshd_config设置
	&& passwd=$(date +%s | sha256sum | base64 | head -c 32) \
	&& echo "root:$passwd" | chpasswd \
	&& sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin without-password/g" /etc/ssh/sshd_config \
	&& sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/g" /etc/ssh/sshd_config \
	&& sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config \
	&& echo -e "Host *\nStrictHostKeyChecking accept-new" > /etc/ssh/ssh_config \
# 清除缓存
	&& rm -rf /var/cache/apk/* \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /tmp/* \
	&& rm -rf /var/tmp/* \
	&& rm -rf $HOME/.cache


VOLUME /conf /backup
EXPOSE 22 873
ENTRYPOINT [ "/init" ]