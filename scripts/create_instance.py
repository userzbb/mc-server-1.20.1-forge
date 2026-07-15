#!/usr/bin/env python3
"""创建 MCSManager 实例配置文件"""
import json, os, sys, subprocess

nickname = sys.argv[1]
uuid = sys.argv[2]
config_dir = sys.argv[3]
cfg_path = f"{config_dir}/{uuid}.json"

data_dir = config_dir.replace("/InstanceConfig", "/InstanceData")
os.makedirs(f"{data_dir}/{uuid}", exist_ok=True)

cfg = {
    "nickname": nickname,
    "startCommand": "", "stopCommand": "^c", "cwd": f"data/InstanceData/{uuid}",
    "ie": "utf-8", "oe": "utf-8",
    "createDatetime": 0, "lastDatetime": 0,
    "processType": "docker", "type": "universal",
    "docker": {
        "image": "itzg/minecraft-server:java17",
        "containerName": f"mc-{nickname}",
        "ports": ["25565:25565/tcp", "25575:25575/tcp", "24454:24454/udp"],
        "extraVolumes": [],
        "env": ["EULA=TRUE", "TYPE=FORGE", "VERSION=1.20.1",
                "FORGE_VERSION=47.4.21", "ONLINE_MODE=false",
                "MEMORY=4G", "MAX_PLAYERS=20", "TZ=Asia/Shanghai"],
        "workingDir": "/data", "networkMode": "bridge"
    }
}

data = json.dumps(cfg, indent=2, ensure_ascii=False)
# 写入临时文件，用 sudo mv（从 .secrets 读取密码）
import tempfile
tmp = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json')
tmp.write(data)
tmp.close()

# 读取 sudo 密码
secrets_path = os.path.join(os.path.dirname(__file__), '..', '.secrets')
sudo_pass = ''
if os.path.exists(secrets_path):
    with open(secrets_path) as sf:
        for line in sf:
            if line.startswith('SUDO_PASS'):
                sudo_pass = line.split('=', 1)[1].strip()
                break

# 执行 mv
if sudo_pass:
    r = subprocess.run(['sudo', '-S', 'mv', tmp.name, cfg_path], input=sudo_pass.encode(), capture_output=True, text=True)
    if r.returncode != 0:
        # fallback: try writing directly
        import shutil
        shutil.copy(tmp.name, cfg_path)
    subprocess.run(['sudo', '-S', 'chmod', '644', cfg_path], input=sudo_pass.encode(), capture_output=True, text=True)
else:
    subprocess.run(['sudo', 'mv', tmp.name, cfg_path], check=True)
    subprocess.run(['sudo', 'chmod', '644', cfg_path], check=True)
print(uuid)
