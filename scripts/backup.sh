#!/bin/bash
# Minecraft 服务器备份脚本
# 用法:
#   ./backup.sh                    ← 交互选择实例
#   ./backup.sh forge-1.20.1       ← 备份指定实例

BACKUP_DIR="/home/yuan/minecraft-server/backups"
MCSM_DIR="/home/yuan/minecraft-server/mcsm/daemon/data"

# 获取实例列表
get_instances() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    local uuid=$(basename "$f" .json)
    [ -n "$nickname" ] && [ "$nickname" != "__MCSM_GLOBAL_INSTANCE__" ] && echo "$uuid:$nickname"
  done
}

# 交互选择
select_instance() {
  local instances=()
  while IFS= read -r line; do instances+=("$line"); done < <(get_instances)

  echo "可用实例:"
  for i in "${!instances[@]}"; do
    local name=$(echo "${instances[$i]}" | cut -d: -f2)
    echo "  $((i+1)). $name"
  done
  echo ""
  read -p "选择实例 (1-${#instances[@]}): " choice
  local selected="${instances[$((choice-1))]}"
  UUID=$(echo "$selected" | cut -d: -f1)
  NAME=$(echo "$selected" | cut -d: -f2)
}

# 无参数 → 交互选择
if [ $# -eq 0 ]; then
  select_instance
else
  NAME="$1"
  # 按名称匹配
  for inst in $(get_instances); do
    local n=$(echo "$inst" | cut -d: -f2)
    if [ "$n" = "$NAME" ]; then
      UUID=$(echo "$inst" | cut -d: -f1)
      break
    fi
  done
  if [ -z "$UUID" ]; then
    echo "❌ 未找到实例: $NAME"
    select_instance
  fi
fi

DATE=$(date +%Y%m%d_%H%M)
mkdir -p "$BACKUP_DIR"
echo "🔄 正在备份 [$NAME] ..."

tar -czf "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" \
  "$MCSM_DIR/InstanceData/$UUID" \
  "$MCSM_DIR/InstanceConfig/$UUID.json" \
  "$MCSM_DIR/../web/data/RemoteServiceConfig" \
  /home/yuan/minecraft-server/credentials.md \
  /home/yuan/minecraft-server/ddns-go-data 2>/dev/null

find "$BACKUP_DIR" -name "backup-${NAME}-*.tar.gz" -mtime +30 -delete
SIZE=$(ls -lh "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" | awk '{print $5}')
echo "✅ 备份完成: backup-${NAME}-$DATE.tar.gz ($SIZE)"
