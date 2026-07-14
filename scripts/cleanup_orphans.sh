#!/bin/bash
# 清理脚本
# 用法:
#   ./cleanup_orphans.sh        # 清理孤儿实例数据（没有对应配置的目录）
#   ./cleanup_orphans.sh --all  # 清理所有非必要实例（只保留主服务器实例）

source "$(dirname "$0")/config.sh"

# 保留的实例（不删除）
KEEP_INSTANCES=(
  "b6a0591e581b4172879211bdeba4f3cf"  # forge-1.20.1
  "71dedd089a9c4affaa3c811a8e722be8"  # tacz-craft
)

# 获取实例名称
get_instance_name() {
  python3 -c "import json; print(json.load(open('$MCSM_DIR/InstanceConfig/$1.json')).get('nickname',''))" 2>/dev/null
}

# 检查是否是保留实例
is_keep_instance() {
  for keep in "${KEEP_INSTANCES[@]}"; do
    [ "$keep" = "$1" ] && return 0
  done
  return 1
}

echo "扫描 InstanceData 目录..."
orphan_count=0
keep_count=0

for d in "$MCSM_DIR/InstanceData"/*/; do
  uuid=$(basename "$d")
  [ -z "$uuid" ] && continue
  [ "$uuid" = "global0001" ] && continue

  name=$(get_instance_name "$uuid")

  if [ ! -f "$MCSM_DIR/InstanceConfig/$uuid.json" ]; then
    echo "  ❌ 孤儿实例: $uuid ($name)"
    orphan_count=$((orphan_count + 1))
  elif is_keep_instance "$uuid"; then
    echo "  ✅ 保留实例: $uuid ($name)"
    keep_count=$((keep_count + 1))
  else
    echo "  ⚠️  多余实例: $uuid ($name)"
    orphan_count=$((orphan_count + 1))
  fi
done

if [ $orphan_count -eq 0 ]; then
  echo "✅ 没有需要清理的实例"
  exit 0
fi

read -p "清理 $orphan_count 个多余实例？(y/N) " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
  for d in "$MCSM_DIR/InstanceData"/*/; do
    uuid=$(basename "$d")
    [ -z "$uuid" ] && continue
    [ "$uuid" = "global0001" ] && continue

    # 跳过保留实例
    is_keep_instance "$uuid" && continue

    name=$(get_instance_name "$uuid")

    # 删除配置文件
    if [ -f "$MCSM_DIR/InstanceConfig/$uuid.json" ]; then
      rm -f "$MCSM_DIR/InstanceConfig/$uuid.json"
      echo "  🗑️  已删除配置: $uuid ($name)"
    fi

    # 删除数据目录
    if [ -d "$MCSM_DIR/InstanceData/$uuid" ]; then
      rm -rf "$MCSM_DIR/InstanceData/$uuid"
      echo "  🗑️  已删除数据: $uuid ($name)"
    fi
  done
  echo "✅ 清理完成"
fi
