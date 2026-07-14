#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh                        # 交互模式（选实例、备份、模式）
#   ./restore.sh forge-1.20.1 instance  # 直接指定
#   ./restore.sh --list                 # 列出备份

source "$(dirname "$0")/config.sh"

# sudo 密码从 .secrets 读取
SECRETS_FILE="$(dirname "$0")/../../.secrets"
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
  local tmpdir=$(mktemp -d)

  echo "========================================"
  echo "  恢复 [$name] - $(basename "$backup_file")"
  echo "  模式: $mode"
  echo "========================================"

  # 场景一：世界回档 - 只恢复世界存档
  if [ "$mode" = "world" ]; then
    echo "🔄 恢复世界存档..."
    tar -xzf "$backup_file" --wildcards "*/world/*" "*/server.properties" "*/eula.txt" -C "$tmpdir" 2>/dev/null
    # 用 sudo 复制到实例目录
    [ -d "$tmpdir/$MCSM_DIR/InstanceData/$old_uuid/world" ] && \
      sudo cp -r "$tmpdir/$MCSM_DIR/InstanceData/$old_uuid/world"/* "$MCSM_DIR/InstanceData/$uuid/world/" 2>/dev/null && \
      echo "✅ 世界存档已恢复"
    [ -f "$tmpdir/$MCSM_DIR/InstanceData/$old_uuid/server.properties" ] && \
      sudo cp "$tmpdir/$MCSM_DIR/InstanceData/$old_uuid/server.properties" "$MCSM_DIR/InstanceData/$uuid/" && \
      echo "✅ server.properties 已恢复"
    [ -f "$tmpdir/$MCSM_DIR/InstanceData/$old_uuid/eula.txt" ] && \
      sudo cp "$tmpdir/$MCSM_DIR/InstanceData/$old_uuid/eula.txt" "$MCSM_DIR/InstanceData/$uuid/" && \
      echo "✅ eula.txt 已恢复"
    rm -rf "$tmpdir"
    return
  fi

  # 场景二/三：完整恢复 - 解压到临时目录再移动
  echo "🔄 解压备份..."
  tar -xzf "$backup_file" -C "$tmpdir" 2>/dev/null

  # 恢复 InstanceData（mod、世界、配置等）
  backup_instance_dir=""
  if [ -d "$tmpdir/home/yuan/minecraft-server/$MCSM_DIR/InstanceData/$old_uuid" ]; then
    backup_instance_dir="$tmpdir/home/yuan/minecraft-server/$MCSM_DIR/InstanceData/$old_uuid"
  elif [ -d "$tmpdir/$MCSM_DIR/InstanceData/$old_uuid" ]; then
    backup_instance_dir="$tmpdir/$MCSM_DIR/InstanceData/$old_uuid"
  fi

  if [ -n "$backup_instance_dir" ]; then
    echo "🔄 恢复实例数据..."
    run_sudo mkdir -p "$MCSM_DIR/InstanceData/$uuid" 2>/dev/null
    run_sudo cp -r "$backup_instance_dir"/* "$MCSM_DIR/InstanceData/$uuid/" 2>/dev/null && \
      echo "✅ 实例数据已恢复（mod、世界、配置）"
  fi

  # 恢复 InstanceConfig（Docker 配置）
  backup_config_file=""
  if [ -f "$tmpdir/home/yuan/minecraft-server/$MCSM_DIR/InstanceConfig/$old_uuid.json" ]; then
    backup_config_file="$tmpdir/home/yuan/minecraft-server/$MCSM_DIR/InstanceConfig/$old_uuid.json"
  elif [ -f "$tmpdir/$MCSM_DIR/InstanceConfig/$old_uuid.json" ]; then
    backup_config_file="$tmpdir/$MCSM_DIR/InstanceConfig/$old_uuid.json"
  fi

  if [ -n "$backup_config_file" ]; then
    echo "🔄 恢复实例配置..."
    run_sudo cp "$backup_config_file" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null && \
      echo "✅ 实例配置已恢复"
  else
    # 备份中没有配置，从模板创建
    python3 "$CREATE_SCRIPT" "$name" "$uuid" "$MCSM_DIR/InstanceConfig" 2>/dev/null && \
      echo "✅ 配置已从模板创建"
  fi

  # 场景三：完整迁移 - 额外恢复节点配置、凭据、DDNS
  if [ "$mode" = "--full" ]; then
    echo "🔄 恢复节点/凭据/DDNS..."
    [ -d "$tmpdir/$MCSM_DIR/../web/data/RemoteServiceConfig" ] && \
      run_sudo cp -r "$tmpdir/$MCSM_DIR/../web/data/RemoteServiceConfig"/* "$PROJECT_DIR/mcsm/web/data/RemoteServiceConfig/" 2>/dev/null && \
      echo "✅ 节点配置已恢复"
    [ -f "$tmpdir/$PROJECT_DIR/credentials.md" ] && \
      run_sudo cp "$tmpdir/$PROJECT_DIR/credentials.md" "$PROJECT_DIR/" 2>/dev/null && \
      echo "✅ 凭据已恢复"
    [ -d "$tmpdir/$PROJECT_DIR/ddns-go-data" ] && \
      run_sudo cp -r "$tmpdir/$PROJECT_DIR/ddns-go-data"/* "$PROJECT_DIR/ddns-go-data/" 2>/dev/null && \
      echo "✅ DDNS 已恢复"
  fi

  # 清理临时目录
  rm -rf "$tmpdir"

  echo "✅ 恢复完成，重启 daemon..."
  docker compose restart mcsm-daemon 2>/dev/null
}

# 自动清理孤儿实例数据
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

# === 交互模式 ===
if [ $# -eq 0 ]; then
  # 1. 先选备份
  select_backup
  backup_name=$(basename "$SELECTED_BACKUP" | sed 's/^backup-//;s/-[0-9]\{8\}.*\.tar\.gz$//')
  echo ""
  # 2. 选择已有实例或新建
  echo "已有实例:"
  instances=()
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    n=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
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
  UUID=$(python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null || run_sudo python3 "$CREATE_SCRIPT" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null)
  [ -z "$UUID" ] && echo "❌ 创建失败" && exit 1
  echo "✅ 已创建 (UUID: $UUID)"
fi

do_restore "$NAME" "$MODE" "$UUID" "$SELECTED_BACKUP"
