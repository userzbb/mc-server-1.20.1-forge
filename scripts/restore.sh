#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh                        # 交互模式（选备份→选实例→选模式）
#   ./restore.sh forge-1.20.1 instance  # 直接指定

PROJECT_DIR="/home/yuan/minecraft-server"
MCSM_DIR="$PROJECT_DIR/mcsm/daemon/data"
BACKUP_DIR="$PROJECT_DIR/backups"
SECRETS_FILE="$PROJECT_DIR/.secrets"

SUDO_PASS=""
[ -f "$SECRETS_FILE" ] && SUDO_PASS=$(grep "SUDO_PASS" "$SECRETS_FILE" 2>/dev/null | cut -d= -f2)

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

# 查找实例 UUID
get_uuid_by_name() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    n=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    [ "$n" = "$1" ] && basename "$f" .json && return 0
  done
  return 1
}

# 选择备份
select_backup() {
  local backups=()
  for f in "$BACKUP_DIR"/backup-*.tar.gz; do [ -f "$f" ] && backups+=("$f"); done
  [ ${#backups[@]} -eq 0 ] && echo "❌ 没有备份" && exit 1
  if [ ${#backups[@]} -eq 1 ]; then SELECTED_BACKUP="${backups[0]}"; return; fi
  echo "可选备份:"
  for i in "${!backups[@]}"; do echo "  $((i+1)). $(basename "${backups[$i]}")"; done
  read -p "选择备份 (1-${#backups[@]}): " c
  SELECTED_BACKUP="${backups[$((c-1))]}"
}

# 清理孤儿
cleanup_orphans() {
  for d in "$MCSM_DIR/InstanceData"/*/; do
    local uuid=$(basename "$d")
    [ -z "$uuid" ] || [ "$uuid" = "global0001" ] && continue
    [ ! -f "$MCSM_DIR/InstanceConfig/$uuid.json" ] && rm -rf "$d"
  done
}
cleanup_orphans

# 恢复逻辑
do_restore() {
  local name="$1" mode="$2" uuid="$3" backup_file="$4"
  local tmpdir=$(mktemp -d)

  echo "========================================"
  echo "  恢复 [$name] - $(basename "$backup_file")"
  echo "  模式: $mode"
  echo "========================================"

  # 解压备份
  echo "🔄 解压备份..."
  tar -xzf "$backup_file" -C "$tmpdir" 2>/dev/null

  # 找到备份中的 InstanceData 目录（兼容新旧格式）
  local old_uuid=""
  local old_instance_dir=""

  # 新格式: tmpdir/InstanceData/<UUID>/
  if [ -d "$tmpdir/InstanceData" ]; then
    old_uuid=$(ls "$tmpdir/InstanceData" 2>/dev/null | head -1)
    old_instance_dir="$tmpdir/InstanceData/$old_uuid"
  # 旧格式: tmpdir/home/.../InstanceData/<UUID>/
  else
    old_instance_dir=$(find "$tmpdir" -type d -name "InstanceData" -path "*/mcsm/*" 2>/dev/null | head -1)
    if [ -n "$old_instance_dir" ]; then
      old_uuid=$(ls "$old_instance_dir" 2>/dev/null | head -1)
      old_instance_dir="$old_instance_dir/$old_uuid"
    fi
  fi

  if [ -z "$old_uuid" ]; then
    echo "❌ 备份中无实例数据"
    rm -rf "$tmpdir"
    return 1
  fi

  # 场景一：world 回档
  if [ "$mode" = "world" ]; then
    echo "🔄 恢复世界存档..."
    if [ -d "$old_instance_dir/world" ]; then
      run_sudo cp -r "$old_instance_dir/world"/* "$MCSM_DIR/InstanceData/$uuid/world/" 2>/dev/null
      echo "✅ 世界存档已恢复"
    fi
    rm -rf "$tmpdir"
    return 0
  fi

  # 场景二/三：完整恢复
  echo "🔄 恢复实例数据 (旧UUID: $old_uuid → 新UUID: $uuid)..."

  # 复制 InstanceData
  run_sudo mkdir -p "$MCSM_DIR/InstanceData/$uuid" 2>/dev/null
  run_sudo cp -r "$old_instance_dir"/* "$MCSM_DIR/InstanceData/$uuid/" 2>/dev/null
  # 修复文件权限（容器内 uid=1000）
  run_sudo chown -R 1000:1000 "$MCSM_DIR/InstanceData/$uuid" 2>/dev/null
  echo "✅ 实例数据已恢复（mod、世界、配置）"

  # 检测损坏文件（0 字节），从备份重新复制
  local bad_count=$(find "$MCSM_DIR/InstanceData/$uuid" -name "*.jar" -size 0 2>/dev/null | wc -l)
  if [ "$bad_count" -gt 0 ]; then
    echo "⚠️  发现 $bad_count 个损坏文件，正在重新复制..."
    find "$MCSM_DIR/InstanceData/$uuid" -name "*.jar" -size 0 -delete 2>/dev/null
    run_sudo cp -r "$old_instance_dir"/* "$MCSM_DIR/InstanceData/$uuid/" 2>/dev/null
    local bad_after=$(find "$MCSM_DIR/InstanceData/$uuid" -name "*.jar" -size 0 2>/dev/null | wc -l)
    [ "$bad_after" -eq 0 ] && echo "✅ 已修复" || echo "⚠️  仍有 $bad_after 个损坏文件，请手动检查"
  fi

  # 复制 InstanceConfig 并更新 UUID
  local old_config=""
  if [ -f "$tmpdir/InstanceConfig/$old_uuid.json" ]; then
    old_config="$tmpdir/InstanceConfig/$old_uuid.json"  # 新格式
  else
    old_config=$(find "$tmpdir" -name "$old_uuid.json" -path "*/InstanceConfig/*" 2>/dev/null | head -1)  # 旧格式
  fi

  if [ -n "$old_config" ]; then
    run_sudo cp "$old_config" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
    run_sudo sed -i "s/$old_uuid/$uuid/g" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
    echo "✅ 实例配置已更新"
  fi

  # 始终修正 cwd 和 changeWorkdir（不管配置来源）
  python3 -c "
import json
uuid = '$uuid'
path = '$MCSM_DIR/InstanceConfig/$uuid.json'
with open(path) as f:
    c = json.load(f)
need_fix = (c['cwd'] != f'data/InstanceData/{uuid}') or c.get('docker', {}).get('changeWorkdir')
if need_fix:
    c['cwd'] = f'data/InstanceData/{uuid}'
    c['docker']['changeWorkdir'] = False
    with open('/tmp/mcsm_cwd_fix.json', 'w') as fh:
        json.dump(c, fh, indent=2, ensure_ascii=False)
    print('fixed')
" 2>/dev/null
  if [ -f /tmp/mcsm_cwd_fix.json ]; then
    run_sudo mv /tmp/mcsm_cwd_fix.json "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
    echo "✅ cwd 已修正 (data/InstanceData/$uuid), changeWorkdir=False"
  fi

  # 场景三：完整迁移
  if [ "$mode" = "--full" ]; then
    echo "🔄 恢复节点/凭据/DDNS..."
    # 兼容新旧格式
    local node_config=$(find "$tmpdir" -type d -name "RemoteServiceConfig" 2>/dev/null | head -1)
    [ -n "$node_config" ] && run_sudo cp -r "$node_config"/* "$PROJECT_DIR/mcsm/web/data/RemoteServiceConfig/" 2>/dev/null && echo "✅ 节点配置"
    local creds=$(find "$tmpdir" -name "credentials.md" 2>/dev/null | head -1)
    [ -n "$creds" ] && run_sudo cp "$creds" "$PROJECT_DIR/" 2>/dev/null && echo "✅ 凭据"
    local ddns=$(find "$tmpdir" -type d -name "ddns-go-data" 2>/dev/null | head -1)
    [ -n "$ddns" ] && run_sudo cp -r "$ddns"/* "$PROJECT_DIR/ddns-go-data/" 2>/dev/null && echo "✅ DDNS"
  fi

  rm -rf "$tmpdir"
  echo "✅ 恢复完成"
  docker compose restart mcsm-daemon 2>/dev/null
}

# === 主流程 ===
if [ $# -eq 0 ]; then
  # 交互模式
  select_backup
  backup_name=$(basename "$SELECTED_BACKUP" | sed 's/^backup-//;s/-[0-9]\{8\}.*\.tar\.gz$//')
  echo ""
  echo "已有实例:"
  instances=()
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    n=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    [ -n "$n" ] && [ "$n" != "__MCSM_GLOBAL_INSTANCE__" ] && instances+=("$n")
  done
  for i in "${!instances[@]}"; do echo "  $((i+1)). ${instances[$i]}"; done
  echo "  $(( ${#instances[@]} + 1 )). 新建实例 (默认: $backup_name)"
  read -p "选择实例 (1-$(( ${#instances[@]} + 1 ))): " choice
  if [ "$choice" = "$(( ${#instances[@]} + 1 ))" ] || [ -z "$choice" ]; then
    NAME="$backup_name"
  else
    NAME="${instances[$((choice-1))]}"
  fi
  echo ""
  echo "恢复模式: 1=世界 2=全部 3=迁移"
  read -p "选择 (1-3): " m
  case "$m" in 1) MODE="world";; 2) MODE="instance";; 3) MODE="--full";; *) echo "无效"; exit 1;; esac
else
  # 直接指定参数
  NAME="$1"; MODE="$2"
  [ -z "$MODE" ] && { echo "请指定: world / instance / --full"; exit 1; }
  SELECTED_BACKUP=$(ls -t "$BACKUP_DIR/backup-${NAME}-"*.tar.gz 2>/dev/null | head -1)
  [ -z "$SELECTED_BACKUP" ] && select_backup
fi

UUID=$(get_uuid_by_name "$NAME")
if [ -z "$UUID" ]; then
  echo "实例 [$NAME] 不存在，正在自动创建..."
  NEW_UUID=$(python3 -c "import uuid; print(uuid.uuid4().hex)")
  UUID=$(python3 "$(dirname "$0")/create_instance.py" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null || run_sudo python3 "$(dirname "$0")/create_instance.py" "$NAME" "$NEW_UUID" "$MCSM_DIR/InstanceConfig" 2>/dev/null)
  [ -z "$UUID" ] && echo "❌ 创建失败" && exit 1
  echo "✅ 已创建 (UUID: $UUID)"
  docker compose restart mcsm-daemon 2>/dev/null
  echo "ℹ️  daemon 已重启，面板上应该能看到新实例了"
fi

do_restore "$NAME" "$MODE" "$UUID" "$SELECTED_BACKUP"
