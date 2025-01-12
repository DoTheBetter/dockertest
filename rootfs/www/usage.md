## 一、手动激活 Windows

使用管理员打开 cmd 或 Windows Power Shell，输入以下命令：

```bash
slmgr.vbs /upk                        #可选：移除原有密钥
slmgr.vbs /ipk {对应操作系统的密钥}    #可选：设置新密钥
slmgr.vbs /skms skms.netnr.eu.org     #设置KMS服务器地址
slmgr.vbs /ato                        #立即尝试激活
slmgr.vbs /dlv                        #查看激活状态
slmgr.vbs /xpr                        #查看激活时效
```

## 二、手动激活 Office（VOL 版本）

找到 Office 的安装目录，使用管理员打开 cmd 或 Windows Power Shell，并切换到该目录，输入以下命令：

```bash
cd /d D:\Program Files\Microsoft Office\Office16       #office安装位置
cscript ospp.vbs /inpkey:{对应Office的密钥}             #可选：更改密钥
cscript ospp.vbs /sethst:skms.netnr.eu.org             #设置KMS服务器地址
cscript ospp.vbs /act                                  #立即尝试激活
cscript ospp.vbs /dstatus                              #查看激活状态
```

## 三、局域网自动发现激活（DNS SRV 记录）

`SRV` 记录是一种 DNS 记录类型，用于指定提供特定服务的服务器地址和端口。在 OpenWrt 中，通过 DNSmasq 配置 `SRV` 记录，可以让局域网内的设备自动发现 KMS 服务器。

在 DNS 服务器上创建一个 SRV 记录，指向 KMS 服务器的地址和端口：

| 属性      | 值                |
| :-------- | :---------------- |
| 类型      | SRV               |
| 服务/名称 | _vlmcs            |
| 协议      | _tcp              |
| 优先度    | 0                 |
| 权重      | 0                 |
| 端口号    | 1688              |
| 主机名    | *KMS 主机的 FQDN* |

### 3.1. openwrt 中的2种设置方法

1. 在 LuCI 界面中找到 `网络` - `DHCP/DNS` - `SRV` 标签 - `添加`
2. 直接在/etc/dnsmasq. conf 末尾添加 srv 的声明

### 3.2. 配置格式

```plaintext
srv-host=<服务名称>.<协议>,<目标主机>,<端口>,<优先级>,<权重>
```

比如：

```plaintext
srv-host=_vlmcs._tcp,ImmortalWrt,1688,0,100
```

### 3.3. 参数详解

1. **`_vlmcs`**：
   
   + 这是 KMS 服务的标识符。`_vlmcs` 是微软 KMS 服务的标准名称，客户端通过这个名称来查找 KMS 服务器。
   
2. **`_tcp`**：

   + 表示服务使用的协议类型。KMS 服务使用 TCP 协议，因此这里填写 `_tcp`。

3. **`ImmortalWrt`**：

   + 这是 KMS 服务器的主机名或域名。`ImmortalWrt` 表示 KMS 服务器的地址是 `ImmortalWrt`（可以是 IP 地址或域名）。
   + 例如，如果 KMS 服务器的 IP 地址是 `192.168.1.100`，可以写成 `192.168.1.100`。

4. **`1688`**：

   + 这是 KMS 服务的默认端口号。KMS 服务器通常监听 1688 端口。

5. **`0`**：

   + 这是优先级（Priority）。优先级的值越小，表示优先级越高。如果有多个 KMS 服务器，客户端会优先选择优先级较低的服务器。
   + 如果只有一个 KMS 服务器，可以设置为 `0`。

6. **`100`**：

   + 这是权重（Weight）。当多个 KMS 服务器的优先级相同时，客户端会根据权重来选择服务器。权重越高，被选中的概率越大。
   + 如果只有一个 KMS 服务器，可以设置为 `100`。

### 3.4. 验证 SRV 记录

在客户端上，可以使用以下命令验证 SRV 记录是否生效：

#### 3.4.1. Windows

```bash
nslookup -type=SRV _vlmcs._tcp
```

#### 3.4.2. Linux

```bash
dig SRV _vlmcs._tcp
```

如果配置正确，会返回类似以下结果：

```plaintext
服务器:  ImmortalWrt.lan
Address:  192.168.10.1

_vlmcs._tcp.lan SRV service location:
          priority       = 0
          weight         = 100
          port           = 1688
          svr hostname   = ImmortalWrt
ImmortalWrt     AAAA IPv6 address = fd8e:a84b:df69::1
ImmortalWrt     internet address = 192.168.10.1
```
