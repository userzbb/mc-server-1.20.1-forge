#!/bin/bash
# Minecraft 服务器备份脚本
# 用法: ./backup.sh [实例UUID]
# 默认备份 forge-1.20.1

BACKUP_DIR="/home/yuan/minecraft-server/backups"
DATE=$(date +%Y%m%d_%H%M)
UUID="${1:-01a48a38aa7542b1922be7de6f872b94}"
WORLD_DIR="/home/yuan/minecraft-server/mcsm/daemon/data/InstanceData/$UUID/world"
CONFIG_FILE="/home/yuan/minecraft-server/mcsm/daemon/data/InstanceConfig/$UUID.json"
REMOTE_CONFIG="/home/yuan/minecraft-server/mcsm/web/data/RemoteServiceConfig"

mkdir -p "$BACKUP_DIR"

# 停服
docker stop mc-forge 2>/dev/null
sleep 2

# 打包
tar -czf "$BACKUP_DIR/backup-$DATE.tar.gz" \
  "$WORLD_DIR" \
  "$CONFIG_FILE" \
  "$REMOTE_CONFIG" \
  /home/yuan/minecraft-server/credentials.md \
  /home/yuan/minecraft-server/ddns-go-data 2>/dev/null

# 启服
docker start mc-forge 2>/dev/null

# 保留最近 30 天的备份，删除旧的
find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime +30 -delete

echo "✅ 备份完成: backup-$DATE.tar.gz ($(ls -lh $BACKUP_DIR/backup-$DATE.tar.gz | awk '{print $5}'))"
echo "📁 备份位置: $BACKUP_DIR"
