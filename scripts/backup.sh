#!/bin/bash
# Minecraft 服务器备份脚本
# 用法:
#   ./backup.sh forge-1.20.1       ← 备份指定实例
#   ./backup.sh --list             ← 列出可备份的实例

source "$(dirname "$0")/config.sh"

# 获取实例列表
get_instances() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    local uuid=$(basename "$f" .json)
    [ -n "$nickname" ] && [ "$nickname" != "__MCSM_GLOBAL_INSTANCE__" ] && echo "$uuid:$nickname"
  done
}

# 列出实例
if [ "$1" = "--list" ]; then
  echo "可备份的实例:"
  for inst in $(get_instances); do
    echo "  $(echo $inst | cut -d: -f2)"
  done
  exit 0
fi

# 获取要备份的实例
if [ -z "$1" ]; then
  echo "用法: $0 <实例名>"
  echo "  $0 forge-1.20.1"
  echo "  $0 --list"
  exit 1
fi

NAME="$1"
UUID=""
for inst in $(get_instances); do
  n=$(echo "$inst" | cut -d: -f2)
  [ "$n" = "$NAME" ] && UUID=$(echo "$inst" | cut -d: -f1) && break
done

if [ -z "$UUID" ]; then
  echo "❌ 未找到实例: $NAME"
  echo "可备份的实例:"
  for inst in $(get_instances); do
    echo "  $(echo $inst | cut -d: -f2)"
  done
  exit 1
fi

DATE=$(date +%Y%m%d_%H%M)
mkdir -p "$BACKUP_DIR"

echo "🔄 正在备份 [$NAME] (UUID: $UUID)..."

# 备份：只打包 InstanceData/<UUID> 和 InstanceConfig/<UUID>.json
# 不包含完整路径，只保留相对路径，恢复时根据 .env 配置重新组装
tar -czf "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" \
  -C "$MCSM_DIR" \
  "InstanceData/$UUID" \
  "InstanceConfig/$UUID.json" \
  2>/dev/null

# 只保留最近 2 个备份
ls -t "$BACKUP_DIR"/backup-${NAME}-*.tar.gz 2>/dev/null | tail -n +3 | xargs rm -f 2>/dev/null

SIZE=$(ls -lh "$BACKUP_DIR/backup-${NAME}-$DATE.tar.gz" | awk '{print $5}')
echo "✅ 备份完成: backup-${NAME}-$DATE.tar.gz ($SIZE)"
