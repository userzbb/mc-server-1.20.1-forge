# 🧱 Minecraft Forge 服务器

> **版本：** Forge 1.20.1 (47.4.21)
> **域名：** `catzizimiku.top`（IPv6 直连，不需要端口转发）
> **运行环境：** Docker (itzg/minecraft-server:java17)

---

## 🚀 快速启动

```bash
cd ~/minecraft-server

# 启动所有服务（后台运行）
docker compose up -d

# 查看运行状态
docker compose ps

# 查看 Minecraft 服务器日志
docker compose logs -f mc-forge

# 停止服务器
docker compose stop

# 完全停止并删除容器
docker compose down
```

首次启动需要下载安装 Forge 并加载所有 Mod，**约 3-5 分钟**。看到以下日志即为启动完成：

```
[DedicatedServer]: Done (XX.XXXs)! For help, type "help"
```

---

## 🔗 访问方式

服务器所有服务都通过域名 `catzizimiku.top` 走 **IPv6** 访问，不需要在路由器上做端口转发。

| 服务 | 地址 | 说明 |
|------|------|------|
| 🎮 Minecraft 游戏 | `catzizimiku.top:25565` | 直接进游戏添加服务器 |
| 📊 MCSManager 面板 | `http://catzizimiku.top:23333` | 网页管理面板，**用 HTTP 不是 HTTPS** |
| 🌐 DDNS-GO | `http://catzizimiku.top:9876` | 动态域名解析管理 |

### 端口一览

| 端口 | 协议 | 用途 |
|------|------|------|
| 25565 | TCP | Minecraft 游戏连接 |
| 23333 | TCP | MCSManager 面板 |
| 24444 | TCP | MCSManager 守护进程（内部通信） |
| 25575 | TCP | RCON 远程管理 |
| 24454 | UDP | 语音聊天（Voice Chat） |
| 9876 | TCP | DDNS-GO 管理界面 |

---

## 🐳 服务架构

项目通过 Docker Compose 管理 **4 个服务**：

| 服务 | 镜像 | 说明 |
|------|------|------|
| **mc-forge** | `itzg/minecraft-server:java17` | Minecraft Forge 1.20.1 服务器，含 85 个 Mod |
| **mcsm-web** | `githubyumao/mcsmanager-web` | MCSManager Web 管理面板 |
| **mcsm-daemon** | `githubyumao/mcsmanager-daemon` | MCSManager 守护进程 |
| **ddns-go** | `jeessy/ddns-go` | 动态域名解析，绑定域名到公网 IP |

### 常用命令

```bash
# 查看所有容器状态
docker compose ps

# 查看某个服务的日志
docker compose logs -f mc-forge      # MC 服务器
docker compose logs -f mcsm-web      # MCSManager 面板
docker compose logs -f ddns-go       # DDNS

# 重启某个服务
docker compose restart mc-forge

# 更新 Mod 后重启
docker compose restart mc-forge
```

---

## 📦 Mod 列表

本服务器安装了 **85 个 Mod**，涵盖科技、魔法、冒险、武器、存储、地图等类别。

📋 完整分类清单请查看 **[mod-list.md](mod-list.md)**

### 主要 Mod 一览

| 类别 | Mod |
|------|-----|
| ⚡ 科技 | Applied Energistics 2, Mekanism, Refined Storage, Flux Networks |
| 🔮 魔法 | Ars Nouveau, 暮色森林, Patchouli |
| 🗡️ 武器 | 拔刀剑 (SlashBlade), TACZ 现代枪械 |
| 🎩 伙伴 | 东方女仆 (Touhou Little Maid) |
| 🏠 领地 | Open Parties and Claims |
| 🎤 语音 | Voice Chat |
| 🗺️ 地图 | Xaero's Minimap / World Map, The One Probe, Jade |

### ⚠️ 注意

以下客户端 Mod **不要**安装到服务器上，会导致启动崩溃：

- `entity_texture_features` — Mixin 引用客户端类
- `oculus` — 客户端光影
- `sodiumextras` — 客户端渲染
- `DGLabCraft` — 客户端 UI

其他客户端 Mod（如 embeddium、JEI 等）虽然不会导致崩溃，但也没必要放在服务器上。

---

## 🎮 MCSManager 管理面板

MCSManager 是一个 Web 面板，可以方便地管理游戏服务器。但注意：**当前 mc-forge 是通过 docker-compose 直接启动的，不在面板管理范围内**。面板可以用来创建新的服务器实例。

### 访问面板

```
地址：http://catzizimiku.top:23333
账号：zizimiku
```

> ⚠️ 务必用 **HTTP**！浏览器默认 HTTPS 会连不上。

### 如果守护进程离线

节点配置存储在 `mcsm/web/data/RemoteServiceConfig/` 目录下。如果需要手动添加：

1. 面板 → 左侧「节点」→「添加节点」
2. 填写：
   - 名称：`主服务器`
   - IP：`catzizimiku.top`（必须是域名）
   - 端口：`24444`
   - 密钥：`3fa29ec75e5f4c66cbb29eed3de41b798e73b18f29061fe`
3. 点击确认

### 排查连接问题

```bash
# 检查守护进程是否运行
docker compose ps mcsm-daemon

# 测试连通性
docker exec mcsm-web node -e "const http = require('http'); http.get('http://catzizimiku.top:24444/', r => { r.resume(); console.log(r.statusCode) }).on('error', e => console.log(e.message))"

# 返回 200 即正常，重启面板
docker compose restart mcsm-web
```

---

## 🌐 DDNS-GO 动态域名

DDNS-GO 将服务器的公网 IP 自动绑定到域名 `catzizimiku.top`，IP 变了域名自动更新。

```
管理地址：http://catzizimiku.top:9876
DNS 服务商：阿里云 DNS
支持：IPv4 + IPv6 双栈
```

### 检查域名解析

```bash
host catzizimiku.top
# 正常应看到 IPv4 + IPv6 地址

# 查看当前公网 IP
curl -4 https://myip.ipip.net
curl -6 https://myip.ipip.net

# 重启 DDNS
docker compose restart ddns-go
```

---

## 🔧 配置参考

### 环境变量（docker-compose.yml）

| 变量 | 值 | 说明 |
|------|-----|------|
| `MEMORY` | 4G | 分配内存 |
| `MAX_PLAYERS` | 20 | 最大玩家数 |
| `ONLINE_MODE` | false | 离线模式（允许非正版） |
| `VERSION` | 1.20.1 | Minecraft 版本 |
| `FORGE_VERSION` | 47.4.21 | Forge 版本 |

### RCON 远程管理

已开启 RCON，端口 `25575`。密码在 `data/server.properties` 中的 `rcon.password` 字段。

### 防火墙

所有端口集成在 `mc-server` 这个 firewalld 服务里。在 GUI（`firewall-config`）中勾选：
- **区域 → FedoraWorkstation** → `mc-server`
- **区域 → FedoraServer** → `mc-server`（同样重要！网卡绑定的是这个区域）

---

## 📄 项目文件结构

```
~/minecraft-server/
├── docker-compose.yml      # Docker 服务定义
├── README.md               # 本文件
├── mod-list.md             # Mod 完整清单
├── credentials.md          # 🔑 所有账号密码（已 gitignore）
├── docs/
│   └── 操作手册.md          # 详细运维指南（面向 AI）
├── mods/                   # Mod jar 文件
├── data/                   # MC 世界存档、日志等
├── mcsm/                   # MCSManager 数据
└── ddns-go-data/           # DDNS 配置
```
