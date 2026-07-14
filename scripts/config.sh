#!/bin/bash
# Minecraft 服务器配置文件
# 所有脚本从这里读取路径配置
# ⚠️ 迁移时只需修改 .env 文件中的 PROJECT_DIR，此处自动读取

# 从 .env 读取项目根目录
if [ -f "$(dirname "$0")/../.env" ]; then
  source "$(dirname "$0")/../.env"
fi
PROJECT_DIR="${PROJECT_DIR:-/home/yuan/minecraft-server}"

# MCSManager 数据目录
MCSM_DIR="$PROJECT_DIR/mcsm/daemon/data"

# 备份目录
BACKUP_DIR="$PROJECT_DIR/backups"

# 实例配置目录
INSTANCE_CONFIG_DIR="$MCSM_DIR/InstanceConfig"

# 实例数据目录
INSTANCE_DATA_DIR="$MCSM_DIR/InstanceData"

# 节点配置目录
REMOTE_CONFIG_DIR="$PROJECT_DIR/mcsm/web/data/RemoteServiceConfig"

# DDNS 数据目录
DDNS_DATA_DIR="$PROJECT_DIR/ddns-go-data"

# 凭据文件
CREDENTIALS_FILE="$PROJECT_DIR/credentials.md"

# 实例配置模板
INSTANCE_TEMPLATE="$PROJECT_DIR/instance-config.json"
