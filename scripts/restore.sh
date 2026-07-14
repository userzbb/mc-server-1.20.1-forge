#!/bin/bash
# Minecraft 服务器恢复脚本
# restore.sh <实例名> <world|instance|--full>

source "$(dirname "$0")/config.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
CREATE_SCRIPT="$(dirname "$0")/create_instance.py"

[ "$1" = "--list" ] && { echo "可用备份:"; ls -1 "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | while read f; do echo "  $(basename "$f") ($(du -h "$f" | cut -f1))"; done; exit 0; }

get_uuid_by_name() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    local n=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    local u=$(basename "$f" .json)
    [ "$n" = "$1" ] && echo "$u" && return 0
  done
  return 1
}

do_restore() {
  local name="$1" mode="$2" uuid="$3"
  local backup_file=$(ls -t "$BACKUP_DIR/backup-${name}-"*.tar.gz 2>/dev/null | head -1)
  [ -z "$backup_file" ] && { echo "❌ 未找到 $name 的备份"; exit 1; }

  local old_uuid=$(tar -tzf "$backup_file" | grep "InstanceData/" | head -1 | cut -d/ -f9)

  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  恢复 [$name] - $(basename "$backup_file")${NC}"
  echo -e "${GREEN}  模式: $mode${NC}"
  echo -e "${GREEN}========================================${NC}"

  # 世界回档 — 只恢复存档
  if [ "$mode" = "world" ]; then
    tar -xzf "$backup_file" --wildcards "*/world/*" "*/server.properties" "*/eula.txt" -C / 2>/dev/null
    echo -e "${GREEN}✅ 世界已恢复。启动实例即可。${NC}"
    return
  fi

  # instance / --full：恢复完整实例数据
  tar -xzf "$backup_file" -C / 2>/dev/null

  # UUID 迁移
  if [ -n "$old_uuid" ] && [ "$old_uuid" != "$uuid" ]; then
    echo "ℹ️  UUID 已变更 ($old_uuid → $uuid)，迁移数据..."
    [ -d "$MCSM_DIR/InstanceData/$old_uuid" ] && mv "$MCSM_DIR/InstanceData/$old_uuid"/* "$MCSM_DIR/InstanceData/$uuid"/ 2>/dev/null && rm -rf "$MCSM_DIR/InstanceData/$old_uuid"
  fi

  # 实例配置：从备份恢复或从模板补全
  if tar -tzf "$backup_file" 2>/dev/null | grep -q "InstanceConfig/"; then
    [ -f "$MCSM_DIR/InstanceConfig/$old_uuid.json" ] && mv "$MCSM_DIR/InstanceConfig/$old_uuid.json" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
    echo "✅ 实例配置已从备份恢复"
  else
    python3 "$CREATE_SCRIPT" "$name" "$uuid" "$MCSM_DIR/InstanceConfig" 2>/dev/null
    echo "✅ Docker 配置已从模板创建"
  fi

  # --full 额外恢复：节点配置 + 凭据 + DDNS
  if [ "$mode" = "--full" ]; then
    tar -xzf "$backup_file" --wildcards "*RemoteServiceConfig*" "*credentials.md*" "*ddns-go-data*" -C / 2>/dev/null
    echo "✅ 节点/凭据/DDNS 已恢复"
  fi

  echo -e "${GREEN}✅ 完成。重启 daemon 后启动实例。${NC}"
  docker compose restart mcsm-daemon 2>/dev/null
}

# === 主流程 ===
NAME="$1"; MODE="$2"

if [ -z "$NAME" ]; then
  echo "用法: $0 <实例名> <world|instance|--full>"
  exit 1
fi

UUID=$(get_uuid_by_name "$NAME")
if [ -z "$UUID" ]; then
  echo "实例 [$NAME] 不存在，自动创建..."
  NEW_UUID=$(python3 -c "import uuid; print(uuid.uuid4().hex)")
  UUID=$(python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null || echo "1970" | sudo -S python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null)
  [ -z "$UUID" ] && echo "❌ 创建失败" && exit 1
  echo "✅ 已创建 (UUID: $UUID)"
fi

[ -z "$MODE" ] && { echo "请指定模式: world / instance / --full"; exit 1; }

read -p "继续? (y/N) " confirm; [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "已取消" && exit 0
do_restore "$NAME" "$MODE" "$UUID"
