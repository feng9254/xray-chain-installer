# 🐾 PuppyIP Xray Chain

无需 x-ui 面板，一条命令搭建：

**VLESS + REALITY + Vision → VPS 本机直连 / SOCKS5 静态住宅出口**

[PuppyIP.com](https://PuppyIP.com) · [购买静态住宅 IP](https://PuppyIP.com/static-ip) · [使用教程](https://PuppyIP.com/tutorials#) · [服务条款](https://PuppyIP.com/terms)

> 原生住宅静态 IP · 固定地区 · 长期使用（具体资源属性与可用期以订单和服务条款为准）

```text
v2rayN / Shadowrocket
          │
          │ VLESS + REALITY + Vision + TCP
          ▼
     你自己的 VPS（一个端口）
          │
          ├── PuppyIP-203.0.113.10 ── VPS 本机直连
          ├── PuppyIP-198.51.100.11 ── SOCKS5 A
          ├── PuppyIP-198.51.100.12 ── SOCKS5 B
          └── PuppyIP-198.51.100.13 ── SOCKS5 C
```

每条 VLESS 链接只对应一个固定出口，可以是 VPS 本机公网 IP，也可以是一条 SOCKS5。多个节点共用同一个 VPS 监听端口和同一套 REALITY 密钥，不需要为每个出口再搭一个面板或占用一个新端口。

## 一键安装

使用 root 登录 VPS，然后执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh)
```

运行后按提示选择出口：直接回车会创建使用 VPS 本机公网 IP 的直连节点；粘贴一条 SOCKS5 会创建一个固定代理出口；一次粘贴多条则会批量创建多个独立节点。SOCKS5 格式为：

```text
IP:端口:用户名:密码
```

示例使用保留文档地址，不是真实代理：

```text
203.0.113.10:1080:username:password
```

需要一次生成多个出口时，可以用空格分隔：

```text
203.0.113.10:1080:user1:password1 198.51.100.20:2080:user2:password2
```

也可以直接粘贴多行：

```text
203.0.113.10:1080:user1:password1
198.51.100.20:2080:user2:password2
```

输入内容不会回显。脚本会验证本机公网出口或逐条验证 SOCKS5，并为每个出口生成独立节点、`vless://` 链接和终端二维码，然后统一部署。单次最多支持 50 条 SOCKS5。

终端品牌页会显示教程地址 `https://puppyip.com/tutorials#`。打开后选择“VPS配置教程 → VPS 链式代理配置”。

如果当前用户不是 root，可先下载再使用 sudo：

```bash
curl -fsSL https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh -o /tmp/puppyip-install.sh
sudo bash /tmp/puppyip-install.sh install
```

一键命令首次执行时需要信任当时公开的 `main` 内容。安装器会将管理脚本固定到当次解析出的 Git 提交，并校验文件大小、版本标记和 Bash 语法；要求严格复现的环境应使用已审核的明确提交 SHA。

## 管理菜单

安装后只需输入：

```bash
puppyip
```

`puppyip` 始终打开完整管理菜单。已经安装后再次执行本页的一键命令，脚本会先安全更新旧版本（如有需要），随后直接进入新增 SOCKS5 的输入步骤，不会重新安装或覆盖原节点。只想管理现有线路时输入 `puppyip`；只想新增线路也可以输入 `puppyip add`。

菜单提供：

```text
1) 新增本机直连或批量 SOCKS5 出口
2) 查看线路、链接和二维码
3) 更换线路的出口 IP
4) 暂停或启用线路
5) 删除线路
6) 重新生成线路链接（旧链接会失效）
7) 检查是否正常运行
8) 查看运行日志
9) 更新 Xray 程序
10) 卸载 PuppyIP Chain
0) 退出
```

也可以直接使用命令：

```bash
puppyip add
puppyip list
puppyip show all
puppyip show 2
puppyip edit 2
puppyip pause 2
puppyip resume 2
puppyip remove 2
puppyip reset 2
puppyip upgrade
puppyip status
puppyip logs
puppyip update
puppyip uninstall
```

为兼容旧版，原命令 `xray-chain` 仍可继续使用。

每个确认提示都会直接写明 `y=同意`、`n=不同意` 以及回车采用哪个选择。删除、重置和卸载等操作默认不同意；更新提示默认同意。不需要输入 `DELETE`、`UNINSTALL` 等确认单词。清除历史备份会单独询问。直接执行明确的 `puppyip pause <编号>` 或 `puppyip resume <编号>` 时会立即应用，不再重复询问。

### 实时状态检测

选择菜单 `7` 或执行 `puppyip status` 时，脚本会先检查 PuppyIP 服务、入口 TCP 端口和当前 Xray 配置。三项均正常后，再让每条已启用线路通过自己的本机直连或 SOCKS5 出口访问公网 IP 检测站；只有实际取得有效 IPv4 时才显示“正常”。暂停线路显示“未检测”，出口超时或无法取得 IPv4 显示“检测失败”。

如果实时出口与安装时记录的 IP 不同，状态页会明确标记“与记录不一致”，同时显示本次检测 IP 和原记录 IP，不会把它标为“正常”，也不会自动改写节点。该检测只确认当时的 TCP 出口和服务配置可用，不承诺所有网站、UDP 或客户端所在网络都能访问。

### 暂停与启用线路

选择菜单 `4` 后，脚本会列出线路及当前状态。暂停只会禁用选中的线路，不会删除它的 UUID、Short ID、SpiderX、备注、SOCKS5 设置、链接或二维码；再次启用后，客户端原链接可以继续使用，无需重新扫码。也可以直接执行：

```bash
puppyip pause 2
puppyip resume 2
```

暂停时，该 VLESS 用户的所有流量会被明确路由到拒绝出口，不会使用它原来的本机直连或 SOCKS5 上游。原出站设置和密码仍留在本机受限权限的 Xray 配置中，以便无损恢复；其他线路继续按原出口工作。即使全部线路都暂停，Xray 服务和配置也会保持正常，之后仍可逐条启用。

每次暂停或启用都会先生成候选配置、执行 Xray 校验、备份并安全应用。PuppyIP 自己的 Xray 服务会重启一次，因此其他线路已有连接可能短暂重连；不会停止或修改 x-ui、3x-ui、S-UI 及其服务。

### VPS 本机直连

首次安装或执行 `puppyip add` 时，在 SOCKS5 输入提示处直接回车，脚本就会创建一条不经过 SOCKS5 的本机直连节点。脚本会先绕过终端代理环境检测 VPS 的实际公网 IPv4；检测失败时停止创建，不会输出未经验证的节点。

直连节点备注采用 `PuppyIP-<本机公网IPv4>` 的形式，例如 `PuppyIP-203.0.113.10`。它拥有独立 UUID、Short ID、SpiderX 和路由规则，TCP 与 UDP 都通过 VPS 本机网络发送。需要同时添加本机直连和多条 SOCKS5 时，先用一次空输入创建直连节点，再执行 `puppyip add` 批量粘贴 SOCKS5。

### 批量新增出口

首次安装和 `puppyip add` 使用同一套批量输入方式：多条信息使用空格或换行分隔，每条仍保持完整的 `IP:端口:用户名:密码` 格式。SOCKS5 地址支持 IPv4 或域名，当前不接受 IPv6 字面量；用户名和密码不要包含空格或换行，密码中的冒号可以保留。

脚本会先检查整批格式，再逐条测试实际出口 IP。所有节点准备好后只重载一次 Xray；中途取消或部署失败不会留下只添加了一部分的运行配置。添加成功后，所有新链接和二维码会依次直接显示。

## 多出口如何工作

- 一台 VPS 只运行一个 Xray 进程、一个 VLESS 入站和一个 TCP 端口。
- 每个本机直连或 SOCKS5 出口对应独立的 UUID、Short ID、SpiderX、用户标识、出站和分享链接。
- Xray 根据 VLESS 用户标识把流量精确路由到对应的 `freedom` 或 SOCKS5 出站。
- 暂停线路只改变其启用状态；节点身份与分享链接保持不变，启用后继续使用原链接。
- 未匹配到任何节点的流量会被阻断，不会回落到 VPS 直连出口。
- 删除节点不会重新编号。删除内部编号 `2` 后，如果下一个可用编号原本是 `4`，新节点仍使用 `4`，不会复用旧编号。

每条链接始终绑定一个固定出口。脚本不会把本机出口与住宅 IP 混用，也不会默认把多个出口做随机负载均衡。直连使用 Xray 官方 `freedom` 出站；路由采用与 3x-ui 默认配置相同的 `domainStrategy: AsIs` + `geoip:private`，会阻断明确的私网 IP 目标和 BitTorrent，并保留最终兜底阻断规则。该规则不能拦截所有经域名解析后指向私网的目标，因此不应视为完整的 SSRF 防护。[Xray 路由官方文档](https://xtls.github.io/en/config/routing.html)、[3x-ui 当前默认配置](https://github.com/MHSanaei/3x-ui/blob/main/internal/web/service/config.json)

## 节点备注

SOCKS5 验证成功后，脚本会查询实际出口 IPv4，并生成类似：

```text
PuppyIP-198.51.100.23
```

备注使用实际出口，而不是只使用 SOCKS5 网关地址，因为两者可能不同。本机直连同样使用检测到的 VPS 公网 IPv4。相同出口重复添加时会自动追加 `-2`、`-3`。修改 SOCKS5 后，脚本会询问是否同步更新备注。

## 哪些参数固定，哪些参数随机

| 参数 | 生命周期 | 说明 |
|---|---|---|
| VPS 地址 | 整个安装固定 | 首次自动识别，所有节点共用 |
| VLESS 端口 | 整个安装固定 | 首次从 `62001-65534` 随机选择空闲端口并保存；可显式指定 |
| REALITY 目标 / SNI | 整个安装固定 | 默认 `www.bing.com:443`，不随机轮换 |
| REALITY X25519 密钥 | 整个安装固定 | 首次安全生成；新增节点不会重置 |
| UUID | 每个节点独立 | 新增时由 Xray 生成，保存后不变 |
| Short ID | 每个节点独立 | 使用 `openssl rand -hex 8` 生成并确保唯一 |
| SpiderX | 每个节点独立 | 使用随机 16 位十六进制路径 |
| 出口类型 | 每个节点固定 | 本机直连使用 `freedom`；代理节点使用对应 SOCKS5 |
| SOCKS5 凭据 | 每个节点独立 | 由用户输入，修改前保持不变 |
| 线路状态 | 每个节点独立 | 默认启用；暂停和恢复不会重置链接或出口设置 |
| 节点编号 | 单调递增 | 删除后不回收，避免旧链接与新节点混淆 |

菜单中的“重置节点凭据”只轮换该节点的 UUID、Short ID 和 SpiderX；不会影响其他节点，也不会重置全局 REALITY 密钥。

默认使用 `www.bing.com:443`，但这只是兼容性默认值，并不是所有机房的唯一最优目标。Cloudflare 的 DNS 覆盖与 REALITY 目标选择不是一回事；REALITY 会把未通过认证的连接转发到目标站，Xray 官方文档特别提醒 CDN 目标可能被滥用为转发器，因此脚本不会因为 Cloudflare 的 DNS 较完善就固定改用 Cloudflare。了解网络环境的用户仍可通过 `XRAY_CHAIN_REALITY_TARGET` 和 `XRAY_CHAIN_REALITY_SNI` 自定义，并应优先选择与 VPS 同 ASN、支持 TLS 1.3/H2 且长期稳定的目标。[Xray REALITY 官方文档](https://xtls.github.io/en/config/transports/reality.html)

## 端口策略

自动安装不会占用 `22`、`80`、`443`、`2095`、`2096`、`8443`、`54321` 等常见系统、Web、面板或代理端口。脚本默认从下面的高位范围随机选择：

```text
62001-65534
```

IANA 将 `49152-65535` 定义为 Dynamic/Private 范围；这里进一步从 `62001` 开始，是为了高于 3x-ui 官方安装器当前随机面板端口范围的上限 `62000`。S-UI 官方默认面板和订阅端口 `2095/2096` 也自然位于范围外。

选择前会通过 `ss` 检查当前 IPv4/IPv6 的 TCP 和 UDP 监听，配置部署前再检查一次。端口选定后会写入状态文件并长期复用，不会在新增节点时改变。如果检查后仍被其他进程抢占，Xray 启动会失败并触发回滚。

专家用户确实需要指定端口时，可以使用：

```bash
XRAY_CHAIN_PORT=443 bash <(curl -fsSL https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh)
```

显式端口必须是 `1-65535` 的单个整数。常用端口会显示警告；已经被 TCP 或 UDP 服务监听时会直接拒绝，不会静默换成其他端口。`433` 不是 HTTPS 标准端口，但自动范围同样不会选择它。

Xray-core 可能对非 `443` 的 REALITY 监听输出风险提示。本项目默认优先避免与网站、证书服务和已有面板争用 `443`；如果你的网络环境确实需要 `443`，应先确认 Nginx、Caddy、面板入站及其他 Xray 都没有使用它，再通过 `XRAY_CHAIN_PORT=443` 明确指定。

脚本不会自动修改 UFW、firewalld 或云厂商安全组，安装结束会提示需要放行最终选中的 TCP 端口。

## 与 x-ui、3x-ui、S-UI 或独立 Xray 共存

可以并存，但前提是不能监听同一个地址和端口，并且 VPS 有足够的内存与文件描述符。PuppyIP Chain 使用完全独立的组件：

| 项目 | 服务与目录 |
|---|---|
| PuppyIP Chain | `xray-chain.service`、`/usr/local/lib/xray-chain/`、`/etc/xray-chain/` |
| 3x-ui | `x-ui.service`、`/usr/local/x-ui/`，面板发行包自带 Xray |
| S-UI | `s-ui.service` 与 `sing-box.service`、通常使用 `/usr/local/s-ui/` |

安装时会识别常见的 `x-ui`、`s-ui`、`xray`、`v2ray` 和 `sing-box` 服务或目录并显示共存提示。对于官方常见 SQLite 安装，还会以只读模式预留面板已经保存但当前没有监听的端口：

| 环境 | 自动避开的保存端口 |
|---|---|
| x-ui / 3x-ui SQLite | 面板端口、订阅端口、所有入站端口 |
| S-UI SQLite | 面板端口、订阅端口、所有入站的 `listen_port` |
| 任意正在运行的面板或代理 | 宿主机当前全部 TCP/UDP 监听端口 |

只读查询只选择数字端口字段，不访问用户、密码、客户端或节点凭据，不调用面板 CLI，不停止或重启面板，也不修改数据库。即使 x-ui/3x-ui 或 S-UI 当时处于停止状态，官方默认路径中的保存端口也能被避开。

仍需人工核对的边界包括：3x-ui 使用 PostgreSQL、面板数据库放在非官方自定义路径、停止状态的 Docker 容器仅在容器内部保存配置，以及其他分支改变了数据库结构。这些情况下脚本不会尝试读取数据库账号或猜测结构；运行中的宿主机映射端口仍可通过 `ss` 自动发现。

安装完成后，也不要在其他面板里再次使用 PuppyIP 显示的最终端口。

公开依据：[3x-ui 官方安装脚本](https://raw.githubusercontent.com/MHSanaei/3x-ui/main/install.sh)、[S-UI 官方 README](https://github.com/alireza0/s-ui#default-installation-information)、[IANA 端口范围](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml)、[Xray 入站监听文档](https://xtls.github.io/en/config/inbound.html#inboundobject)。

## 客户端兼容

生成链接采用：

```text
VLESS + REALITY + Vision + TCP/RAW
```

目标客户端：

- v2rayN（使用 Xray-core 的近期版本）
- Shadowrocket（支持 VLESS + REALITY 的近期版本）

REALITY 不需要在 VPS 上申请或续期传统 TLS 证书。客户端系统时间必须准确，SNI、Public Key 和 Short ID 必须与链接保持一致。

Shadowrocket 没有公开完整、稳定的 URI 参数规范，因此无法承诺所有历史版本都兼容。遇到导入问题时，请先升级客户端再重新扫码。

## UDP 默认行为

新建 SOCKS5 节点默认允许普通 UDP 经该节点绑定的 SOCKS5 上游转发：

```text
XRAY_CHAIN_UDP_MODE=proxy
```

是否真正可用仍取决于上游 SOCKS5 服务是否支持 UDP。上游不支持时，只会使相应 UDP 请求失败，脚本不会偷偷回落到 VPS 本机出口。Vision 标准流仍会拦截 UDP/443（QUIC）并促使浏览器改走 TCP；这不代表 DNS 等普通 UDP 被全局关闭。[Xray VLESS Flow 官方文档](https://xtls.github.io/en/config/outbounds/vless.html#flow-string)

需要让某个新节点明确阻断所有 UDP 时，可以在新增前设置：

```bash
XRAY_CHAIN_UDP_MODE=block puppyip add
```

普通菜单不会再询问 UDP。执行 `puppyip edit <节点编号>` 只用于更换该线路的 SOCKS5 出口；直接回车保留当前出口。更换后 UUID、端口、REALITY 参数和 Short ID 等连接凭据均保持不变，客户已经导入的原节点仍可使用，无需重新导入，只有实际出口 IP 会改变。如果同时更新节点备注，新显示链接只会改变 `#` 后面的客户端名称，不影响旧链接连接。新设置会先完成 SOCKS5 验证、生成候选配置并通过 Xray 校验，成功后再应用。

为了兼容旧用户，脚本内部仍保留每个节点已有的 UDP 策略。更换出口或升级脚本不会顺带改变旧节点的 UDP 状态；新节点继续默认允许 UDP。

本机直连节点不受 `XRAY_CHAIN_UDP_MODE` 影响，默认允许 UDP 经 VPS 本机网络直接发送。

## 旧用户原地更新

旧版用户不需要卸载，也不需要重新搭节点。再次执行同一条一键命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh)
```

脚本检测到旧版本后会使用 `[y=同意 / n=不同意 / 回车=同意]` 询问是否更新；成功更新后直接进入新增 SOCKS5 的输入步骤。已经是当前版本时会跳过更新并直接进入新增步骤。取消更新时不会修改节点，并提示输入 `puppyip` 打开管理菜单。更新前会把旧状态迁移为当前 schema，再逐项核对以下不变量：

- VPS 地址和 VLESS 监听端口
- 全部节点编号、备注、UUID、Short ID、SpiderX 和暂停状态
- REALITY 目标、SNI、公钥与私钥
- 本机直连或 SOCKS5 地址、端口、用户名、密码、UDP 策略和已验证出口
- 原分享链接和二维码所依赖的全部参数

只有候选状态、候选 Xray 配置和原安装完全匹配时才会继续。脚本还会直接比较升级前后 Xray 配置里的入站客户端、监听端口、REALITY 参数、Short ID 以及每个实际出站；如果旧状态文件与正在使用的配置已经不一致，会安全停止并提示检查，不会用状态文件静默覆盖运行配置。随后脚本执行 Xray 配置校验、创建完整备份、原子替换管理文件并检查服务；任一步失败都会恢复更新前文件。升级会重启一次 PuppyIP 自己的 Xray，因此现有连接可能短暂重连，但客户端无需重新导入。

如果当前脚本版本比 VPS 已安装版本更旧，脚本会拒绝降级。如果发现 `state.json` 或 `config.json` 尚在但其他安装组件残缺，脚本也会停止，不会把它当成全新安装覆盖；应先备份 `/etc/xray-chain/` 和 `/var/lib/xray-chain/` 再排查。

`puppyip upgrade` 可用当前已经取得的脚本执行同一套原地迁移。`puppyip update` 用于更新 Xray-core，也会先运行同样的节点、密钥与密码核对，不会只更新核心后留下不兼容的旧状态。

## BBR TCP 加速

安装时默认自动检测 BBR。内核提供 `bbr` 时，脚本会保存安装前的拥塞控制与 qdisc，启用并持久化：

```text
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
```

启用后会重启 PuppyIP 自己的 `xray-chain.service`，让新连接使用 BBR；不会重启或修改 x-ui、3x-ui、S-UI 及它们的服务。执行 `puppyip status` 可以查看当前 TCP 拥塞控制和 qdisc。

明确在命令末尾添加 `install` 也会执行原地版本检查与安全迁移，不会进入新增节点流程：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh) install
```

如果服务器原本已经使用 BBR，脚本会保留现有设置而不接管。如果内核不提供 BBR、容器或云厂商禁止修改 sysctl，脚本只会显示警告，节点安装仍会继续。需要明确禁止脚本修改 TCP 参数时：

```bash
XRAY_CHAIN_ENABLE_BBR=0 bash <(curl -fsSL https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh) install
```

脚本只使用系统内核已经提供的 BBR，不安装第三方内核。由脚本启用的设置会在卸载时恢复到安装前的值。BBR 可能改善高延迟或丢包链路上的 TCP 吞吐，但无法修复上游 SOCKS5 本身限速、丢包、封禁目标网站或 UDP 不可用。

公开依据：[Linux TCP sysctl 文档](https://docs.kernel.org/networking/ip-sysctl.html)、[Linux `default_qdisc` 文档](https://docs.kernel.org/6.3/admin-guide/sysctl/net.html)、[Google BBR](https://github.com/google/bbr)。

## 系统支持

推荐部署环境：`Ubuntu 24.04 LTS`（64 位）。

支持环境：

- Ubuntu 22.04 LTS、Ubuntu 24.04 LTS、Ubuntu 26.04 LTS
- Debian 12、Debian 13
- systemd 正在运行
- `apt-get` 与 `dpkg` 可用
- `amd64`、`arm64` 或 `armv7`
- 内核提供 BBR 时会自动启用；不提供时保留系统原设置

安装器会在下载或修改系统前检查发行版、版本、CPU 架构、`apt-get` 和 systemd。不符合要求时会明确提示更换系统，并优先推荐 `Ubuntu 24.04 LTS`（64 位）。重装 VPS 通常会清空数据，请先备份。

不支持 Alpine/OpenRC、CentOS、AlmaLinux、Rocky Linux、Arch、Debian/Ubuntu 的衍生发行版，以及未运行 systemd 的容器环境。这些环境的服务管理方式不同，安装器会停止执行并提示更换系统。

版本生命周期以 [Ubuntu 官方发布周期](https://ubuntu.com/about/release-cycle) 和 [Debian 官方发布信息](https://www.debian.org/releases/) 为准。

## 安装与升级安全

- 首次安装默认使用已验证的 Xray-core `v26.3.27`。
- `puppyip update` 才会查询 XTLS 官方 GitHub Release 的最新稳定版。
- 下载 Xray 后会核对官方 `.dgst` 中的 SHA-256。
- 通过远程一键命令安装时，落盘的 `puppyip` 管理脚本会固定到一次解析出的 Git 提交，并校验大小、版本标记和 Bash 语法；无法取得固定提交副本时不部署服务。
- 新配置必须先通过 `xray run -test`。
- 旧安装更新前会比较版本并拒绝降级；候选配置必须通过身份、端口、REALITY 私钥和 SOCKS5 密码不变量检查。
- 检测到旧 `state.json` 或 `config.json` 但安装不完整时会停止，不会自动初始化新节点覆盖旧数据。
- 所有节点修改都使用并发锁、部署前备份、原子替换、服务健康检查和失败回滚。
- BBR 只通过 PuppyIP 独立的 sysctl/modules-load 文件启用，不安装第三方内核，也不覆盖同名的非 PuppyIP 文件。
- 脚本不会替换 apt 软件源、删除其他 JSON 文件或修改现有 x-ui、3x-ui、S-UI。

需要安装指定核心版本时：

```bash
XRAY_VERSION=v26.3.27 bash <(curl -fsSL https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh)
```

## 旧版自动迁移

检测到旧版 schema 1 单节点配置后，第一次原地更新、新增或修改节点时会迁移为 schema 2。迁移会保留：

- VPS 地址和监听端口
- 原 UUID 与 Short ID
- REALITY 目标、SNI 和密钥
- SOCKS5 地址、端口、用户名和密码
- 原节点备注与 UDP 策略

迁移不会擅自更换旧 REALITY 目标或 SNI，因为这会改变原分享链接。新安装仍使用当前默认目标；旧节点如需更换目标，应在明确了解会影响原链接后单独处理。

## 文件与凭据

| 用途 | 路径 | 权限 |
|---|---|---|
| Xray | `/usr/local/lib/xray-chain/xray` | `root:root` |
| Geo 数据 | `/usr/local/share/xray-chain/` | `root:root` |
| Xray 配置 | `/etc/xray-chain/config.json` | `root:xray-chain`，`0640` |
| 非密码状态 | `/etc/xray-chain/state.json` | `root:root`，`0600` |
| systemd 服务 | `/etc/systemd/system/xray-chain.service` | 独立用户运行 |
| 历史备份 | `/var/lib/xray-chain/backups/` | `root:root`，`0700` |
| BBR sysctl | `/etc/sysctl.d/99-zz-puppyip-bbr.conf` | `root:root`，`0644` |
| BBR 模块加载 | `/etc/modules-load.d/puppyip-bbr.conf` | `root:root`，`0644` |
| BBR 恢复记录 | `/var/lib/xray-chain/bbr-state.json` | `root:root`，`0600` |
| 管理命令 | `/usr/local/sbin/puppyip` | `root:root`，`0755` |

SOCKS5 密码只写入 Xray 配置和部署备份，不会写入状态文件或 VLESS 分享链接。备份可能包含旧密码，请勿上传 `/etc/xray-chain/`、`/var/lib/xray-chain/`、终端录屏或诊断包。凭据如果曾出现在聊天、工单或公开日志中，应先在供应商后台轮换。

## 关于“没有证书不能用”

v2rayN 的相关提示针对普通 TLS 中的证书验证和 Xray-core 对 `allowInsecure` 的调整，不代表 REALITY 必须安装传统公网证书。本项目使用 REALITY，因此用户无需维护 ACME 证书，但仍必须正确验证 REALITY 的 SNI、Public Key、Short ID 和客户端时间。

公开资料：

- [Xray REALITY 官方文档](https://xtls.github.io/en/config/transports/reality.html)
- [Xray VLESS 入站官方文档](https://xtls.github.io/en/config/inbounds/vless.html)
- [Xray 路由官方文档](https://xtls.github.io/en/config/routing.html)
- [v2rayN：Xray TLS 移除 allowInsecure 的讨论](https://github.com/2dust/v2rayN/discussions/9460)
- [Xray-core #6356：证书记录超过 REALITY 处理上限](https://github.com/XTLS/Xray-core/issues/6356)

## 使用声明、隐私与责任边界

### 合规使用与第三方关系

本项目是独立工具，不隶属于、不代表，也未获得 XTLS、Xray-core、v2rayN、Shadowrocket、x-ui、3x-ui、S-UI 或其他第三方的赞助、认可或背书；相关名称、标识和商标归各自权利人所有。

请仅在当地法律、网络运营商及云厂商规则、目标服务条款、上游 SOCKS5 服务条款和必要授权均允许的业务场景中使用。不得用于未授权访问、欺诈、滥用、规避访问控制或绕过网络限制。PuppyIP 服务仅适用于中国大陆境外的合法合规业务。

### 不作保证

本项目及相关服务按“现状”提供，不保证持续可用、速度、延迟、稳定性、出口属性或地区、兼容所有客户端/网络/上游，也不保证访问或解锁任何网站与服务。页面中的“原生住宅静态 IP、固定地区、长期使用”是产品类别说明；具体资源属性、地区、ISP、可用期与售后范围以实际订单及 [PuppyIP 服务条款](https://PuppyIP.com/terms) 为准。

VLESS、REALITY、Xray 和 SOCKS5 提供的是传输与代理能力，不保证匿名、隐身、不可追踪、绝对隐私或绝对安全，也不能替代终端安全、应用层 TLS、DNS/浏览器防泄漏措施和正常的系统维护。SOCKS5 本身不提供加密；VPS 到上游 SOCKS5 之间的保护取决于应用协议、上游服务和实际网络路径。

### 凭据、流量与日志

SOCKS5 输入在终端中不会回显，但会写入 VPS 本机受限权限的 Xray 配置和部署备份，并用于向上游 SOCKS5 认证。验证 SOCKS5 时，脚本会经该上游访问 `https://api.ipify.org` 查询出口 IPv4；该检测服务会看到出口 IP 及正常连接元数据。

VPS、上游 SOCKS5、DNS 服务、目标站点、客户端及系统日志均可能处理或记录连接元数据；本项目不作“零日志”承诺。运营者必须保护 VLESS 分享链接、二维码、UUID、Short ID、REALITY 私钥、SOCKS5 凭据、配置、日志和备份。请勿把这些内容提交到仓库、公开 Issue、聊天截图、录屏或诊断包；一旦泄露，应立即轮换相应凭据。

### 运营者责任与责任限制

运营者负责 VPS 与账号安全、系统和 Xray 更新、端口及防火墙/云安全组、客户端配置、上游授权、日志与备份访问控制、数据保护以及全部出站流量的合法合规。安装器的自动检查不能替代持续的安全运维或合规审查。

在适用法律允许的最大范围内，项目维护者和服务提供方不对因安装、使用、不可用、配置错误、凭据泄露、第三方服务、账号或 IP 被限制，以及数据或业务中断造成的直接或间接损失作出明示或默示保证或承担责任；适用法律不得排除的责任不受本段影响。

### 版权与使用许可

除引用的第三方项目、名称、商标和资料外，本仓库原创脚本与文档的版权归项目维护者所有。本仓库当前未附加开放源代码许可证；公开可见不等于放弃版权。

允许最终用户为合法自用或内部业务审阅、下载并运行本仓库官方版本。除 GitHub 服务条款允许的查看与 Fork，以及适用法律另有规定外，未经维护者书面许可，不得复制后独立分发、镜像发布、转售、去除品牌或声明、冒充官方，或把本仓库代码作为其他商业产品或安装服务重新发布。需要其他授权时，请先取得维护者书面许可。[GitHub 关于无许可证仓库的说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)

安全问题请参阅 [SECURITY.md](SECURITY.md)。报告问题时只提交脱敏后的复现信息，不要附带真实节点、配置、日志、二维码或凭据。

还没有上游 SOCKS5？

**PuppyIP 提供原生住宅静态 IP：<https://PuppyIP.com>**
