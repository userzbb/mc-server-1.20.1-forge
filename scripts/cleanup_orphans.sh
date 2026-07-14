#!/bin/bash
# 清理孤儿实例数据目录（InstanceData 里没有对应 InstanceConfig 的）

source "$(dirname "$0")/config.sh"

echo "扫描 InstanceData 目录..."
orphan_count=0

for d in "$MCSM_DIR/InstanceData"/*/; do
  uuid=$(basename "$d")
  [ -z "$uuid" ] && continue
  [ "$uuid" = "global0001" ] && continue

  if [ ! -f "$MCSM_DIR/InstanceConfig/$uuid.json" ]; then
    echo "  ❌ 孤儿: $uuid"
    orphan_count=$((orphan_count + 1))
  fi
done

if [ $orphan_count -eq 0 ]; then
  echo "✅ 没有孤儿目录"
  exit 0
fi

read -p "清理这 $orphan_count 个孤儿目录？(y/N) " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
  for d in "$MCSM_DIR/InstanceData"/*/; do
    uuid=$(basename "$d")
    [ -z "$uuid" ] && continue
    [ "$uuid" = "global0001" ] && continue

    if [ ! -f "$MCSM_DIR/InstanceConfig/$uuid.json" ]; then
      rm -rf "$d"
      echo "  🗑️  已删除: $uuid"
    fi
  done
  echo "✅ 清理完成"
fi
