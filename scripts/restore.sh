#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh --list                      ← 列出可用备份
#   ./restore.sh forge-1.20.1 world          ← 场景一：世界回档
#   ./restore.sh forge-1.20.1 instance       ← 场景二：重建实例后恢复
#   ./restore.sh forge-1.20.1 --full         ← 场景三：完整迁移

BACKUP_DIR="/home/yuan/minecraft-server/backups"
MCSM_DIR="/home/yuan/minecraft-server/mcsm/daemon/data"

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# 自动检测实例
find_instance() {
  local name="$1"
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    local uuid=$(basename "$f" .json)
    if [ "$nickname" = "$name" ]; then echo "$uuid"; return 0; fi
  done
  return 1
}

find_backup() {
  local name="$1"
  local mode="$2"
  local file=$(ls -t "$BACKUP_DIR/backup-${name}-"*.tar.gz 2>/dev/null | head -1)
  echo "$file"
}

# 列出备份
if [ "$1" = "--list" ]; then
  echo "可用备份:"
  for f in "$BACKUP_DIR"/backup-*.tar.gz; do
    [ -f "$f" ] && echo "  $(basename "$f") ($(du -h "$f" | cut -f1))"
  done
  [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ] && echo "  （无备份）"
  exit 0
fi

# 校验参数
if [ $# -lt 2 ]; then
  echo "用法: $0 <实例名> <world|instance|--full>"
  exit 1
fi

NAME="$1"; MODE="$2"
UUID=$(find_instance "$NAME")
[ $? -ne 0 ] && echo "❌ 未找到实例: $NAME" && exit 1

BACKUP_FILE=$(find_backup "$NAME" "$MODE")
[ -z "$BACKUP_FILE" ] && echo "❌ 未找到 $NAME 的备份" && exit 1

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  恢复 [$NAME] - $(basename "$BACKUP_FILE")${NC}"
echo -e "${GREEN}  模式: $MODE${NC}"
echo -e "${GREEN}========================================${NC}"
echo "⚠️  请先确认面板上已停止实例!"
read -p "继续? (y/N) " confirm
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "已取消" && exit 0

case "$MODE" in
  world)
    echo "🔄 恢复世界存档..."
    tar -xzf "$BACKUP_FILE" -C / --wildcards "*/world/*" "*/server.properties" "*/eula.txt" 2>/dev/null
    echo -e "${GREEN}✅ 世界已恢复。去面板启动实例即可。${NC}"
    ;;

  instance)
    echo "🔄 恢复实例全部数据..."
    tar -xzf "$BACKUP_FILE" -C / 2>/dev/null
    echo -e "${GREEN}✅ 实例数据已恢复。${NC}"
    echo "⚠️  如果 UUID 变了，需要手动更新 InstanceConfig/<新UUID>.json"
    ;;

  --full)
    echo "🔄 完整恢复..."
    tar -xzf "$BACKUP_FILE" -C / 2>/dev/null
    echo -e "${GREEN}✅ 全部数据已恢复。${NC}"
    echo "然后需要:"
    echo "  1. docker compose up -d     # 启动 MCSManager"
    echo "  2. 面板重建实例并配置 Docker 设置"
    echo "  3. 复制 mods 文件"
    ;;
esac
