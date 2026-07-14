#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh                    ← 交互选择实例和模式
#   ./restore.sh forge-1.20.1 world ← 世界回档

BACKUP_DIR="/home/yuan/minecraft-server/backups"
MCSM_DIR="/home/yuan/minecraft-server/mcsm/daemon/data"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# 获取实例列表
get_instances() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    local uuid=$(basename "$f" .json)
    [ -n "$nickname" ] && [ "$nickname" != "__MCSM_GLOBAL_INSTANCE__" ] && echo "$uuid:$nickname"
  done
}

# 交互选择实例
select_instance() {
  local instances=()
  while IFS= read -r line; do instances+=("$line"); done < <(get_instances)
  echo "可用实例:"
  for i in "${!instances[@]}"; do
    local n=$(echo "${instances[$i]}" | cut -d: -f2)
    echo "  $((i+1)). $n"
  done
  read -p "选择实例 (1-${#instances[@]}): " choice
  local s="${instances[$((choice-1))]}"
  UUID=$(echo "$s" | cut -d: -f1)
  NAME=$(echo "$s" | cut -d: -f2)
}

# 交互选择模式
select_mode() {
  echo ""
  echo "恢复模式:"
  echo "  1. world     — 世界回档（只恢复 world/ + server.properties）"
  echo "  2. instance  — 重建实例后恢复全部数据"
  echo "  3. --full    — 完整迁移（含凭据、DDNS、节点配置）"
  read -p "选择模式 (1-3): " m
  case "$m" in
    1) MODE="world" ;;
    2) MODE="instance" ;;
    3) MODE="--full" ;;
    *) echo "无效选择"; exit 1 ;;
  esac
}

# 查找最新备份
find_backup() {
  echo "$BACKUP_DIR/backup-${NAME}-"*.tar.gz 2>/dev/null | sort -r | head -1
}

# 无参数 → 交互选择
if [ $# -eq 0 ]; then
  select_instance
  select_mode
elif [ $# -eq 1 ]; then
  NAME="$1"
  select_mode
else
  NAME="$1"
  MODE="$2"
  # 按名称匹配 UUID
  for inst in $(get_instances); do
    local n=$(echo "$inst" | cut -d: -f2)
    [ "$n" = "$NAME" ] && UUID=$(echo "$inst" | cut -d: -f1) && break
  done
fi

[ -z "$UUID" ] && echo "❌ 未找到实例: $NAME" && exit 1

BACKUP_FILE=$(find_backup)
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
    tar -xzf "$BACKUP_FILE" --wildcards "*/world/*" "*/server.properties" "*/eula.txt" -C / 2>/dev/null
    echo -e "${GREEN}✅ 世界已恢复。去面板启动实例即可。${NC}"
    ;;
  instance)
    echo "🔄 恢复实例全部数据..."
    tar -xzf "$BACKUP_FILE" -C / 2>/dev/null
    echo -e "${GREEN}✅ 实例数据已恢复。${NC}"
    echo "⚠️  如果 UUID 变了，需要手动更新新 UUID 的配置"
    ;;
  --full)
    echo "🔄 完整恢复..."
    tar -xzf "$BACKUP_FILE" -C / 2>/dev/null
    echo -e "${GREEN}✅ 全部数据已恢复。${NC}"
    echo "然后: 1. docker compose up -d  2. 面板重建实例  3. 复制 mods"
    ;;
esac
