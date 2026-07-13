# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Minecraft Forge 1.20.1 服务器，通过 **MCSManager** Web 面板管理，基于 Docker Compose 部署。
域名 `catzizimiku.top`，走 IPv6 对外服务。DDNS-GO 自动更新域名解析。

## 服务架构

3 个容器，由 `docker compose` 管理：

- **mcsm-web** — MCSManager Web 面板，端口 `23333`，`extra_hosts: catzizimiku.top:host-gateway`
- **mcsm-daemon** — MCSManager 守护进程，端口 `24444`，挂载 `docker.sock`，环境变量 `MCSM_DOCKER_WORKSPACE_PATH=/home/yuan/minecraft-server/mcsm/daemon/data/InstanceData`
- **ddns-go** — 动态域名解析，`network_mode: host`，端口 `9876`

Minecraft 服务器通过 MCSManager 面板创建 Docker 实例，不直接由 docker-compose 管理。

## 关键文件

| 文件 | 说明 | Git |
|------|------|-----|
| `docker-compose.yml` | 3 个服务的定义 | ✅ |
| `credentials.md` | 所有密码和密钥 | ❌ gitignore |
| `instance-config.json` | Docker 实例配置模板 | ✅ |
| `server.properties.template` | 服务端配置模板 | ✅ |
| `mod-list.md` | 84 个 Mod 清单 | ✅ |
| `mods/*.jar` | Mod 二进制文件 | ❌ gitignore |
| `mcsm/` | MCSManager 运行时数据（含实例数据） | ❌ gitignore |
| `docs/` | 操作手册、GUI指南、迁移指南 | ✅ |

## Mod 管理

Mod 文件放在 `mods/` 目录，通过 Docker 卷挂载到容器的 `/mods`。

**添加：** 复制 `.jar` 到 `mods/` → 重启实例（镜像自动复制到实例的 `/data/mods`）

**删除：** 需要同时删除两处：
1. `mods/<文件名>.jar`（源文件）
2. `mcsm/daemon/data/InstanceData/<UUID>/mods/<文件名>.jar`（实例数据目录）

否则重启后旧文件还在。镜像只会复制文件，不会同步删除。

**⚠️ 重要：添加 Mod 前必须询问用户**
创建新实例时，**不要**默认挂载整个 `mods/` 目录。只有用户明确要求添加特定 Mod 时，才通过面板文件管理上传或配置挂载卷。

## 安装整合包

在 Docker 环境变量中设置 `CF_SERVER_MOD` 即可让镜像自动下载安装 CurseForge 整合包：

```json
"env": ["CF_SERVER_MOD=https://www.curseforge.com/minecraft/modpacks/<整合包名>"]
```

首次启动自动安装。之后如需添加额外 Mod：
- **自动（挂载卷）：** 在 `extraVolumes` 加 `"/host/path|/mods|ro"`
- **手动（面板）：** 实例 → 文件管理 → 上传 `.jar` 到 `mods/`


## 网络架构

- 域名 `catzizimiku.top` 走 IPv6，不需端口转发
- MCSManager 节点 IP 必须为域名，不能用容器名或内网 IP
- 防火墙：`enp2s0` 绑定 `FedoraServer` 区域，两个区域都需要 `mc-server` 服务

## 日常命令

```bash
docker compose up -d                                    # 启动
docker compose restart mcsm-web                         # 重启面板（恢复节点）
docker compose logs -f mcsm-daemon                      # daemon 日志
docker exec mcsm-web node -e "const http = require('http'); http.get('http://catzizimiku.top:24444/', r => { r.resume(); console.log(r.statusCode) }).on('error', e => console.log(e.message))"
```

## MCSManager 实例管理

实例**必须通过面板 UI 创建**，API 不支持直接创建。创建步骤：
1. 面板 → 终端 → 主服务器 → 创建实例
2. 选 Minecraft Java 版 / Forge 1.20.1，填名称，其他全部留空
3. 创建后手动编辑 `mcsm/daemon/data/InstanceConfig/<UUID>.json` 配置 Docker

### JSON 配置格式（注意：全部是字符串格式！）

```json
{
  "cwd": "data/InstanceData/<UUID>",
  "docker": {
    "image": "itzg/minecraft-server:java17",
    "ports": ["25565:25565/tcp", "25575:25575/tcp", "24454:24454/udp"],
    "env": ["EULA=TRUE", "TYPE=FORGE", "VERSION=1.20.1", "FORGE_VERSION=47.4.21", "ONLINE_MODE=false", "MEMORY=4G", "MAX_PLAYERS=20", "TZ=Asia/Shanghai"],
    "extraVolumes": ["/home/yuan/minecraft-server/mods|/mods|ro"],
    "workingDir": "/data",
    "networkMode": "bridge"
  }
}
```

关键要求：
- `cwd` **不能为空或 null**，设成 `data/InstanceData`（daemon 自动追加实例 UUID）
- `ports` 是字符串 `"宿主机:容器/协议"`，不是对象
- `env` 是 `"KEY=VALUE"` 字符串，不是 `{key, value}` 对象
- `extraVolumes` 用 `|` 分隔，格式 `"宿主机路径|容器路径|模式"`
- 不要设置 `changeWorkdir: true`，会导致 bind mount 错误

### 文件权限

`server.properties` 和 `eula.txt` 需要改为 `uid=1000`，否则容器进程无法写入：
```bash
sudo chown 1000:1000 mcsm/daemon/data/InstanceData/<UUID>/server.properties
sudo chown 1000:1000 mcsm/daemon/data/InstanceData/<UUID>/eula.txt
```

### 实例日志

`mcsm/daemon/data/InstanceLog/<UUID>.log`

### 配置 daemon 后重启

修改实例配置后需要重启 daemon 才能生效：
```bash
docker compose restart mcsm-daemon
```

## 凭据管理

所有密码和密钥在 `credentials.md`（已 gitignore），不要硬编码到任何跟踪的文件中。

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 面板节点离线 | 配置丢失 | `docker compose restart mcsm-web` |
| 容器端口配置有误 | `ports` 格式错误（写了对象） | 改为字符串 `"25565:25565/tcp"` |
| bind source path does not exist: /data | `changeWorkdir: true` 导致 | 去掉该配置 |
| cwd is Null! | `cwd` 为空或 null | 设为 `"data/InstanceData/<UUID>"` |
| AccessDeniedException: server.properties | 文件权限为 root | `chown 1000:1000` |
| Pull 镜像超时 | 国内网络 | 镜像源 `https://docker.1ms.run` |
| 崩溃 Mod | 客户端 Mixin | 不要装 ETF、oculus、sodiumextras、DGLabCraft |
