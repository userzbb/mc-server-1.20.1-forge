#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh                    ← 交互选择实例和模式
#   ./restore.sh forge-1.20.1 world ← 世界回档

BACKUP_DIR="/home/yuan/minecraft-server/backups"
MCSM_DIR="/home/yuan/minecraft-server/mcsm/daemon/data"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# 获取实例列表（当前 + 备份中已删除的）
get_instances() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    local uuid=$(basename "$f" .json)
    [ -n "$nickname" ] && [ "$nickname" != "__MCSM_GLOBAL_INSTANCE__" ] && echo "$uuid:$nickname"
  done
  # 补充已删除但有备份的实例（不重复列出现有的）
  local existing=$(for f in "$MCSM_DIR/InstanceConfig"/*.json; do python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null; done)
  for bf in "$BACKUP_DIR"/backup-*.tar.gz; do
    local bname=$(basename "$bf" | sed 's/^backup-//;s/-[0-9]\{8\}.*\.tar\.gz$//')
    [ -n "$bname" ] && echo "$existing" | grep -qx "$bname" || echo ":$bname"
  done | sort -u
}

# 交互选择实例
select_instance() {
  local instances=()
  while IFS= read -r line; do instances+=("$line"); done < <(get_instances)
  echo "可用实例:"
  for i in "${!instances[@]}"; do
    local u=$(echo "${instances[$i]}" | cut -d: -f1)
    local n=$(echo "${instances[$i]}" | cut -d: -f2)
    local tag=""
    [ -z "$u" ] && tag=" (已删除)"
    echo "  $((i+1)). $n$tag"
  done
  read -p "选择实例 (1-${#instances[@]}): " choice
  local s="${instances[$((choice-1))]}"
  UUID=$(echo "$s" | cut -d: -f1)
  NAME=$(echo "$s" | cut -d: -f2)
  if [ -z "$UUID" ]; then
    echo "❌ 实例 [$NAME] 已从面板删除，无法恢复。请先在面板重建同名实例后重试。"
    exit 1
  fi
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
    # 找出备份中的旧 UUID
    OLD_UUID=$(tar -tzf "$BACKUP_FILE" | grep "InstanceData/" | head -1 | cut -d/ -f9)
    tar -xzf "$BACKUP_FILE" -C / 2>/dev/null
    # 如果 UUID 变了，自动迁移数据
    if [ -n "$OLD_UUID" ] && [ "$OLD_UUID" != "$UUID" ]; then
      echo "ℹ️  UUID 已变更 ($OLD_UUID → $UUID)，正在迁移数据..."
      [ -d "$MCSM_DIR/InstanceData/$OLD_UUID" ] && mv "$MCSM_DIR/InstanceData/$OLD_UUID"/* "$MCSM_DIR/InstanceData/$UUID"/ 2>/dev/null && rm -rf "$MCSM_DIR/InstanceData/$OLD_UUID"
    fi
    # 如果备份中没有 InstanceConfig（实例已删除后备份的），自动应用模板配置
    if ! tar -tzf "$BACKUP_FILE" 2>/dev/null | grep -q "InstanceConfig/"; then
      echo "ℹ️  备份中无实例配置，从 instance-config.json 模板自动配置 Docker 模式..."
      if [ -f "/home/yuan/minecraft-server/instance-config.json" ]; then
        local tmpconfig=$(mktemp)
        python3 -c "
import json
with open('$MCSM_DIR/InstanceConfig/$UUID.json') as f:
    c = json.load(f)
with open('/home/yuan/minecraft-server/instance-config.json') as t:
    tmpl = json.load(t)
c['processType'] = 'docker'
c['cwd'] = 'data/InstanceData/$UUID'
c['docker'] = tmpl['docker']
c['docker']['containerName'] = 'mc-$NAME'
with open('$tmpconfig', 'w') as f:
    json.dump(c, f, indent=2, ensure_ascii=False)
" 2>/dev/null
        cp "$tmpconfig" "$MCSM_DIR/InstanceConfig/$UUID.json"
        rm -f "$tmpconfig"
        echo "✅ Docker 配置已从模板应用"
      fi
    else
      # 备份中有 InstanceConfig
      [ -f "$MCSM_DIR/InstanceConfig/$OLD_UUID.json" ] && mv "$MCSM_DIR/InstanceConfig/$OLD_UUID.json" "$MCSM_DIR/InstanceConfig/$UUID.json" 2>/dev/null
    fi
    echo -e "${GREEN}✅ 实例数据已恢复。${NC}"
    ;;
  --full)
    echo "🔄 完整恢复..."
    tar -xzf "$BACKUP_FILE" -C / 2>/dev/null
    echo -e "${GREEN}✅ 全部数据已恢复。${NC}"
    echo "然后: 1. docker compose up -d  2. 面板重建实例  3. 复制 mods"
    ;;
esac
