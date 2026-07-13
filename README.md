# 🧱 Minecraft Forge 服务器

> **版本：** Forge 1.20.1 (47.4.21)
> **运行环境：** Docker (itzg/minecraft-server:java17)

## 🚀 快速启动

```bash
# 启动服务器（后台运行）
docker compose up -d

# 查看日志
docker compose logs -f mc-forge

# 停止服务器
docker compose stop

# 完全停止并删除容器
docker compose down
```

首次启动需要下载安装 Forge 并加载所有 mod，**约 3-5 分钟**。请耐心等待，看到以下日志即为启动完成：

```
[DedicatedServer]: Done (XX.XXXs)! For help, type "help"
```

服务器端口 `25565` 默认对外开放。防火墙需要放行以下端口：

| 端口 | 协议 | 用途 |
|------|------|------|
| 25565 | TCP | Minecraft 游戏连接 |
| 25575 | TCP | RCON 远程管理 |
| 24454 | UDP | 语音聊天 (Voice Chat) |

## 📦 Mod 列表

本服务器安装了 **85 个 Mod**，详细清单请查看 [mod-list.md](mod-list.md)。

## 🔧 配置

### 环境变量（docker-compose）

| 变量 | 值 | 说明 |
|------|-----|------|
| `MEMORY` | 4G | 分配内存 |
| `MAX_PLAYERS` | 20 | 最大玩家数 |
| `ONLINE_MODE` | false | 离线模式（允许非正版） |
| `VERSION` | 1.20.1 | Minecraft 版本 |
| `FORGE_VERSION` | 47.4.21 | Forge 版本 |

### RCON 管理

已开启 RCON，端口 `25575`。密码在 `data/server.properties` 中的 `rcon.password` 字段。

## 🐳 Docker Compose 服务

| 服务 | 说明 |
|------|------|
| **mc-forge** | Minecraft Forge 服务器 |
| **ddns-go** | 动态域名解析服务 |

### 🌐 DDNS-GO 动态域名解析

DDNS-GO 用于将你的公网 IP 自动绑定到域名，这样玩家可以通过域名连接服务器，IP 变了也不受影响。

**配置文件位置：** `ddns-go-data/.ddns_go_config.yaml`

**当前配置：**
| 项目 | 内容 |
|------|------|
| 域名 | `catzizimiku.top` |
| DNS 服务商 | 阿里云 DNS (Alidns) |
| IPv4 | ✅ 启用（URL 获取公网 IP） |
| IPv6 | ✅ 启用 |
| Web 管理端口 | `9876`（host 网络直通） |

**配置方式：**
1. 直接访问 `http://你的IP:9876` 进入 Web 管理界面
2. 或在 `ddns-go-data/.ddns_go_config.yaml` 中编辑配置
3. 修改后重启生效：
   ```bash
   docker compose restart ddns-go
   ```

> ⚠️ 配置文件包含 DNS 服务商的 API 密钥，已加入 `.gitignore`，不会提交到 git。

## 🔄 更新 Mod

1. 下载新的 `.jar` 文件放到 `mods/` 目录
2. 重启服务器：
   ```bash
   docker compose down
   docker compose up -d
   ```
# mc-server-1.20.1-forge
# mc-server-1.20.1-forge
