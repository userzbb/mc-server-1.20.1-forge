#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh                        # 交互模式（选实例、备份、模式）
#   ./restore.sh forge-1.20.1 instance  # 直接指定
#   ./restore.sh --list                 # 列出备份

source "$(dirname "$0")/config.sh"

CREATE_SCRIPT="$(dirname "$0")/create_instance.py"

# 列出备份
if [ "$1" = "--list" ]; then
  echo "可用备份:"
  ls -1 "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
  exit 0
fi

# 按名称查找实例 UUID
get_uuid_by_name() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    n=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    u=$(basename "$f" .json)
    [ "$n" = "$1" ] && echo "$u" && return 0
  done
  return 1
}

# 选择备份文件
select_backup() {
  local backups=()
  for f in "$BACKUP_DIR"/backup-*.tar.gz; do
    [ -f "$f" ] && backups+=("$f")
  done
  if [ ${#backups[@]} -eq 0 ]; then
    echo "❌ 没有任何备份文件"
    exit 1
  fi
  if [ ${#backups[@]} -eq 1 ]; then
    SELECTED_BACKUP="${backups[0]}"
    return
  fi
  echo "可选备份:"
  for i in "${!backups[@]}"; do
    echo "  $((i+1)). $(basename "${backups[$i]}")"
  done
  read -p "选择备份 (1-${#backups[@]}): " c
  SELECTED_BACKUP="${backups[$((c-1))]}"
}

# 恢复逻辑
do_restore() {
  local name="$1" mode="$2" uuid="$3" backup_file="$4"
  local old_uuid=$(tar -tzf "$backup_file" | grep "InstanceData/" | head -1 | cut -d/ -f9)

  echo "========================================"
  echo "  恢复 [$name] - $(basename "$backup_file")"
  echo "  模式: $mode"
  echo "========================================"

  if [ "$mode" = "world" ]; then
    tar -xzf "$backup_file" --wildcards "*/world/*" "*/server.properties" "*/eula.txt" -C / 2>/dev/null
    echo "✅ 世界已恢复"
    return
  fi

  # instance / --full
  tar -xzf "$backup_file" -C / 2>/dev/null

  # UUID 迁移
  if [ -n "$old_uuid" ] && [ "$old_uuid" != "$uuid" ]; then
    echo "ℹ️  UUID 变更 ($old_uuid → $uuid)"
    [ -d "$MCSM_DIR/InstanceData/$old_uuid" ] && mv "$MCSM_DIR/InstanceData/$old_uuid"/* "$MCSM_DIR/InstanceData/$uuid"/ 2>/dev/null && rm -rf "$MCSM_DIR/InstanceData/$old_uuid"
  fi

  # 实例配置
  if tar -tzf "$backup_file" 2>/dev/null | grep -q "InstanceConfig/"; then
    [ -f "$MCSM_DIR/InstanceConfig/$old_uuid.json" ] && mv "$MCSM_DIR/InstanceConfig/$old_uuid.json" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
    echo "✅ 配置已从备份恢复"
  else
    python3 "$CREATE_SCRIPT" "$name" "$uuid" "$MCSM_DIR/InstanceConfig" 2>/dev/null
    echo "✅ 配置已从模板创建"
  fi

  # --full 额外
  if [ "$mode" = "--full" ]; then
    tar -xzf "$backup_file" --wildcards "*RemoteServiceConfig*" "*credentials.md*" "*ddns-go-data*" -C / 2>/dev/null
    echo "✅ 节点/凭据/DDNS 已恢复"
  fi

  echo "✅ 完成"
  docker compose restart mcsm-daemon 2>/dev/null
}

# === 交互模式 ===
if [ $# -eq 0 ]; then
  # 1. 先选备份
  select_backup
  backup_name=$(basename "$SELECTED_BACKUP" | sed 's/^backup-//;s/-[0-9]\{8\}.*\.tar\.gz$//')
  echo ""
  # 2. 显示已有实例，或新建
  echo "已有实例（可直接恢复）:"
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    n=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    [ -n "$n" ] && [ "$n" != "__MCSM_GLOBAL_INSTANCE__" ] && echo "  - $n"
  done
  echo ""
  read -p "恢复到实例 ($backup_name): " NAME
  NAME="${NAME:-$backup_name}"
  # 3. 选模式
  echo ""
  echo "恢复模式:"
  echo "  1. world     — 世界回档"
  echo "  2. instance  — 恢复全部数据"
  echo "  3. --full    — 完整迁移"
  read -p "选择 (1-3): " m
  case "$m" in
    1) MODE="world" ;;
    2) MODE="instance" ;;
    3) MODE="--full" ;;
    *) echo "无效"; exit 1 ;;
  esac

# 直接指定参数
else
  NAME="$1"; MODE="$2"
  [ -z "$MODE" ] && { echo "请指定: world / instance / --full"; exit 1; }

  # 找备份
  SELECTED_BACKUP=$(ls -t "$BACKUP_DIR/backup-${NAME}-"*.tar.gz 2>/dev/null | head -1)
  if [ -z "$SELECTED_BACKUP" ]; then
    echo "未找到 [$NAME] 的备份，可选："
    select_backup
  fi
fi

# 查找或创建实例
UUID=$(get_uuid_by_name "$NAME")
if [ -z "$UUID" ]; then
  echo "创建实例 [$NAME]..."
  NEW_UUID=$(python3 -c "import uuid; print(uuid.uuid4().hex)")
  UUID=$(python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null || echo "1970" | sudo -S python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null)
  [ -z "$UUID" ] && echo "❌ 创建失败" && exit 1
  echo "✅ 已创建 (UUID: $UUID)"
fi

do_restore "$NAME" "$MODE" "$UUID" "$SELECTED_BACKUP"
