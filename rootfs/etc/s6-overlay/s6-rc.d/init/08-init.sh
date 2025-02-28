#!/command/with-contenv sh

echo "+正在运行初始化任务..."

echo "1.设置系统时区"
# 设置时区https://wiki.alpinelinux.org/wiki/Setting_the_timezone
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
#显示信息
echo "→当前服务器时间:$(date "+%Y-%m-%d %H:%M:%S")"

echo "2.创建用户组"
addgroup -g ${NUT_GID} nut && adduser -D -H -u ${NUT_UID} -G nut nut
addgroup http && adduser -D -H -G http http

echo "3.nut相关设置"
#设置配置文件
#NUT作为网络UPS工具，主要包含几个组件：驱动（upsdrvctl）、服务端（upsd）、监控端（upsmon）等。在netserver模式下，应该是要运行upsd作为服务器，让其他客户端可以连接到这个服务器获取UPS的状态
#ups.conf配置UPS设备，upsd.conf配置服务器参数，upsd.users设置用户权限，upsmon.conf用于监控，nut.conf设置运行模式等
mkdir -p /conf
cp -f /nut/etc/* /conf/

if [ ! -e /conf/nut.conf ]; then
echo "→3.1初始定义NUT运行模式为netserver >>nut.conf"
cat >/conf/nut.conf <<EOF
#定义NUT运行模式
MODE=netserver
EOF
else
	echo "→3.1文件存在，跳过 nut.conf 设置"
fi

if [ ! -e /conf/ups.conf ]; then
echo "→3.2初始配置连接的UPS设备，指定驱动和参数 >>ups.conf"
cat >/conf/ups.conf <<EOF
#配置连接的UPS设备，指定驱动和参数
#可以通过nut-scanner命令扫描获得配置信息
#用法见https://networkupstools.org/docs/man/nut-scanner.html
#测试用虚拟ups
[virtualups]
    driver = "dummy-ups"
    port = "/nut/bin/dummy-ups"
    desc = "Virtual UPS for Testing"
#威联通示例：名称qnapups不能改变
#[qnapups]
#        driver = "snmp-ups"
#        port = "192.168.0.99"
#        desc = "Smart-UPS 1500"
#        mibs = "apcc"
#        snmp_version = "v1"
#        community = "public"
#        pollfreq = "15"
#
#群晖示例：名称ups不能改变
#[ups]
#        driver = "snmp-ups"
#        port = "192.168.0.99"
#        desc = "Smart-UPS 1500"
#        mibs = "apcc"
#        snmp_version = "v1"
#        community = "public"
#        pollfreq = "15"
EOF
else
    echo "→3.2文件存在，跳过 ups.conf 设置"
fi

if [ ! -e /conf/upsd.conf ]; then
echo "→3.3初始配置upsd监听的地址、端口和会话超时 >>upsd.conf"
cat >/conf/upsd.conf <<EOF
#配置upsd监听的地址、端口和会话超时
LISTEN 0.0.0.0 3493
MAXAGE 15
EOF
else
    echo "→3.3文件存在，跳过 upsd.conf 设置"
fi

if [ ! -e /conf/upsd.users ]; then
echo "→3.4初始定义访问NUT服务的用户及其权限 >>upsd.users"
cat >/conf/upsd.users <<EOF
#定义访问NUT服务的用户及其权限
#群晖：UPS标识：ups、用户名：monuser、密码：secret
#威联通：UPS标识：qnapups、用户名：admin、密码：123456
[admin]
	password = 123456
	upsmon master

[monuser]
	password = secret
	upsmon master
EOF
else
    echo "→3.4文件存在，跳过 upsd.users 设置"
fi

if [ ! -e /conf/upsmon.conf ]; then
echo "→3.5初始配置本地或远程UPS监控策略 >>upsmon.conf"
cat >/conf/upsmon.conf <<EOF
#配置本地或远程UPS监控策略
MONITOR virtualups@localhost 1 admin 123456 master
EOF
else
    echo "→3.5文件已存在，跳过 upsmon.conf 设置"
fi

ln -sf /conf /nut/etc

# 创建运行时目录并设置权限
mkdir -p /var/run/nut
chown -R root:nut /var/run/nut
chmod -R 770 /var/run/nut

chown -R root:nut /conf
chmod -R 660 /conf/*

echo "4.lighttpd相关设置"
chmod 755 /nut/cgi-bin/*.cgi
chmod 644 /nut/html/*

chown -R http:http /lighttpd.conf
chmod 644 /lighttpd.conf
#sed -i 's|#!/usr/bin/perl|#!/usr/bin/env perl|' /nut/cgi-bin/*.cgi