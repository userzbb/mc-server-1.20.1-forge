# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Minecraft Forge 1.20.1 服务器，基于 Docker Compose 部署，含 85 个 Mod。
通过 DDNS-GO 绑定域名 `catzizimiku.top`，走 IPv6 对外服务。

## 关键文件

| 文件 | 说明 |
|------|------|
| `docker-compose.yml` | 4 个服务的定义 |
| `credentials.md` | 所有密码/密钥（已 gitignore，不要提交） |
| `mod-list.md` | 85 个 Mod 的完整分类清单 |
| `docs/操作手册.md` | 给 AI 看的详细运维指令 |
| `README.md` | 给人看的项目介绍 |

## 服务架构

4 个容器通过 `docker compose` 管理：

- **mc-forge** — Forge 1.20.1 服务器 (itzg/minecraft-server:java17)，端口 25565/25575/24454
- **mcsm-web** — MCSManager Web 面板 (23333)，通过 `extra_hosts: catzizimiku.top:host-gateway` 连接 daemon
- **mcsm-daemon** — MCSManager 守护进程 (24444)，挂载 docker.sock 管理容器
- **ddns-go** — 动态域名解析，`network_mode: host`，端口 9876

## 网络要点

- 所有服务通过域名 `catzizimiku.top` 走 IPv6，不需端口转发
- MCSManager 节点 IP 必须设置为域名，不能用 Docker 容器名或内网 IP
- Web 容器通过 `extra_hosts` 加 `host-gateway` 让后端也能解析域名到宿主机
- 防火墙：`enp2s0` 网卡绑定 `FedoraServer` 区域，`FedoraWorkstation` 和 `FedoraServer` 都需要启用 `mc-server` 服务

## 日常命令

```bash
# 启动/停止/重启
docker compose up -d
docker compose stop
docker compose restart mc-forge

# 日志
docker compose logs -f mc-forge

# 从 Web 容器测试 daemon 连通性
docker exec mcsm-web node -e "const http = require('http'); http.get('http://catzizimiku.top:24444/', r => { r.resume(); console.log(r.statusCode) }).on('error', e => console.log(e.message))"
```

## 凭据管理

`credentials.md` 记录所有敏感信息（已 gitignore，不会提交到 GitHub），包括：
- MCSManager 面板账号密码
- 守护进程密钥
- RCON 密码
- DDNS-GO 阿里云 API 密钥
- sudo 密码

**任何时候都不要把 `credentials.md` 里的内容硬编码到 README、操作手册或其他 git 跟踪的文件中。**

## 崩溃 Mod 清单

以下客户端 Mod 安装到服务器会导致崩溃：
- `entity_texture_features` — Mixin 引用客户端 Screen 类
- `oculus` — 客户端光影 Mixin
- `sodiumextras` — 客户端渲染 Mixin
- `DGLabCraft` — 客户端 UI Mixin

## Docker 镜像加速

配置在 `/etc/docker/daemon.json`，当前使用 `https://docker.1ms.run`。
如果拉取镜像超时，先检查镜像源是否可用。
