#!/bin/bash
# Minecraft 服务器备份脚本
# 用法:
#   ./backup.sh            ← 默认备份 forge 实例
#   ./backup.sh forge      ← 备份 forge 实例
#   ./backup.sh tacz       ← 备份 tacz 实例

# 实例名 → UUID 映射
case "${1:-forge}" in
  forge|forge-1.20.1)
    UUID="01a48a38aa7542b1922be7de6f872b94"
    NAME="forge-1.20.1"
    ;;
  tacz|tacz-craft|taczcraft)
    UUID="71dedd089a9c4affaa3c811a8e722be8"
    NAME="tacz-craft"
    ;;
  *)
    UUID="$1"
    NAME="$1"
    ;;
esac

BACKUP_DIR="/home/yuan/minecraft-server/backups"
DATE=$(date +%Y%m%d_%H%M)
INSTANCE_DIR="/home/yuan/minecraft-server/mcsm/daemon/data/InstanceData/$UUID"
CONFIG_FILE="/home/yuan/minecraft-server/mcsm/daemon/data/InstanceConfig/$UUID.json"
REMOTE_CONFIG="/home/yuan/minecraft-server/mcsm/web/data/RemoteServiceConfig"

mkdir -p "$BACKUP_DIR"
echo "🔄 正在备份 [$NAME] ..."

# 备份（不停服，只备份世界存档和配置）
tar -czf "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" \
  "$INSTANCE_DIR/world" \
  "$INSTANCE_DIR/server.properties" \
  "$INSTANCE_DIR/eula.txt" \
  "$CONFIG_FILE" \
  "$REMOTE_CONFIG" \
  /home/yuan/minecraft-server/credentials.md \
  /home/yuan/minecraft-server/ddns-go-data 2>/dev/null

# 保留 30 天
find "$BACKUP_DIR" -name "backup-${NAME}-*.tar.gz" -mtime +30 -delete

SIZE=$(ls -lh "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" | awk '{print $5}')
echo "✅ 备份完成: backup-${NAME}-$DATE.tar.gz ($SIZE)"
echo "📁 位置: $BACKUP_DIR"
