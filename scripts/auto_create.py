#!/usr/bin/env python3
"""自动创建 MCSManager 实例配置文件"""
import json, os, sys, uuid, subprocess

nickname = sys.argv[1]
config_dir = sys.argv[2]

instance_uuid = uuid.uuid4().hex
cfg = {
    "nickname": nickname,
    "startCommand": "", "stopCommand": "^c", "cwd": "",
    "ie": "utf-8", "oe": "utf-8",
    "createDatetime": 0, "lastDatetime": 0,
    "processType": "general", "type": "universal",
    "tag": [], "endTime": 0, "fileCode": "utf-8",
    "docker": {}
}

os.makedirs(config_dir, exist_ok=True)
data = json.dumps(cfg, indent=2)
cfg_path = f"{config_dir}/{instance_uuid}.json"

try:
    with open(cfg_path, 'w') as f:
        f.write(data)
except PermissionError:
    r = subprocess.run(['sudo', 'tee', cfg_path], input=data, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"ERROR: Permission denied", file=sys.stderr)
        sys.exit(1)

print(instance_uuid)
