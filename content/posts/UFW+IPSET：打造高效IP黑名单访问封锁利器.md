---
title: UFW+IPSET：打造高效IP黑名单访问封锁利器
date: 2025-03-12T07:27:41+08:00
lastmod: 2025-03-22T15:58:28+08:00
tags:
  - UFW
  - IPSET
  - 黑名单封禁
  - Linux安全
description: 这篇文章介绍了如何使用UFW防火墙和IPSET工具结合起来实现更精确、高效的安全策略管控。通过IPSET构建动态黑名单，可以根据特定条件自动添加或删除IP地址，从而增强对入侵者的防御能力。文中详细解释了从安装到配置、测试的步骤，以及如何应用其在网络安全领域的用途。
categories:
  - VPS
  - 服务器
collections:
  - VPS系统安装
featuredImage: https://www.bing.com/th?id=OHR.ChateauLoire_ZH-CN5040147638_800x480.jpg
featuredImagePreview: https://www.bing.com/th?id=OHR.ChateauLoire_ZH-CN5040147638_800x480.jpg
blog: "true"
dir: posts
---

‌‌‌‌　　在服务器上运用 UFW 管理系统防火墙时，若需处理成千上万条 IP 规则，逐一添加将显著降低系统性能。为提高效率与管理便利性，可采用 `ipset` 结合 `ufw` 的方法。这种方法通过在底层的 `iptables` 规则中嵌入 `ipset` 集合，能够有效应对大量 IP 规则的管理挑战，确保系统运行流畅且高效。  

## 1. 创建 ipset 集合  

```shell
ipset create block_ipv4 hash:net family inet hashsize 15000 maxelem 1000000 
```
‌‌‌‌　　这段代码用于创建一个名为 `block_ipv4` 的 IP 集合（IP set），使用 `hash:net` 类型来存储 IPv4 地址或子网。以下是对代码的详细解释：
1. `ipset create`  
	+ `ipset` 是一个用于管理 IP 集合的工具，通常与 `iptables` 配合使用来实现高效的 IP 地址过滤。  
	+ `create` 是 `ipset` 的一个子命令，用于创建一个新的 IP 集合。  
2. `block_ipv4`  
	+ `block_ipv4` 是新创建的 IP 集合的名称。你可以根据需要自定义这个名称。  
3. `hash:net`  
	+ `hash:net` 是 IP 集合的类型。`hash:net` 类型允许你存储 IP 地址或 IP 子网（例如 `192.168.1.0/24`）。  
	+ 这种类型的集合使用哈希表来存储数据，因此查找和插入操作都非常高效。  
4. `family inet`  
	+ `family inet` 指定了这个 IP 集合将用于 IPv4 地址。`inet` 是 IPv4 的标识符。  
	+ 如果你需要处理 IPv6 地址，可以使用 `family inet6`。  
5. `hashsize 15000`  
	+ `hashsize` 指定了哈希表的初始大小。这里的 `15000` 表示哈希表的初始大小为 15000 个桶（buckets）。  
	+ 哈希表的大小会影响性能。如果集合中的元素数量远大于哈希表的大小，可能会导致哈希冲突增加，从而影响性能。因此，选择一个合适的初始大小很重要。  
6. `maxelem 1000000`  
	+ `maxelem` 指定了这个 IP 集合可以存储的最大元素数量。这里的 `1000000` 表示这个集合最多可以存储 100 万个 IP 地址或子网。  
	+ 这个参数用于限制集合的大小，防止集合占用过多内存。

## 2. 将 ipset 规则集成到 ufw  

```shell
sed -i '/^COMMIT$/i -A ufw-before-input -m set --match-set block_ipv4 src -j DROP' /etc/ufw/before.rules
```
‌‌‌‌　　这段代码使用 `sed` 命令在 `/etc/ufw/before.rules` 文件中找到 `COMMIT` 这一行。在 `COMMIT` 行之前插入一条防火墙规则：`-A ufw-before-input -m set --match-set block_ipv4 src -j DROP`。 这条规则会将来自 `block_ipv4` IP 集合的流量直接丢弃（DROP）。以下是对代码的详细解释：
1. `'/^COMMIT$/i …'`
	+ `/^COMMIT$/` 是一个正则表达式，用于匹配文件中包含 `COMMIT` 的行。`^` 表示行的开头，`$` 表示行的结尾，因此 `/^COMMIT$/` 匹配的是单独一行的 `COMMIT`。
	+ `i` 是 `sed` 的插入命令，表示在匹配到的行之前插入指定的内容。
	+ 因此，`'/^COMMIT$/i …'` 的意思是：在文件中找到 `COMMIT` 这一行，并在它之前插入指定的内容。  
2. `-A ufw-before-input -m set --match-set block_ipv4 src -j DROP`
	+ 这是要插入的防火墙规则，具体含义如下：
	    + `-A ufw-before-input`：表示将这条规则添加到 `ufw-before-input` 链中。`ufw-before-input` 是 UFW 的一个内置链，用于处理输入流量。
	    + `-m set --match-set block_ipv4 src`：使用 `set` 模块来匹配 IP 集合。
	        + `--match-set block_ipv4`：指定要匹配的 IP 集合名称为 `block_ipv4`（即之前创建的 IP 集合）。
	        + `src`：表示匹配源地址（即流量的来源 IP）。
	    + `-j DROP`：表示如果匹配成功，则丢弃（DROP）该流量。

## 3. 为什么使用 ufw，而不是使用 iptables

‌‌‌‌　　`ufw`（Uncomplicated Firewall）是一个用户友好的防火墙管理工具，它基于 `iptables` 进行封装，提供了简洁直观的命令行界面。通过简单的命令，`ufw` 能够自动生成并维护复杂的 `iptables` 规则，并将这些规则保存在特定配置文件中，如 `/etc/ufw/*.rules` 文件里。这种自动化的管理方式不仅简化了规则设置，还确保了规则的持久性，即使重启系统也不会丢失。  
‌‌‌‌　　当需要调整或错误地设置了规则时，`ufw` 允许用户通过简单命令快速删除不正确的配置，甚至可以直接卸载 `ufw` 并恢复到默认的安全策略，而无需手动处理复杂的规则保存和恢复操作。  
‌‌‌‌　　相比之下，`iptables` 是一个更底层的防火墙工具，其规则设置更为复杂，涉及到表、链等概念。使用 `iptables` 时，用户需要手动创建和维护这些规则，并且一旦发生错误，恢复起来会更加繁琐。尽管灵活性高，但对新手来说，`iptables` 的学习曲线相对陡峭，操作也更需谨慎。

## 4. 为什么添加到 before.rules，而不是 user.rules

‌‌‌‌　　`user. rules` 文件是通过 UFW 命令行添加规则自动写入并生成配套注释，若必须手动编辑，必须添加完整规则注释，每条规则前需包含 `### tuple ###` 注释块，注释需与规则参数完全匹配，否则会被 UFW 删除。这个网址有说明：[将UFW规则手动添加到user.rules ubuntu16.04后消失](https://cloud.tencent.com/developer/ask/sof/116387371)  
‌‌‌‌　　UFW 加载规则的顺序为：默认规则 → `before*.rules` → `user*.rules` → `after*.rules`, 在 `before*.rules` 或 `after*.rules` 末尾添加自定义规则，则在重新加载后不会消失。

## 5. 完整脚本  

‌‌‌‌　　脚本的使用环境是 Debian，这个脚本通过自动化的方式，从远程下载 IP 黑名单文件，并使用 `ipset` 和 `UFW` 来阻止这些 IP 地址的访问。它涵盖了从下载文件、安装必要工具、配置防火墙到最终检查规则是否生效的完整流程，确保系统的安全性。  

### 5.1. 脚本运行步骤如下

1. 环境准备  
	+ PATH 设置：脚本首先设置了 `PATH` 环境变量，确保在 `cron` 环境下也能正确找到所需的命令。  
	+ 检查 root 权限：脚本检查是否以 `root` 用户运行，如果不是则退出并提示错误。  
2. 工作目录管理  
	+ 清空工作目录：如果工作目录 `ufw_block` 已经存在，脚本会清空该目录的内容。  
	+ 创建工作目录：如果工作目录不存在，脚本会创建该目录。  
3. 下载 IP 黑名单文件  
	+ 下载文件：脚本尝试使用 `wget` 或 `curl` 从指定的 URL 下载 IP 黑名单文件。如果这两个工具都没有安装，脚本会尝试安装 `curl`。  
	+ 检查下载结果：脚本检查下载是否成功，并确保下载的文件不为空。  
4. 安装必要的工具  
	+ 安装 `ipset`：如果 `ipset` 未安装，脚本会自动安装它。  
	+ 安装 `UFW`：如果 `UFW` 未安装，脚本会自动安装它。  
5. 启用和配置 UFW  
	+ 启用 UFW：如果 UFW 未启用，脚本会自动启用它。  
	+ 允许 SSH 端口：脚本会检查并确保 SSH 端口在 UFW 中被允许，以防止管理员被锁在外面。  
6. 拆分 IP 地址列表  
	+ 提取 IPv4 和 IPv6 地址：脚本从下载的 IP 黑名单文件中提取出 IPv4 和 IPv6 地址，并分别保存到不同的文件中。  
	+ 统计 IP 地址数量：脚本统计并输出原始文件、IPv4 和 IPv6 地址的数量。  
7. 创建和管理 `ipset` 集合  
	+ 创建 `ipset` 集合：脚本创建两个 `ipset` 集合，分别用于存储 IPv4 和 IPv6 地址。如果集合已经存在，脚本会清空它们。  
	+ 添加 IP 地址到集合：脚本将提取出的 IPv4 和 IPv6 地址分别添加到对应的 `ipset` 集合中，并保存这些规则到配置文件中。  
8. 将 `ipset` 规则集成到 UFW  
	+ 修改 UFW 规则文件：脚本将 `ipset` 规则添加到 UFW 的 `before.rules` 和 `before6.rules` 文件中，以确保这些规则在 UFW 启动时生效。  
	+ 重启 UFW：脚本重启 UFW 以使更改生效，并检查 UFW 是否成功重启。  
9. 检查规则是否生效  
	+ 检查 `ipset` 集合：脚本输出 `ipset` 集合的内容，确保 IP 地址已成功添加。  
	+ 检查 `iptables` 规则：脚本检查 `iptables` 和 `ip6tables` 规则，确保 `ipset` 规则已正确应用到防火墙。  
	+ 检查 UFW 规则文件：脚本检查 UFW 规则文件，确保 `ipset` 规则已正确集成。  
10. 输出结果  
	+ 输出检查结果：脚本输出所有检查的结果，确保规则已成功添加并生效。

### 5.2. 脚本内容  

```shell
#!/bin/bash
# 添加PATH环境变量（修复cron环境问题）
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# 定义常量
DOWNLOAD_URL="https://blackip.ustc.edu.cn/list.php?txt"
WORK_DIR="ufw_block"                  # 工作目录
BLOCK_LIST="$WORK_DIR/block_list.txt" # IP地址列表文件名
BLOCK_LIST_V4="$WORK_DIR/block_list_v4.txt"
BLOCK_LIST_V6="$WORK_DIR/block_list_v6.txt"
IPSET_V4_CONF="$WORK_DIR/ipset_v4.conf"
IPSET_V6_CONF="$WORK_DIR/ipset_v6.conf"
# 定义颜色常量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色
# 检查是否以root用户运行脚本
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误：请以root用户运行此脚本！${NC}"
    exit 1
fi
# 清空工作目录
if [ -d "$WORK_DIR" ]; then
    echo -e "${YELLOW}正在清空工作目录 $WORK_DIR ...${NC}"
    rm -rf "$WORK_DIR"/*
    echo -e "${GREEN}工作目录已清空！${NC}"
fi
# 创建工作目录
if [ ! -d "$WORK_DIR" ]; then
    mkdir -p "$WORK_DIR"
    echo -e "${GREEN}工作目录 $WORK_DIR 已创建！${NC}"
fi
# 下载IP列表文件
echo -e "${YELLOW}正在下载IP列表文件...${NC}"
if command -v wget &>/dev/null; then
    wget -q -O "$BLOCK_LIST" "$DOWNLOAD_URL"
    DOWNLOAD_RESULT=$?
elif command -v curl &>/dev/null; then
    curl -s -o "$BLOCK_LIST" "$DOWNLOAD_URL"
    DOWNLOAD_RESULT=$?
else
    echo -e "${YELLOW}未找到wget或curl，正在尝试安装curl...${NC}"
    apt-get update && apt-get install -y curl
    if command -v curl &>/dev/null; then
        curl -s -o "$BLOCK_LIST" "$DOWNLOAD_URL"
        DOWNLOAD_RESULT=$?
    else
        echo -e "${RED}错误：无法安装curl，请手动安装wget或curl！${NC}"
        exit 1
    fi
fi
# 检查下载结果
if [ "$DOWNLOAD_RESULT" -ne 0 ]; then
    echo -e "${RED}错误：IP列表文件下载失败！${NC}"
    exit 1
elif [ ! -s "$BLOCK_LIST" ]; then
    echo -e "${RED}错误：下载的文件为空！${NC}"
    exit 1
else
    echo -e "${GREEN}IP列表文件下载成功！${NC}"
fi
# 检查ipset是否安装，未安装则自动安装
if ! command -v ipset &>/dev/null; then
    echo -e "${YELLOW}ipset未安装，正在自动安装...${NC}"
    apt-get update && apt-get install -y ipset
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：ipset安装失败！${NC}"
        exit 1
    fi
    echo -e "${GREEN}ipset安装成功！${NC}"
fi
# 检查UFW是否安装，未安装则自动安装
if ! command -v ufw &>/dev/null; then
    echo -e "${YELLOW}UFW未安装，正在自动安装...${NC}"
    apt-get update && apt-get install -y ufw
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：UFW安装失败！${NC}"
        exit 1
    fi
    echo -e "${GREEN}UFW安装成功！${NC}"
fi
# 检查UFW服务状态
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}UFW未启用，正在自动启用...${NC}"
    echo "y" | ufw enable >/dev/null 2>&1
    if ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}UFW已成功启用！${NC}"
    else
        echo -e "${RED}错误：UFW启用失败！${NC}"
        exit 1
    fi
fi
# 获取SSH端口号
SSH_PORT=$(grep -E "^Port\s+[0-9]+" /etc/ssh/sshd_config | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22} # 如果未设置，使用默认端口22
# 检查该端口是否已被允许
if ! ufw status | grep -qE "\b$SSH_PORT(/tcp)?\b"; then
    echo -e "${YELLOW}正在允许SSH端口 $SSH_PORT ...${NC}"
    ufw allow "$SSH_PORT/tcp" >/dev/null 2>&1
    echo -e "${GREEN}SSH端口 $SSH_PORT 已允许！${NC}"
else
    echo -e "${YELLOW}SSH端口 $SSH_PORT 已被允许，跳过操作。${NC}"
fi
# 拆分IPv4和IPv6地址
echo -e "${YELLOW}正在拆分IP地址列表...${NC}"
# 提取IPv4地址
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$BLOCK_LIST" >"$BLOCK_LIST_V4"
# 提取IPv6地址
grep -Eio '([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}(/\d{1,3})?' "$BLOCK_LIST" >"$BLOCK_LIST_V6"
# 统计原始文件IP地址数量（忽略空行和注释）
ORIGINAL_COUNT=$(grep -vE '^\s*$|^\s*#' "$BLOCK_LIST" | wc -l)
# 统计拆分后的IP地址数量
V4_COUNT=$(wc -l <"$BLOCK_LIST_V4")
V6_COUNT=$(wc -l <"$BLOCK_LIST_V6")
# 输出统计结果
echo -e "${GREEN}原始文件IP地址数量：${ORIGINAL_COUNT}${NC}"
echo -e "${GREEN}IPv4地址数量：${V4_COUNT}${NC}"
echo -e "${GREEN}IPv6地址数量：${V6_COUNT}${NC}"
# 检查拆分结果
if [ -s "$BLOCK_LIST_V4" ]; then
    echo -e "${GREEN}IPv4地址列表已保存到 $BLOCK_LIST_V4！${NC}"
else
    echo -e "${YELLOW}警告：未找到有效的IPv4地址！${NC}"
fi
if [ -s "$BLOCK_LIST_V6" ]; then
    echo -e "${GREEN}IPv6地址列表已保存到 $BLOCK_LIST_V6！${NC}"
else
    echo -e "${YELLOW}警告：未找到有效的IPv6地址！${NC}"
fi
# 创建ipset集合
echo -e "${YELLOW}正在创建ipset集合...${NC}"
if ! ipset list block_ipv4 &>/dev/null; then
    ipset create block_ipv4 hash:net family inet hashsize 15000 maxelem 1000000
    echo -e "${GREEN}IPv4集合创建成功！${NC}"
else
    ipset flush block_ipv4
    echo -e "${YELLOW}IPv4集合已存在，已清空集合内容${NC}"
fi
if ! ipset list block_ipv6 &>/dev/null; then
    ipset create block_ipv6 hash:net family inet6 hashsize 15000 maxelem 1000000
    echo -e "${GREEN}IPv6集合创建成功！${NC}"
else
    ipset flush block_ipv6
    echo -e "${YELLOW}IPv6集合已存在，已清空集合内容${NC}"
fi
# 将IP地址添加到ipset集合
if [ -s "$BLOCK_LIST_V4" ]; then
    echo -e "${YELLOW}正在将IPv4地址添加到ipset集合...${NC}"
    sed 's/^/add block_ipv4 /' "$BLOCK_LIST_V4" | ipset restore -!
    echo -e "${GREEN}IPv4地址已成功添加到ipset集合！${NC}"
    # 单独保存IPv4规则
    ipset save block_ipv4 -f "$IPSET_V4_CONF"
    echo -e "${GREEN}IPv4规则已保存到 $IPSET_V4_CONF！${NC}"
fi
if [ -s "$BLOCK_LIST_V6" ]; then
    echo -e "${YELLOW}正在将IPv6地址添加到ipset集合...${NC}"
    sed 's/^/add block_ipv6 /' "$BLOCK_LIST_V6" | ipset restore -!
    echo -e "${GREEN}IPv6地址已成功添加到ipset集合！${NC}"
    # 单独保存IPv6规则
    ipset save block_ipv6 -f "$IPSET_V6_CONF"
    echo -e "${GREEN}IPv6规则已保存到 $IPSET_V6_CONF！${NC}"
fi
# 将ipset规则集成到UFW
echo -e "${YELLOW}正在将ipset规则集成到UFW...${NC}"
if [ -s "$IPSET_V4_CONF" ]; then
    if ! grep -qx ".*-A ufw-before-input -m set --match-set block_ipv4 src -j DROP" /etc/ufw/before.rules; then
        sed -i '/^COMMIT$/i -A ufw-before-input -m set --match-set block_ipv4 src -j DROP' /etc/ufw/before.rules
    fi
    echo -e "${GREEN}IPv4规则已成功集成到UFW！${NC}"
fi
if [ -s "$IPSET_V6_CONF" ]; then
    if ! grep -qx ".*-A ufw6-before-input -m set --match-set block_ipv6 src -j DROP" /etc/ufw/before6.rules; then
        sed -i '/^COMMIT$/i -A ufw6-before-input -m set --match-set block_ipv6 src -j DROP' /etc/ufw/before6.rules
    fi
    echo -e "${GREEN}IPv6规则已成功集成到UFW！${NC}"
fi
# 重启UFW使更改生效
echo -e "${YELLOW}正在重启UFW以应用更改...${NC}"
# 检查UFW状态，如果未启用则重新启用
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}检测到UFW未启用，正在重新启用...${NC}"
    echo "y" | ufw enable >/dev/null 2>&1
    if ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}UFW已成功启用！${NC}"
    else
        echo -e "${RED}错误：UFW启用失败！${NC}"
        exit 1
    fi
fi
ufw reload
if ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}UFW已成功重启，ipset规则已生效！${NC}"
else
    echo -e "${RED}错误：UFW重启失败！${NC}"
    exit 1
fi
# 添加自动检查功能
echo -e "${YELLOW}正在检查规则是否添加成功...${NC}"
# 检查ipset集合
echo -e "${GREEN}=== IPv4集合内容 ===${NC}"
ipset list block_ipv4 | head -n 10
echo -e "${GREEN}=== IPv6集合内容 ===${NC}"
ipset list block_ipv6 | head -n 10
# 检查iptables规则
echo -e "${GREEN}=== iptables规则 ===${NC}"
iptables -L -v -n | grep block_ipv4
ip6tables -L -v -n | grep block_ipv6
# 检查规则文件
echo -e "${GREEN}=== UFW规则文件 ===${NC}"
grep -A 1 "block_ipv4" /etc/ufw/before.rules
grep -A 1 "block_ipv6" /etc/ufw/before6.rules
echo -e "${GREEN}规则检查完成！${NC}"
```

## 6. 参考

+ [Linux 使用UFW + IPSET实现阻挡国外ip访问](https://www.cnblogs.com/sakimir/articles/15983374.html)  
+ [基于ipset和ip黑名单批量封禁](https://culla.cn/posts/2023/05/use-ipset-banip/)
