#!/command/with-contenv sh

echo -e "===========================================\n\n"
cat /etc/s6-overlay/s6-rc.d/init/00-banner
echo -e "\n"
echo -e "\nRsync 版本: $(rsync --version | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')\n"
echo -e "SSH服务：$([ "$SSH" = "true" ] && echo "已启用" || echo "未启用") | 计划任务：$([ "$CRON" = "true" ] && echo "已启用" || echo "未启用")\n"
echo -e "Rsync守护进程：$([ "$RSYNC" = "true" ] && echo "已启用" || echo "未启用") | Lsyncd守护进程：$([ "$LSYNCD" = "true" ] && echo "已启用" || echo "未启用")\n"
echo -e "==========================================="