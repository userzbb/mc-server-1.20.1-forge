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

上传 Mod 有两种方式：
1. **面板上传（手动）：** 在 `mods/` 目录点 **「上传文件」**，选择 `.jar`
2. **挂载卷（自动）：** 在 Docker 设置的「额外挂载卷」里加 `/home/yuan/minecraft-server/mods|/mods|ro`
   > ⚠️ 只在用户明确要求时才挂载，不要默认加

**安装整合包：** 在 Docker 环境变量添加 `CF_SERVER_MOD=整合包CurseForge链接`，首次启动自动下载安装。

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

### forge-1.20.1 实例
91 个 Mod，清单见 **[instances/forge-1.20.1/mod-list.md](instances/forge-1.20.1/mod-list.md)**。

### tacz-craft 实例
85 个 Mod，清单见 **[instances/tacz-craft/mod-list.md](instances/tacz-craft/mod-list.md)**。

### 不能装到服务器的客户端 Mod

| Mod | 原因 |
|-----|------|
| `entity_texture_features` | Mixin 引用 Screen 类 → 崩溃 |
| `oculus` | 客户端光影 Mixin → 崩溃 |
| `sodiumextras` | 客户端渲染 Mixin → 崩溃 |
| `DGLabCraft` | 客户端 UI Mixin → 崩溃 |
| `imblocker` | 输入法冲突，纯客户端 |
| `tacticalmovement` | 客户端移动辅助 |
| `jecharacters` | 拼音搜索，缺服务端类 |
| `sound-physics-remastered` | 物理音效，纯客户端 |
| `entityculling` | 实体渲染裁剪，纯客户端 |
| `entity_model_features` | 实体模型，纯客户端 |
| `appleskin` | 饱食度 HUD，纯客户端 |

## 🔧 配置管理

### 全局变量

路径配置统一在 `scripts/config.sh`，迁移时只需修改此文件：

```bash
PROJECT_DIR="/home/yuan/minecraft-server"   # ← 改成新机器的路径
```

### 仍需手动修改的路径

以下文件包含硬编码路径，迁移时也需要改：

| 文件 | 路径 | 说明 |
|------|------|------|
| `docker-compose.yml` | `/home/yuan/minecraft-server/mods` | Mod 挂载卷 |
| `docker-compose.yml` | `MCSM_DOCKER_WORKSPACE_PATH` | 实例工作目录 |
| `instance-config.json` | `/home/yuan/minecraft-server/mods` | Docker 配置模板 |

## 💾 备份 & 恢复

两个脚本在 `scripts/` 目录，自动读取实例名称（forge-1.20.1、tacz-craft）。

### backup.sh — 备份

扫描 `mcsm/daemon/data/InstanceConfig/` 自动匹配实例名 → UUID，不需要手动输 ID。

```bash
./scripts/backup.sh                    # 交互菜单选择实例
./scripts/backup.sh --list             # 列出可备份的实例
./scripts/backup.sh forge-1.20.1       # 直接备份指定实例
```

备份内容：世界存档、实例 Docker 配置、MCSManager 节点配置、credentials.md、ddns-go-data。
备份位置：`backups/backup-实例名-日期.tar.gz`
自动保留：同一实例仅保留最近 **2 个** 备份，旧的自动清理。

### restore.sh — 恢复

```bash
./scripts/restore.sh                     # 交互菜单选择实例 + 恢复模式
./scripts/restore.sh --list              # 列出可用备份
./scripts/restore.sh forge-1.20.1 world  # 直接指定：世界回档
./scripts/restore.sh forge-1.20.1 instance # 直接指定：重建实例
./scripts/restore.sh forge-1.20.1 --full # 直接指定：完整迁移
```

三种恢复模式：
- **world** — 恢复 `world/` + server.properties（实例配置不动）
- **instance** — 恢复实例全部数据，UUID 变更自动迁移
- **--full** — 恢复全部（含凭据、DDNS、节点配置）

- 自动找最新备份，提示先停止实例
- UUID 变更时自动迁移数据目录
- 备份中缺少实例配置时，自动从 `instance-config.json` 模板补全 Docker 配置  
- 已删除的实例在列表中标注「已删除」，需先重建再恢复

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

## 📚 详细文档

| 文档 | 适合谁 | 内容 |
|------|--------|------|
| [GUI操作指南](docs/GUI操作指南.md) | 人类 | 面板每一步怎么点、字段填什么 |
| [操作手册](docs/操作手册.md) | AI / Agent | 项目结构、命令、排查步骤 |
| [迁移指南](docs/迁移指南.md) | 人类 / AI | 换机器时如何恢复整个服务器 |
| [实例配置说明](docs/实例配置说明.md) | 人类 / AI | Docker 配置详情（端口、环境变量、挂载卷） |

## 📄 项目结构

```
~/minecraft-server/
├── docker-compose.yml          # 服务定义
├── instance-config.json        # Docker 实例配置模板
├── server.properties.template  # 服务端配置模板
├── README.md
├── CLAUDE.md                   # AI 指令
├── credentials.md              # 🔑 凭据（已 gitignore）
├── scripts/
│   ├── backup.sh               # 备份脚本
│   └── restore.sh              # 恢复脚本
├── instances/
│   ├── forge-1.20.1/
│   │   └── mod-list.md         # forge 实例 Mod 清单（91 个）
│   └── tacz-craft/
│       ├── mod-list.md         # tacz 实例 Mod 清单（85 个）
│       └── server.properties.template
├── docs/                       # 操作手册、GUI指南、迁移指南
├── mods/                       # Mod jar 文件
├── mcsm/                       # MCSManager 数据
├── ddns-go-data/               # DDNS 配置
└── backups/                    # 备份文件（gitignore）
```
