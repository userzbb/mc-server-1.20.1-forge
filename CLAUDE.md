# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Minecraft Forge 1.20.1 服务器，通过 **MCSManager** Web 面板管理，基于 Docker Compose 部署。
域名 `catzizimiku.top`，走 IPv6 对外服务。DDNS-GO 自动更新域名解析。

## 服务架构

3 个容器，由 `docker compose` 管理：

- **mcsm-web** — MCSManager Web 面板，端口 `23333`，用 `extra_hosts: catzizimiku.top:host-gateway` 连接 daemon
- **mcsm-daemon** — MCSManager 守护进程，端口 `24444`，挂载 `docker.sock` 创建/管理 MC 实例容器
- **ddns-go** — 动态域名解析，`network_mode: host`，端口 `9876`，阿里云 DNS

Minecraft 服务器不直接由 docker-compose 管理，而是通过 MCSManager 面板创建 Docker 实例。实例配置模板在 `instance-config.json`。

## 关键文件

| 文件 | 说明 | Git |
|------|------|-----|
| `docker-compose.yml` | 3 个服务的定义 | ✅ |
| `credentials.md` | 所有密码和密钥 | ❌ gitignore |
| `instance-config.json` | Docker 实例配置模板 | ✅ |
| `server.properties.template` | 服务端配置模板 | ✅ |
| `mod-list.md` | 85 个 Mod 清单 | ✅ |
| `mods/*.jar` | Mod 二进制文件 | ❌ gitignore |
| `mcsm/` | MCSManager 运行时数据 | ❌ gitignore |
| `docs/操作手册.md` | 详细 AI 指令 | ✅ |
| `docs/GUI操作指南.md` | 面板操作说明 | ✅ |
| `docs/迁移指南.md` | 迁移步骤 | ✅ |

## 网络架构

- 所有服务通过域名 `catzizimiku.top` 走 IPv6，不需端口转发
- MCSManager 节点 IP 必须为域名，不能用容器名或内网 IP
- Web 容器通过 `extra_hosts: catzizimiku.top:host-gateway` 让后端能解析域名到宿主机
- 防火墙：`enp2s0` 绑定 `FedoraServer` 区域，两个区域都需要 `mc-server` 服务

## 日常命令

```bash
# 启动/停止/重启
docker compose up -d
docker compose stop
docker compose restart mcsm-web

# 查看状态和日志
docker compose ps
docker compose logs -f mcsm-daemon

# 测试 daemon 连通性（从 Web 容器）
docker exec mcsm-web node -e "const http = require('http'); http.get('http://catzizimiku.top:24444/', r => { r.resume(); console.log(r.statusCode) }).on('error', e => console.log(e.message))"

# 恢复丢失的节点
docker compose restart mcsm-web
```

## MCSManager 实例管理

实例必须通过面板 UI 创建，API 不支持。Docker 设置需要创建后手动配置：
- 镜像: `itzg/minecraft-server:java17`
- Minecraft 端口: 25565/TCP, 25575/TCP, 24454/UDP
- 环境变量: EULA, TYPE=FORGE, VERSION=1.20.1, FORGE_VERSION=47.4.21, ONLINE_MODE=false 等
- 挂载卷: `/home/yuan/minecraft-server/mods` → `/mods` (ro)

## 凭据管理

所有密码在 `credentials.md`（已 gitignore）：
- MCSManager 面板: zizimiku
- 守护进程密钥
- RCON 密码
- DDNS-GO 阿里云 API 密钥
- sudo 密码

**不要硬编码敏感信息到 git 跟踪的文件中。**

## 常见问题

- **节点离线：** `docker compose restart mcsm-web`
- **Docker 实例挂载路径错误：** 确保 `MCSM_DOCKER_WORKSPACE_PATH` 是宿主机路径
- **Pull 镜像超时：** 配置了国内镜像 `https://docker.1ms.run`，在 `/etc/docker/daemon.json`
- **崩溃 Mod：** `entity_texture_features`、`oculus`、`sodiumextras`、`DGLabCraft` 不能装
