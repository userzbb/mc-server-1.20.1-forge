#!/bin/bash
# Minecraft 服务器备份脚本
# 用法:
#   ./backup.sh                    ← 显示实例列表
#   ./backup.sh forge-1.20.1       ← 备份指定实例
#   ./backup.sh --list             ← 显示所有实例

BACKUP_DIR="/home/yuan/minecraft-server/backups"
MCSM_DIR="/home/yuan/minecraft-server/mcsm/daemon/data"

# 自动检测实例：扫描 InstanceConfig 目录
find_instance() {
  local name="$1"
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    local uuid=$(basename "$f" .json)
    if [ "$nickname" = "$name" ]; then
      echo "$uuid"
      return 0
    fi
  done
  return 1
}

list_instances() {
  echo "可用实例:"
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    [ -n "$nickname" ] && [ "$nickname" != "__MCSM_GLOBAL_INSTANCE__" ] && echo "  $nickname"
  done
}

# 无参数则列出实例
if [ $# -eq 0 ] || [ "$1" = "--list" ]; then
  list_instances
  exit 0
fi

# 查找实例
UUID=$(find_instance "$1")
if [ $? -ne 0 ]; then
  echo "❌ 未找到实例: $1"
  list_instances
  exit 1
fi

NAME="$1"
DATE=$(date +%Y%m%d_%H%M)
mkdir -p "$BACKUP_DIR"

echo "🔄 正在备份 [$NAME] ..."

tar -czf "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" \
  "$MCSM_DIR/InstanceData/$UUID" \
  "$MCSM_DIR/InstanceConfig/$UUID.json" \
  "$MCSM_DIR/../web/data/RemoteServiceConfig" \
  /home/yuan/minecraft-server/credentials.md \
  /home/yuan/minecraft-server/ddns-go-data 2>/dev/null

# 保留 30 天
find "$BACKUP_DIR" -name "backup-${NAME}-*.tar.gz" -mtime +30 -delete

SIZE=$(ls -lh "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" | awk '{print $5}')
echo "✅ 备份完成: backup-${NAME}-$DATE.tar.gz ($SIZE)"
