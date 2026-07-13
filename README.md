# 🧱 Minecraft Forge 服务器

> **版本：** Forge 1.20.1 (47.4.21)
> **域名：** `catzizimiku.top`（IPv6 直连）
> **运行环境：** Docker (itzg/minecraft-server:java17)

## 🚀 一键启动

```bash
cd ~/minecraft-server
docker compose up -d
```

首次启动约 **3-5 分钟**，看到 `Done (XX.XXXs)! For help, type "help"` 即为完成。

## 🔗 访问地址

| 服务 | 地址 |
|------|------|
| Minecraft 游戏 | `catzizimiku.top:25565` |
| MCSManager 面板 | `http://catzizimiku.top:23333`（HTTP） |
| DDNS-GO 管理 | `http://catzizimiku.top:9876` |

> ⚠️ 所有服务走 IPv6，不需要端口转发。MCSManager 用 **HTTP** 不是 HTTPS。

## 📦 Mod 清单

85 个 Mod，详见 [mod-list.md](mod-list.md)。

## 🐳 服务架构

| 服务 | 说明 |
|------|------|
| **mc-forge** | Forge 1.20.1 服务器 |
| **mcsm-web** | MCSManager Web 面板 |
| **mcsm-daemon** | MCSManager 守护进程 |
| **ddns-go** | 动态域名解析（阿里云 DNS） |

## 📖 操作手册

详细配置和运维说明请见 [docs/操作手册.md](docs/操作手册.md)。
