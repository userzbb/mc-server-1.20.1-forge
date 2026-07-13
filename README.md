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

### ⚙️ 核心 & 库
| Mod | 说明 |
|-----|------|
| **Architectury** 9.2.14 | 跨加载器 API 桥梁 |
| **Kotlin for Forge** 4.12.0 | Kotlin 语言支持 |
| **Cloth Config** 11.1.136 | 配置界面 API |
| **Yet Another Config Lib** 3.6.6 | YACL 配置库 |
| **Bookshelf** 20.2.15 | 开发库 |
| **Balm** 7.3.41 | 跨平台库 |
| **Resourceful Lib** 2.1.29 | 资源加载库 |
| **Rhino** 2001.2.3 | JavaScript 脚本引擎 (KubeJS 依赖) |
| **KubeJS** 2001.6.5 | JavaScript 脚本自定义 |
| **FTB Library** 2001.2.13 | FTB 系列基础库 |
| **Patchouli** 1.20.1-85 | 指南书系统 |
| **Curios API** 5.14.1 | 饰品栏 API |
| **Player Animation Lib** 1.0.2 | 玩家动画库 |
| **Glodium** 1.5 | GUI/渲染库 |
| **Lionfish API** 3.0 | API 库 |

### 🌟 大型内容模组
| Mod | 说明 |
|-----|------|
| **Applied Energistics 2** 15.4.10 | ⚡ 物流/存储自动化（ME 网络） |
| **AE2 Wireless Terminal Library** 15.3.3 | AE2 无线终端 |
| **AE2 Infinity Booster** 1.0.0 | AE2 无限范围升级 |
| **Applied Mekanistics** 1.4.3 | AE2 × Mekanism 联动 |
| **MegaCells** 2.4.6 | AE2 超大存储单元 |
| **ExtendedAE** 1.4.17 | AE2 扩展（更多设备） |
| **Mekanism** 10.4.16 | ⚙️ 科技模组（核电、矿石处理、能源） |
| **Ars Nouveau** 4.12.7 | 🔮 魔法模组（符文魔法） |
| **Twilight Forest** 4.3.2508 | 🌲 暮色森林（冒险维度） |
| **L_Ender's Cataclysm** 3.31 | 👹 灾厄（Boss 战） |
| **Cataclysm Dimension** 1.6.2 | 灾厄维度 |
| **Farmers Delight** 1.3.2 | 🍳 农夫乐事（烹饪扩展） |
| **Chipped** 3.0.7 | 🎨 建筑方块扩展 |
| **Kaleidoscope Cookery** 1.4.1 | 更多食物 |
| **Touhou Little Maid** 1.5.3 | 🎩 东方女仆（伙伴系统） |
| **Touhou Little Maid Spell** 1.8.0 | 女仆法术扩展 |
| **Maid Attributes** 1.0.0 | 女仆属性 |
| **Touhou Maid Useful Task** 1.4.2 | 女仆有用任务 |
| **Maid Restaurant** 0.2.8 | 女仆餐厅 |
| **Lradd** 0.3.0 | 东方扩展附加 |

### 🗡️ 武器 & 战斗
| Mod | 说明 |
|-----|------|
| **SlashBlade Resharped** 1.9.65 | 🗡️ 拔刀剑（重制版） |
| **Yakumoblade** 1.1.4 | 八云拔刀剑附属 |
| **MrQxs Slashblade Core** 1.4.1 | 拔刀剑核心 |
| **SJAP Resharpened** 1.2.16 | 拔刀剑扩展包 |
| **Energy Blade** 1.1.5 | ⚡ 能量剑（Mekanism 联动） |
| **TACZ** 1.1.8 | 🔫 现代枪械 (Timeless and Classics) |
| **TACZ Addon** 1.1.8 | TACZ 扩展附加 |
| **TACZ Tweaks** 2.14.2 | TACZ 调整优化 |
| **Resharped Renderfix Patch** 1.0.1 | 拔刀剑渲染修复 |

### 📦 存储 & 物流
| Mod | 说明 |
|-----|------|
| **Refined Storage** 1.12.4 | 💾 精致存储 |
| **Extra Disks** 3.0.3 | 精致存储更多磁盘 |
| **RS Requestify** 2.3.3 | 精致存储请求器 |
| **Sophisticated Backpacks** 3.24.59 | 🎒 精致背包 |
| **Sophisticated Core** 1.3.66 | 精致核心 |
| **Sophisticated JEI Index** 1.1.0 | 精致背包 × JEI 联动 |
| **Refined Ammo Box** 0.2.1 | ⚡ 弹药盒 |
| **Curios for Ammo Box** 1.2.0 | 弹药盒 × Curios 联动 |
| **Duplicationless** 1.2.0 | 禁止物品复制 |

### 🔌 能源 & 传输
| Mod | 说明 |
|-----|------|
| **Flux Networks** 7.2.1 | ⚡ 无线能源网络 |
| **AE2 Infinity Booster** 1.0.0 | AE2 无线范围无限 |

### 🌍 地图 & 信息
| Mod | 说明 |
|-----|------|
| **Xaero's Minimap** 26.2.0 | 🗺️ 小地图 |
| **Xaero's World Map** 1.42.0 | 大地图（全屏） |
| **The One Probe** 10.0.3 | 🔍 方块信息探查 |
| **Jade** 11.13.2 | 👁️ 方块信息显示（更多信息） |
| **GuideME** 20.1.15 | 游戏内指南 |

### 🎨 客户端优化 & 视觉
| Mod | 说明 |
|-----|------|
| **Embeddium** 0.3.31 | ⚡ 渲染优化 (Sodium Forge 移植) |
| **ModernFix** 5.27.58 | ⚡ 综合优化（降低内存、加速加载） |
| **FerriteCore** 6.0.1 | ⚡ 内存优化 |
| **Entity Culling** 1.10.5 | ⚡ 实体渲染裁剪 |
| **Entity Model Features** 3.2.4 | 🎨 实体模型增强 |
| **CI Chloride** 1.7.7 | ⚡ 渲染优化 |
| **Flerovium** 1.2.19 | ⚡ 优化 |
| **Sound Physics Remastered** 1.5.1 | 🔊 物理音效 |
| **Sodium Dynamic Lights** 1.0.10 | 🔦 动态光照 |
| **Sodium Options API** 1.0.10 | Sodium 选项 API |
| **Sodium Options Mod Compat** 1.0.0 | Sodium 选项兼容 |
| **AppleSkin** 2.5.1 | 🍎 饱食度显示 |
| **EMI** 1.1.24 | 📜 配方查看器 |
| **JEI** 15.20.0 | 📜 配方查看器 (Just Enough Items) |
| **Controlling** 12.0.2 | ⌨️ 按键控制 |
| **Searchables** 1.0.3 | 搜索增强 |
| **Crafting Tweaks** 18.2.9 | 🛠️ 合成面板增强 |
| **Enchantment Descriptions** 17.1.21 | 📖 附魔描述 |
| **TrashSlot** 15.1.5 | 🗑️ 一键丢弃 |
| **CreativeCore** 2.12.39 | 创意核心（基础库） |

### 🎮 服务器功能
| Mod | 说明 |
|-----|------|
| **Open Parties and Claims** 0.27.6 | 🏠 领地/队伍系统 |
| **PlayerRevive** 2.0.31 | 💀 倒地救援（非秒死） |
| **Voice Chat** 2.6.20 | 🎤 游戏内语音聊天 |
| **Bendy Lib** 4.0.0 | 弯曲方块支持 (Athena 依赖) |
| **Athena** 3.1.2 | 🔲 连接纹理支持 |
| **TLM For AE** 1.2 | 女仆 × AE2 联动 |
| **DGLab Craft** 1.1.1 | DGLab 联动物理反馈 |
| **Energyblade** 1.1.5 | 能量拔刀剑 |

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
