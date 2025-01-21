#!/command/with-contenv sh

cat <<EOF
===========================================

$(cat /etc/s6-overlay/s6-rc.d/init/00-banner)

Rsync 版本: $(rsync --version | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')

SSH服务：$([ "$SSH" = "true" ] && echo "已启用" || echo "未启用") | 计划任务：$([ "$CRON" = "true" ] && echo "已启用" || echo "未启用")

Rsync守护进程：$([ "$RSYNC" = "true" ] && echo "已启用" || echo "未启用") | Lsyncd守护进程：$([ "$LSYNCD" = "true" ] && echo "已启用" || echo "未启用")

===========================================
EOF