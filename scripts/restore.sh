#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh                        # 交互模式（选备份→选实例→选模式）
#   ./restore.sh forge-1.20.1 instance  # 直接指定
#   ./restore.sh --list                 # 列出备份

source "$(dirname "$0")/config.sh"

CREATE_SCRIPT="$(dirname "$0")/create_instance.py"

# sudo 密码从 .secrets 读取
SECRETS_FILE="$PROJECT_DIR/.secrets"
if [ -f "$SECRETS_FILE" ]; then
  SUDO_PASS=$(grep "SUDO_PASS" "$SECRETS_FILE" 2>/dev/null | cut -d= -f2)
else
  SUDO_PASS=""
fi

# 带 sudo 的命令（自动输入密码）
run_sudo() {
  if [ -n "$SUDO_PASS" ]; then
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null
  else
    sudo "$@"
  fi
}

# 列出备份
if [ "$1" = "--list" ]; then
  echo "可用备份:"
  ls -1 "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
  exit 0
fi

# 按名称查找实例 UUID
get_uuid_by_name() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    n=$(python3 -c "import json; print(json.load(open('"'"'$f'"'"')).get('"'"'nickname'"'"','"'"''"'"'))" 2>/dev/null)
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

# 自动清理孤儿实例数据（每次运行时）
cleanup_orphans() {
  for d in "$MCSM_DIR/InstanceData"/*/; do
    local uuid=$(basename "$d")
    [ -z "$uuid" ] && continue
    [ "$uuid" = "global0001" ] && continue
    if [ ! -f "$MCSM_DIR/InstanceConfig/$uuid.json" ]; then
      rm -rf "$d"
      echo "🗑️  已清理孤儿: $uuid"
    fi
  done
}

# 运行清理
cleanup_orphans

# 恢复逻辑
do_restore() {
  local name="$1" mode="$2" uuid="$3" backup_file="$4"
  local tmpdir=$(mktemp -d)

  echo "========================================"
  echo "  恢复 [$name] - $(basename "$backup_file")"
  echo "  模式: $mode"
  echo "========================================"

  # 场景一：世界回档 - 只恢复世界存档
  if [ "$mode" = "world" ]; then
    echo "🔄 恢复世界存档..."
    tar -xzf "$backup_file" -C "$tmpdir" 2>/dev/null
    local world_dir=$(find "$tmpdir" -type d -name "world" -path "*/InstanceData/*" 2>/dev/null | head -1)
    if [ -n "$world_dir" ]; then
      run_sudo cp -r "$world_dir"/* "$MCSM_DIR/InstanceData/$uuid/world/" 2>/dev/null
      echo "✅ 世界存档已恢复"
    fi
    rm -rf "$tmpdir"
    return
  fi

  # 场景二/三：完整恢复
  echo "🔄 解压备份..."
  tar -xzf "$backup_file" -C "$tmpdir" 2>/dev/null

  # 使用 find 动态查找备份中的 InstanceData 目录
  local backup_instance_dir=$(find "$tmpdir" -type d -name "InstanceData" -path "*/mcsm/*" 2>/dev/null | head -1)

  if [ -n "$backup_instance_dir" ]; then
    local old_instance_dir=$(find "$backup_instance_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)

    if [ -n "$old_instance_dir" ]; then
      local old_uuid=$(basename "$old_instance_dir")
      echo "🔄 恢复实例数据 (旧UUID: $old_uuid → 新UUID: $uuid)..."

      run_sudo mkdir -p "$MCSM_DIR/InstanceData/$uuid" 2>/dev/null
      run_sudo cp -r "$old_instance_dir"/* "$MCSM_DIR/InstanceData/$uuid/" 2>/dev/null &&         echo "✅ 实例数据已恢复（mod、世界、配置）"

      local backup_config="$backup_instance_dir/../InstanceConfig/$old_uuid.json"
      if [ -f "$backup_config" ]; then
        run_sudo cp "$backup_config" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
        run_sudo sed -i "s/$old_uuid/$uuid/g" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
        echo "✅ 实例配置已更新"
      else
        python3 "$CREATE_SCRIPT" "$name" "$uuid" "$MCSM_DIR/InstanceConfig" 2>/dev/null &&           echo "✅ 配置已从模板创建"
      fi
    fi
  else
    echo "⚠️  备份中无实例数据"
  fi

  # 场景三：完整迁移
  if [ "$mode" = "--full" ]; then
    echo "🔄 恢复节点/凭据/DDNS..."
    local node_config=$(find "$tmpdir" -type d -name "RemoteServiceConfig" 2>/dev/null | head -1)
    [ -n "$node_config" ] && run_sudo cp -r "$node_config"/* "$PROJECT_DIR/mcsm/web/data/RemoteServiceConfig/" 2>/dev/null && echo "✅ 节点配置已恢复"
    local creds=$(find "$tmpdir" -name "credentials.md" 2>/dev/null | head -1)
    [ -n "$creds" ] && run_sudo cp "$creds" "$PROJECT_DIR/" 2>/dev/null && echo "✅ 凭据已恢复"
    local ddns=$(find "$tmpdir" -type d -name "ddns-go-data" 2>/dev/null | head -1)
    [ -n "$ddns" ] && run_sudo cp -r "$ddns"/* "$PROJECT_DIR/ddns-go-data/" 2>/dev/null && echo "✅ DDNS 已恢复"
  fi

  rm -rf "$tmpdir"
  echo "✅ 恢复完成，重启 daemon..."
  docker compose restart mcsm-daemon 2>/dev/null
}

# === 交互模式 ===
if [ $# -eq 0 ]; then
  select_backup
  backup_name=$(basename "$SELECTED_BACKUP" | sed 's/^backup-//;s/-[0-9]\{8\}.*\.tar\.gz$//')
  echo ""
  echo "已有实例:"
  instances=()
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    n=$(python3 -c "import json; print(json.load(open('"'"'$f'"'"')).get('"'"'nickname'"'"','"'"''"'"'))" 2>/dev/null)
    [ -n "$n" ] && [ "$n" != "__MCSM_GLOBAL_INSTANCE__" ] && instances+=("$n")
  done
  for i in "${!instances[@]}"; do
    echo "  $((i+1)). ${instances[$i]}"
  done
  echo "  $(( ${#instances[@]} + 1 )). 新建实例 (默认: $backup_name)"
  echo ""
  read -p "选择实例 (1-$(( ${#instances[@]} + 1 ))): " choice
  if [ "$choice" = "$(( ${#instances[@]} + 1 ))" ] || [ -z "$choice" ]; then
    read -p "新实例名称 ($backup_name): " NAME
    NAME="${NAME:-$backup_name}"
  else
    NAME="${instances[$((choice-1))]}"
  fi
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
  SELECTED_BACKUP=$(ls -t "$BACKUP_DIR/backup-${NAME}-"*.tar.gz 2>/dev/null | head -1)
  [ -z "$SELECTED_BACKUP" ] && { echo "未找到 [$NAME] 的备份"; select_backup; }
fi

UUID=$(get_uuid_by_name "$NAME")
if [ -z "$UUID" ]; then
  echo "创建实例 [$NAME]..."
  NEW_UUID=$(python3 -c "import uuid; print(uuid.uuid4().hex)")
  UUID=$(python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null || run_sudo python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null)
  [ -z "$UUID" ] && echo "❌ 创建失败" && exit 1
  echo "✅ 已创建 (UUID: $UUID)"
fi

do_restore "$NAME" "$MODE" "$UUID" "$SELECTED_BACKUP"
