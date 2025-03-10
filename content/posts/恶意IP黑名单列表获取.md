---
title: 恶意IP黑名单列表获取
date: 2025-03-06T18:42:12+08:00
lastmod: 2025-03-07T09:28:04+08:00
tags:
  - VPS安全
  - 防火墙
description: 本文介绍了如何使用中国科学技术大学和东北大学提供的IP黑名单来保护VPS的安全，特别强调了通过部署这些黑名单以防止SSH端口受到攻击的方法。文章详细描述了从两所高校获取恶意IP列表的过程，并提供了具体的脚本操作步骤。
categories:
  - VPS
  - 服务器
collections:
  - VPS系统安装
featuredImage: https://www.bing.com/th?id=OHR.NevadaBigHorns_ZH-CN5987046965_800x480.jpg
featuredImagePreview: https://www.bing.com/th?id=OHR.NevadaBigHorns_ZH-CN5987046965_800x480.jpg
blog: "true"
dir: posts
---

‌‌‌‌　　这几天我的 VPS 接连出现来自欧洲 IP 的访问，目标直指 SSH 端口。虽说安全措施已经加固，但是看着日志心烦，直接用 ufw 给封了。我在网络上搜寻有没有现成的恶意 ip 列表，偶然发现两份由国内高校提供的 IP 黑名单清单，我直接在我的 VPS 上用上了。  
‌‌‌‌　　IP 地址黑名单一个是 [中科大](https://blackip.ustc.edu.cn/intro.php) 提供的，另一个由 [东北大学](http://antivirus.neu.edu.cn/scan/) 提供。

## 1. 东北大学网络中心

‌‌‌‌　　东北大学网络应急响应组通过部署相应的 SSH 攻击采集程序，收集了部分发起 SSH 攻击的主机 IP 地址，连接地址为：[http://antivirus.neu.edu.cn/ssh/lists/neu.txt](http://antivirus.neu.edu.cn/ssh/lists/neu.txt "http://antivirus.neu.edu.cn/ssh/lists/neu.txt") ，列表每 5 分钟更新一次，同时还同步 sshbl. org 的黑名单数据，将收集的 IP 地址列表与 sshbl. org 提供的列表进行合并，生成新的 hosts. deny 列表，链接地址：[http://antivirus.neu.edu.cn/ssh/lists/neu_sshbl_hosts.deny](http://antivirus.neu.edu.cn/ssh/lists/neu_sshbl_hosts.deny "http://antivirus.neu.edu.cn/ssh/lists/neu_sshbl_hosts.deny") ，Linux 或 Unix 管理员可以通过更新 hosts. deny 文件来防止主机被攻击。  
‌‌‌‌　　现在打开东北大学网络中心的项目网页只显示部署脚本，按照提示直接在 vps 的 shell 中执行就可以，会每天自动更新 neu_sshbl_hosts. deny 文件。这个脚本只能防止 SSH 端口扫描。
```shell
#==========开始复制==========
ldd `which sshd` | grep libwrap # 确认sshd是否支持TCP Wrapper，输出类似:libwrap.so.0 => /lib/libwrap.so.0 (0x00bd1000)
cd /usr/local/bin/
[ -z $(which wget) ] || CMD="wget -O fetch_neusshbl.sh"
[ -z $(which curl) ] || CMD="curl -o fetch_neusshbl.sh"
${CMD} https://antivirus.neu.edu.cn/ssh/soft/fetch_neusshbl.sh
chmod +x fetch_neusshbl.sh
cd /etc/cron.hourly/
ln -s /usr/local/bin/fetch_neusshbl.sh fetch_neusshbl
./fetch_neusshbl
#=========结束复制==========
```

## 2. 中国科学技术大学  

‌‌‌‌　　中科大的这个地址提供了 IP 地址黑名单，DNS 客户黑名单，Mail 客户黑名单三种黑名单。对我们个人有用的就只有 IP 地址黑名单，他的 IP 地址黑名单集成了几种其他的名单，ip 列表很大，都是些大量扫描和密码尝试活动的恶意 IP。[IP黑名单文本格式列表](https://blackip.ustc.edu.cn/list.php?txt)，官方也提供了脚本，不过需要自己参考修改下。  

### DNS 客户黑名单封锁步骤

1. 在 DNS 服务器上增加如下 iptables 规则
```shell
iptables -N dns 
iptables -I INPUT -j dns -p udp --dport 53
```

2. 执行如下命令更新黑名单
```shell
#!/bin/bash

iptables -F dns

curl http://blackip.ustc.edu.cn/dnsblackip.php?txt > dnsblackip.txt

for ip in `cat dnsblackip.txt`; 
do echo iptables -A dns -j DROP -s $ip; 
iptables -A dns -j DROP -s $ip;
done
```

### MAIL 客户黑名单封锁步骤

1. 在 mail 服务器上增加如下 iptables 规则
```shell
iptables -N BANIP

#smtp/imap/pop auto block
iptables -A INPUT -j BANIP -p tcp --dport 25 
iptables -A INPUT -j BANIP -p tcp --dport 110
iptables -A INPUT -j BANIP -p tcp --dport 143
iptables -A INPUT -j BANIP -p tcp --dport 465
iptables -A INPUT -j BANIP -p tcp --dport 993
iptables -A INPUT -j BANIP -p tcp --dport 995
```
2. 执行如下命令更新黑名单
```shell
iptables -F BANIP

wget http://blackip.ustc.edu.cn/mailblackip.php?txt -O old.blackip.txt 2>/dev/null

for i in `cat old.blackip.txt`; do
iptables -A BANIP -j DROP -s $i;
done

while true; do
 date
 wget http://blackip.ustc.edu.cn/mailblackip.php?txt -O new.blackip.txt 2>/dev/null
 diff -u old.blackip.txt new.blackip.txt |grep "^-[0-9]"|cut -c2-| while read ip; do
  echo del $ip
  iptables -D BANIP -j DROP -s $ip;
 done
 diff -u old.blackip.txt new.blackip.txt |grep "^+[0-9]"|cut -c2-| while read ip; do
  echo add $ip
  iptables -A BANIP -j DROP -s $ip;
 done
 mv -f new.blackip.txt old.blackip.txt
 sleep 5
done
```
