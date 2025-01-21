#!/command/with-contenv sh

echo -e "===========================================\n"
cat 00-banner
echo -e "\nRsync 版本: $(rsync --version | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')"
echo -e "\nSSH服务：$([ "$SSH" = "true" ] && echo "已启用" || echo "未启用") | 计划任务：$([ "$CRON" = "true" ] && echo "已启用" || echo "未启用")"
echo -e "\nRsync守护进程：$([ "$RSYNC" = "true" ] && echo "已启用" || echo "未启用") | Lsyncd守护进程：$([ "$LSYNCD" = "true" ] && echo "已启用" || echo "未启用")"
echo -e "\n==========================================="
