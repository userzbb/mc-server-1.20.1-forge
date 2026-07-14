#!/bin/bash
# Minecraft 服务器恢复脚本
# 用法:
#   ./restore.sh                           ← 交互菜单
#   ./restore.sh forge-1.20.1 world        ← 世界回档
#   ./restore.sh forge-1.20.1 instance     ← 重建实例
#   ./restore.sh forge-1.20.1 --full       ← 完整迁移

source "$(dirname "$0")/config.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# --list 参数
if [ "$1" = "--list" ]; then
  echo "可用备份:"
  for f in "$BACKUP_DIR"/backup-*.tar.gz; do
    [ -f "$f" ] && echo "  $(basename "$f") ($(du -h "$f" | cut -f1))"
  done
  [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ] && echo "  （无备份）"
  exit 0
fi

# 获取实例列表
get_instances() {
  for f in "$MCSM_DIR/InstanceConfig"/*.json; do
    nickname=$(python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null)
    uuid=$(basename "$f" .json)
    [ -n "$nickname" ] && [ "$nickname" != "__MCSM_GLOBAL_INSTANCE__" ] && echo "$uuid:$nickname"
  done
  existing=$(for f in "$MCSM_DIR/InstanceConfig"/*.json; do python3 -c "import json; print(json.load(open('$f')).get('nickname',''))" 2>/dev/null; done)
  for bf in "$BACKUP_DIR"/backup-*.tar.gz; do
    bname=$(basename "$bf" | sed 's/^backup-//;s/-[0-9]\{8\}.*\.tar\.gz$//')
    [ -n "$bname" ] && echo "$existing" | grep -qx "$bname" || echo ":$bname"
  done | sort -u
}

# 自动补全 Docker 配置（从模板）
apply_docker_config() {
  python3 -c "
import json, os, subprocess, sys
uuid = '$1'
cfg_path = '$2'
name = '$3'
with open(cfg_path) as f:
    c = json.load(f)
with open('/home/yuan/minecraft-server/instance-config.json') as t:
    tmpl = json.load(t)
c['processType'] = 'docker'
c['cwd'] = f'data/InstanceData/{uuid}'
c['docker'] = tmpl['docker']
c['docker']['containerName'] = f'mc-{name}'
try:
    with open(cfg_path, 'w') as f:
        json.dump(c, f, indent=2, ensure_ascii=False)
except PermissionError:
    data = json.dumps(c, indent=2, ensure_ascii=False)
    r = subprocess.run(['sudo', 'tee', cfg_path], input=data, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(1)
print('OK')
" 2>/dev/null
}

# 恢复逻辑（世界/实例/完整）
do_restore() {
  local name="$1" mode="$2" uuid="$3"
  local backup_file=$(ls -t "$BACKUP_DIR/backup-${name}-"*.tar.gz 2>/dev/null | head -1)

  [ -z "$backup_file" ] && echo "❌ 未找到 $name 的备份" && exit 1

  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  恢复 [$name] - $(basename "$backup_file")${NC}"
  echo -e "${GREEN}  模式: $mode${NC}"
  echo -e "${GREEN}========================================${NC}"

  local old_uuid=$(tar -tzf "$backup_file" | grep "InstanceData/" | head -1 | cut -d/ -f9)

  case "$mode" in
    world)
      echo "🔄 恢复世界存档..."
      tar -xzf "$backup_file" --wildcards "*/world/*" "*/server.properties" "*/eula.txt" -C / 2>/dev/null
      echo -e "${GREEN}✅ 世界已恢复。去面板启动实例即可。${NC}"
      ;;
    instance)
      echo "🔄 恢复实例全部数据..."
      tar -xzf "$backup_file" -C / 2>/dev/null
      if [ -n "$old_uuid" ] && [ "$old_uuid" != "$uuid" ]; then
        echo "ℹ️  UUID 已变更 ($old_uuid → $uuid)，迁移数据..."
        [ -d "$MCSM_DIR/InstanceData/$old_uuid" ] && mv "$MCSM_DIR/InstanceData/$old_uuid"/* "$MCSM_DIR/InstanceData/$uuid"/ 2>/dev/null && rm -rf "$MCSM_DIR/InstanceData/$old_uuid"
      fi
      if ! tar -tzf "$backup_file" 2>/dev/null | grep -q "InstanceConfig/"; then
        echo "ℹ️  备份中无实例配置，从模板补全 Docker 配置..."
        apply_docker_config "$uuid" "$MCSM_DIR/InstanceConfig/$uuid.json" "$name"
        echo "✅ Docker 配置已从模板应用"
      else
        [ -f "$MCSM_DIR/InstanceConfig/$old_uuid.json" ] && mv "$MCSM_DIR/InstanceConfig/$old_uuid.json" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
      fi
      echo -e "${GREEN}✅ 实例数据已恢复。重启 daemon 后启动实例。${NC}"
      docker compose restart mcsm-daemon 2>/dev/null
      ;;
    --full)
      echo "🔄 完整恢复..."
      tar -xzf "$backup_file" -C / 2>/dev/null
      if [ -n "$old_uuid" ] && [ "$old_uuid" != "$uuid" ]; then
        echo "ℹ️  UUID 已变更，迁移数据..."
        [ -d "$MCSM_DIR/InstanceData/$old_uuid" ] && mv "$MCSM_DIR/InstanceData/$old_uuid"/* "$MCSM_DIR/InstanceData/$uuid"/ 2>/dev/null && rm -rf "$MCSM_DIR/InstanceData/$old_uuid"
      fi
      if ! tar -tzf "$backup_file" 2>/dev/null | grep -q "InstanceConfig/"; then
        echo "ℹ️  备份中无实例配置，从模板补全 Docker 配置..."
        apply_docker_config "$uuid" "$MCSM_DIR/InstanceConfig/$uuid.json" "$name"
        echo "✅ Docker 配置已从模板应用"
      else
        [ -f "$MCSM_DIR/InstanceConfig/$old_uuid.json" ] && mv "$MCSM_DIR/InstanceConfig/$old_uuid.json" "$MCSM_DIR/InstanceConfig/$uuid.json" 2>/dev/null
      fi
      echo -e "${GREEN}✅ 全部数据已恢复。重启 daemon 后启动实例。${NC}"
      docker compose restart mcsm-daemon 2>/dev/null
      ;;
  esac
}

# 交互选择实例
select_instance() {
  local instances=()
  while IFS= read -r line; do instances+=("$line"); done < <(get_instances)
  echo "可用实例:"
  for i in "${!instances[@]}"; do
    local u=$(echo "${instances[$i]}" | cut -d: -f1)
    local n=$(echo "${instances[$i]}" | cut -d: -f2)
    local tag=""; [ -z "$u" ] && tag=" (已删除)"
    echo "  $((i+1)). $n$tag"
  done
  read -p "选择实例 (1-${#instances[@]}): " choice
  local s="${instances[$((choice-1))]}"
  UUID=$(echo "$s" | cut -d: -f1)
  NAME=$(echo "$s" | cut -d: -f2)
  if [ -z "$UUID" ]; then
    echo "❌ 实例 [$NAME] 已从面板删除。请先重建同名实例后重试。"
    exit 1
  fi
}

# 交互选择模式
select_mode() {
  echo ""
  echo "恢复模式:"
  echo "  1. world     — 世界回档"
  echo "  2. instance  — 重建实例后恢复全部数据"
  echo "  3. --full    — 完整迁移（含凭据、DDNS）"
  read -p "选择模式 (1-3): " m
  case "$m" in
    1) MODE="world" ;;
    2) MODE="instance" ;;
    3) MODE="--full" ;;
    *) echo "无效选择"; exit 1 ;;
  esac
}

# ---- 主流程 ----

if [ $# -eq 0 ]; then
  # 交互模式
  select_instance
  select_mode
  echo "⚠️  请先确认面板上已停止实例!"
  read -p "继续? (y/N) " confirm
  [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "已取消" && exit 0
  do_restore "$NAME" "$MODE" "$UUID"

elif [ $# -eq 1 ]; then
  # 只有实例名，交互选模式
  NAME="$1"
  for inst in $(get_instances); do
    n=$(echo "$inst" | cut -d: -f2)
    [ "$n" = "$NAME" ] && UUID=$(echo "$inst" | cut -d: -f1) && break
  done
  if [ -z "$UUID" ]; then
    echo "实例 [$NAME] 不存在。请选择:"
    echo "  1. 我去面板创建同名实例，再来恢复"
    echo "  2. 自动创建配置文件，直接恢复"
    read -p "选择 (1-2): " c
    case "$c" in
      2)
        UUID=$(python3 -c "import uuid; print(uuid.uuid4().hex)")
        read -p "新实例名称 ($NAME): " new_name
        NAME="${new_name:-$NAME}"
        sudo python3 -c "
import json
cfg_path = '$MCSM_DIR/InstanceConfig/$UUID.json'
with open(cfg_path, 'w') as f:
    json.dump({
        'nickname': '$NAME',
        'startCommand': '',
        'stopCommand': '^c',
        'cwd': '',
        'ie': 'utf-8',
        'oe': 'utf-8',
        'createDatetime': 0,
        'lastDatetime': 0,
        'processType': 'general',
        'type': 'universal',
        'docker': {}
    }, f, indent=2)
"
        mkdir -p "$MCSM_DIR/InstanceData/$UUID"
        echo "✅ 配置文件已创建"
        ;;
      *) exit 0 ;;
    esac
  fi
  select_mode
  read -p "继续? (y/N) " confirm; [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "已取消" && exit 0
  do_restore "$NAME" "$MODE" "$UUID"

elif [ $# -ge 2 ]; then
  NAME="$1"; MODE="$2"
  for inst in $(get_instances); do
    n=$(echo "$inst" | cut -d: -f2)
    [ "$n" = "$NAME" ] && UUID=$(echo "$inst" | cut -d: -f1) && break
  done
  read -p "新实例名称 ($NAME): " new_name
  NAME="${new_name:-$NAME}"
  if [ -z "$UUID" ]; then
    echo "实例 [$NAME] 不存在，自动创建配置..."
    UUID=$(python3 -c "import uuid; print(uuid.uuid4().hex)") && sudo python3 -c "import json; cfg_path='/$MCSM_DIR/InstanceConfig/$UUID.json'; json.dump({"nickname":"'$NAME'", "startCommand":"","stopCommand":"^c","cwd":"","ie":"utf-8","oe":"utf-8","createDatetime":0,"lastDatetime":0,"processType":"general","type":"universal","docker":{}}, open(cfg_path,"w"),indent=2)"
    mkdir -p "$MCSM_DIR/InstanceData/$UUID"
    echo "✅ 配置已创建"
  fi
  read -p "继续? (y/N) " confirm; [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "已取消" && exit 0
  do_restore "$NAME" "$MODE" "$UUID"
fi
