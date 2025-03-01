#!/command/with-contenv sh

echo "+ 正在运行初始化任务..."

echo "1. 设置系统时区"
# 设置时区 https://wiki.alpinelinux.org/wiki/Setting_the_timezone
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
# 显示信息
echo "→ 当前服务器时间: $(date "+%Y-%m-%d %H:%M:%S")"

echo "2. 创建用户组"
# ========== 强制覆盖 nut 用户/组（使用指定 UID/GID） ==========
if getent passwd nut >/dev/null; then
    deluser nut >/dev/null 2>&1 || true
fi

if getent group nut >/dev/null; then
    delgroup nut >/dev/null 2>&1 || true
fi

addgroup -g "${NUT_GID:-1000}" nut
adduser -D -H -u "${NUT_UID:-1000}" -G nut -s /sbin/nologin nut

# ================== 强制覆盖 http 用户/组 ==================
if getent passwd http >/dev/null; then
    deluser http >/dev/null 2>&1 || true
fi

if getent group http >/dev/null; then
    delgroup http >/dev/null 2>&1 || true
fi

addgroup http
adduser -D -H -G http -s /sbin/nologin http

echo "3. nut 相关设置"
# 设置配置文件
# NUT 作为网络 UPS 工具，主要包含几个组件：驱动（upsdrvctl）、服务端（upsd）、监控端（upsmon）等。
# 在 netserver 模式下，应该是要运行 upsd 作为服务器，让其他客户端可以连接到这个服务器获取 UPS 的状态
# ups.conf 配置 UPS 设备，upsd.conf 配置服务器参数，upsd.users 设置用户权限，upsmon.conf 用于监控，nut.conf 设置运行模式等
mkdir -p /conf
cp -rf /nut/etc.bak/* /conf/

if [ ! -e /conf/nut.conf ]; then
    echo "→ 初始定义 NUT 运行模式为 netserver >> nut.conf"
    cat >/conf/nut.conf <<EOF
# 定义 NUT 运行模式
MODE=netserver
EOF
else
    echo "→ 文件存在，跳过 nut.conf 设置"
fi

if [ ! -e /conf/ups.conf ]; then
    echo "→ 初始配置连接的 UPS 设备，指定驱动和参数 >> ups.conf"
    cat >/conf/dummy-ups.dev <<EOF
# /conf/dummy-ups.dev
# 模拟 UPS 定义文件，测试用，正式使用可删除
ups.status: OL
battery.charge: 100
input.voltage: 230.0
output.voltage: 230.0
ups.load: 15
EOF
    cat >/conf/ups.conf <<EOF
# 配置连接的 UPS 设备，指定驱动和参数
# 可以通过 nut-scanner 命令扫描获得配置信息
# 用法见 https://networkupstools.org/docs/man/nut-scanner.html
# 威联通示例：名称 qnapups 不能改变
#[qnapups]
#        driver = "snmp-ups"
#        port = "192.168.0.99"
#        desc = "Smart-UPS 1500"
#        mibs = "apcc"
#        snmp_version = "v1"
#        community = "public"
#        pollfreq = "15"
#
# 群晖示例：名称 ups 不能改变
#[ups]
#        driver = "snmp-ups"
#        port = "192.168.0.99"
#        desc = "Smart-UPS 1500"
#        mibs = "apcc"
#        snmp_version = "v1"
#        community = "public"
#        pollfreq = "15"
#
# 测试用虚拟 ups
[virtualups]
    driver = dummy-ups
    port = /conf/dummy-ups.dev
    desc = "Virtual UPS for testing"
EOF
else
    echo "→ 文件存在，跳过 ups.conf 设置"
fi

if [ ! -e /conf/upsd.conf ]; then
    echo "→ 初始配置 upsd 监听的地址、端口和会话超时 >> upsd.conf"
    cat >/conf/upsd.conf <<EOF
# 配置 upsd 监听的地址、端口和会话超时
LISTEN 0.0.0.0 3493
MAXAGE 15
EOF
else
    echo "→ 文件存在，跳过 upsd.conf 设置"
fi

if [ ! -e /conf/upsd.users ]; then
    echo "→ 初始定义访问 NUT 服务的用户及其权限 >> upsd.users"
    cat >/conf/upsd.users <<EOF
# 定义访问 NUT 服务的用户及其权限
# 群晖：UPS 标识：ups、用户名：monuser、密码：secret
# 威联通：UPS 标识：qnapups、用户名：admin、密码：123456
[admin]
    password = 123456
    upsmon master
[monuser]
    password = secret
    upsmon master
EOF
else
    echo "→ 文件存在，跳过 upsd.users 设置"
fi

if [ ! -e /conf/upsmon.conf ]; then
    echo "→ 初始配置本地或远程 UPS 监控策略 >> upsmon.conf"
    cat >/conf/upsmon.conf <<EOF
# 配置本地或远程 UPS 监控策略
# MONITOR qnapups@localhost 1 admin 123456 master
MONITOR virtualups@localhost 1 admin 123456 master
EOF
else
    echo "→ 文件已存在，跳过 upsmon.conf 设置"
fi

ln -sf /conf /nut/etc

echo "4. lighttpd 相关设置"
if [ "$WEB" = "true" ]; then
    if [ ! -e /conf/hosts.conf ]; then
        echo "→ 初始定义要监控的 UPS 设备及其描述，供 CGI 页面展示 >> hosts.conf"
        cat >/conf/hosts.conf <<EOF
# 定义要监控的 UPS 设备及其描述，供 CGI 页面（如 upsstats）展示
# 写法：MONITOR <UPS标识@nut server地址> "<描述>"
#MONITOR qnapups@localhost "QNAP"
#MONITOR ups@localhost "Synology"
MONITOR virtualups@localhost "Virtual UPS"
EOF
    else
        echo "→ 文件存在，跳过 hosts.conf 设置"
    fi

    if [ ! -e /conf/upsstats.html ]; then
        echo "→ 复制并重命名 upsstats.html.sample 为 upsstats.html"
        cp /conf/upsstats.html.sample /conf/upsstats.html
    else
        echo "→ 文件 /conf/upsstats.html 已存在，跳过复制操作"
    fi

    if [ ! -e /conf/upsstats-single.html ]; then
        echo "→ 复制并重命名 upsstats-single.html.sample 为 upsstats-single.html"
        cp /conf/upsstats-single.html.sample /conf/upsstats-single.html
    else
        echo "→ 文件 /conf/upsstats-single.html 已存在，跳过复制操作"
    fi
else
    echo "→ 未设置启动 lighttpd 服务"
fi

echo "5. 修复文件权限"
# nut
mkdir -p /var/run/nut
chown -R nut:nut /var/run/nut
chmod -R 770 /var/run/nut
chown -R root:nut /conf
chmod -R 644 /conf

# lighttpd
if [ "$WEB" = "true" ]; then
    chown -R http:http /nut/cgi-bin
    chmod -R 755 /nut/cgi-bin
    chown http:http /lighttpd.conf
    chmod 644 /lighttpd.conf
else
    echo "→ 未设置启动 lighttpd 服务"
fi