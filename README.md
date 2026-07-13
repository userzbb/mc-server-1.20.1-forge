# 🧱 Minecraft Forge 服务器

> **版本：** Forge 1.20.1 (47.4.21)
> **域名：** `catzizimiku.top`（IPv6 直连，不需要端口转发）
> **管理方式：** MCSManager Web 面板管理

---

## 📋 使用流程

```
1. docker compose up -d           → 部署 MCSManager + DDNS-GO
2. 浏览器访问面板 http://...:23333 → 创建 Minecraft 服务器实例
3. 在面板里启动/停止/管理服务器    → 开玩
```

Minecraft 服务器不再由 docker-compose 直接管理，而是通过 MCSManager 面板创建和管理。

## 🚀 部署

```bash
cd ~/minecraft-server
docker compose up -d
```

## 🔗 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| 📊 MCSManager 面板 | `http://catzizimiku.top:23333` | 管理服务器，**用 HTTP 不是 HTTPS** |
| 🎮 Minecraft 游戏 | `catzizimiku.top:25565` | 直接进游戏添加服务器 |
| 🌐 DDNS-GO | `http://catzizimiku.top:9876` | 动态域名解析管理 |

> 所有服务走 IPv6，不需要端口转发。

## 🎮 MCSManager 面板使用

### 首次使用：创建 MC 服务器实例

**第一步：登录面板**
浏览器打开 `http://catzizimiku.top:23333`（⚠️ 用 HTTP，不是 HTTPS）
账号密码见 `credentials.md`

**第二步：进入节点**
登录后 → 点左侧 **「终端」** → 点 **「主服务器」** 节点

**第三步：创建实例**
点右上角 **「创建实例」** → 弹出窗口选：
- 类型：**Minecraft Java 版**
- 版本：**Forge 1.20.1**
- 填一个实例名称（如 "Forge 服务器"）
- 点「确认创建」

**第四步：上传 Mod 和存档**
创建成功后，点进实例 → 点 **「文件管理」**

上传 Mod：
1. 在文件管理里进入 `mods/` 文件夹（如果没有就新建一个）
2. 点右上角 **「上传文件」**
3. 从 `~/minecraft-server/mods/` 目录选择 `.jar` 文件上传
4. 或者用 **「远程下载」** 直接输入 Mod 下载链接

上传世界存档（可选）：
1. 如果有旧存档，把 `world/` 文件夹上传到实例根目录
2. 把 `server.properties` 也上传覆盖

**第五步：启动服务器**
点左侧 **「控制台」** → 点 **「开启实例」** 按钮
首次启动需要下载 Forge 并加载 Mod，等待 3-5 分钟，看到 `Done` 即为启动成功。

### 日常管理

| 操作 | 位置 |
|------|------|
| 启动/停止 | 实例控制台 → 开启/关闭 |
| 文件管理 | 实例 → 文件管理（上传 Mod、替换存档） |
| 控制台命令 | 实例 → 控制台（输 `/op 玩家名` 等） |
| 查看日志 | 实例 → 控制台 / 日志 |
| 定时备份 | 实例 → 定时任务 |

### 如果守护进程离线

**最快恢复：**
```bash
docker compose restart mcsm-web
```
重启后节点配置自动加载。

**如果不行，再手动添加：**
面板 → 左侧「节点」→「添加节点」：

| 字段 | 值 |
|------|-----|
| 名称 | `主服务器` |
| IP | `catzizimiku.top`（必须是域名） |
| 端口 | `24444` |
| 密钥 | 见 `credentials.md` |

## 🐳 服务架构

| 服务 | 镜像 | 说明 |
|------|------|------|
| **mcsm-web** | `githubyumao/mcsmanager-web` | MCSManager Web 面板 |
| **mcsm-daemon** | `githubyumao/mcsmanager-daemon` | MCSManager 守护进程（管理 MC 实例） |
| **ddns-go** | `jeessy/ddns-go` | 动态域名解析 |

## 📦 Mod 列表

85 个 Mod，完整清单见 **[mod-list.md](mod-list.md)**。

### 不能装的 Mod（会导致崩溃）

- `entity_texture_features` — 客户端 Mixin
- `oculus` — 客户端光影
- `sodiumextras` — 客户端渲染
- `DGLabCraft` — 客户端 UI

## 🔧 防火墙

所有端口集成在 `mc-server` 这个 firewalld 服务里。GUI（`firewall-config`）中需要：
- **FedoraWorkstation** 区域 → 勾选 `mc-server`
- **FedoraServer** 区域 → 勾选 `mc-server`（网卡绑定的是这个）

| 端口 | 用途 |
|------|------|
| 25565/tcp | Minecraft 游戏 |
| 23333/tcp | MCSManager 面板 |
| 24444/tcp | MCSManager 守护进程 |
| 25575/tcp | RCON |
| 24454/udp | 语音聊天 |
| 9876/tcp+udp | DDNS-GO |

## 📄 项目结构

```
~/minecraft-server/
├── docker-compose.yml      # 服务定义
├── README.md
├── mod-list.md             # Mod 清单
├── credentials.md          # 🔑 凭据（已 gitignore）
├── docs/操作手册.md         # 详细运维指南
├── mods/                   # Mod jar 文件
├── mcsm/                   # MCSManager 数据
└── ddns-go-data/           # DDNS 配置
```
