#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import subprocess
import re
import json
import time

BDS_ROOT = "/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/root/minecraft_bds"
PROPS_FILE = os.path.join(BDS_ROOT, "server.properties")
PERMS_FILE = os.path.join(BDS_ROOT, "permissions.json")
PLAYERS_DB = os.path.expanduser("~/.mc_players.json")

def read_props():
    props = {}
    if os.path.exists(PROPS_FILE):
        with open(PROPS_FILE, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    props[k.strip()] = v.strip()
    return props

def write_prop(key, value):
    if not os.path.exists(PROPS_FILE):
        return False
    with open(PROPS_FILE, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    found = False
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            k, _ = stripped.split("=", 1)
            if k.strip() == key:
                new_lines.append(f"{key}={value}\n")
                found = True
                continue
        new_lines.append(line)
    if not found:
        new_lines.append(f"{key}={value}\n")
    
    with open(PROPS_FILE, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    return True

def get_active_world_dir():
    props = read_props()
    level_name = props.get("level-name", "Bedrock level")
    return os.path.join(BDS_ROOT, "worlds", level_name)

def get_hardcore_status():
    world_dir = get_active_world_dir()
    level_dat = os.path.join(world_dir, "level.dat")
    if not os.path.exists(level_dat):
        return None
    try:
        with open(level_dat, "rb") as f:
            data = f.read()
        idx = data.find(b"IsHardcore")
        if idx != -1:
            val_pos = idx + len(b"IsHardcore")
            return data[val_pos] == 1
    except Exception:
        pass
    return False

def set_hardcore(enable):
    world_dir = get_active_world_dir()
    updated = False
    for fname in ["level.dat", "level.dat_old"]:
        path = os.path.join(world_dir, fname)
        if os.path.exists(path):
            try:
                with open(path, "rb") as f:
                    data = bytearray(f.read())
                idx = data.find(b"IsHardcore")
                if idx != -1:
                    val_pos = idx + len(b"IsHardcore")
                    data[val_pos] = 1 if enable else 0
                    if enable:
                        d_idx = data.find(b"Difficulty")
                        if d_idx != -1:
                            d_pos = d_idx + len(b"Difficulty")
                            data[d_pos:d_pos+4] = (3).to_bytes(4, "little")
                    with open(path, "wb") as f:
                        f.write(data)
                    updated = True
            except Exception as e:
                print(f"Error updating {fname}: {e}", file=sys.stderr)
    if enable:
        write_prop("difficulty", "hard")
        write_prop("force-gamemode", "true")
        write_prop("gamemode", "survival")
    return updated

def load_players_db():
    if os.path.exists(PLAYERS_DB):
        try:
            with open(PLAYERS_DB, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_players_db(db):
    try:
        with open(PLAYERS_DB, "w", encoding="utf-8") as f:
            json.dump(db, f, ensure_ascii=False, indent=2)
    except Exception:
        pass

def get_ops_xuids():
    xuids = set()
    if os.path.exists(PERMS_FILE):
        try:
            with open(PERMS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                for entry in data:
                    if entry.get("permission") == "operator":
                        x = str(entry.get("xuid", ""))
                        if x:
                            xuids.add(x)
        except Exception:
            pass
    return xuids

def set_offline_op(xuid, grant=True):
    if not os.path.exists(PERMS_FILE):
        data = []
    else:
        try:
            with open(PERMS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            data = []
    
    data = [e for e in data if str(e.get("xuid", "")) != str(xuid)]
    if grant:
        data.append({"permission": "operator", "xuid": str(xuid)})
    
    with open(PERMS_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=3)

def is_server_running():
    res = subprocess.run(["tmux", "has-session", "-t", "mc"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return res.returncode == 0

def sync_players():
    db = load_players_db()
    if "ScareSleet6962" not in db:
        db["ScareSleet6962"] = {"xuid": "2535452431165878", "last_seen": "2026-10-30 22:37"}

    if is_server_running():
        try:
            pane = subprocess.check_output(["tmux", "capture-pane", "-pt", "mc", "-S", "-1000"], text=True, errors="ignore")
            for m in re.finditer(r"Player (?:connected|Spawned):\s+([a-zA-Z0-9_ ]+?)(?:,\s+xuid:\s+(\d+)|$)", pane):
                name = m.group(1).strip()
                xuid = m.group(2) if m.group(2) else ""
                if name:
                    if name not in db:
                        db[name] = {"xuid": xuid, "last_seen": "Recently"}
                    elif xuid and not db[name].get("xuid"):
                        db[name]["xuid"] = xuid
        except Exception:
            pass

    save_players_db(db)
    return db

def get_player_status():
    db = sync_players()
    ops = get_ops_xuids()
    online = []

    if is_server_running():
        try:
            subprocess.run(["tmux", "send-keys", "-t", "mc", "list", "Enter"], check=True)
            time.sleep(0.4)
            pane = subprocess.check_output(["tmux", "capture-pane", "-pt", "mc", "-S", "-30"], text=True, errors="ignore")
            blocks = pane.split("players online:")
            if len(blocks) > 1:
                last_block = blocks[-1].strip().split("\n")
                if last_block:
                    first_line = last_block[0].strip()
                    if first_line and not first_line.startswith("[") and not first_line.startswith("list"):
                        for name in first_line.split(","):
                            n = name.strip()
                            if n:
                                online.append(n)
        except Exception:
            pass

    result = []
    for name in online:
        xuid = db.get(name, {}).get("xuid", "")
        is_op = (xuid in ops)
        result.append({
            "name": name,
            "online": True,
            "xuid": xuid,
            "is_op": is_op
        })

    for name, info in db.items():
        if name not in online:
            xuid = info.get("xuid", "")
            is_op = (xuid in ops)
            result.append({
                "name": name,
                "online": False,
                "xuid": xuid,
                "is_op": is_op
            })
    return result

def print_status():
    props = read_props()
    hc = get_hardcore_status()
    running = is_server_running()
    
    print(f"RUNNING={'1' if running else '0'}")
    print(f"LEVEL_NAME={props.get('level-name', 'Bedrock level')}")
    print(f"LEVEL_SEED={props.get('level-seed', '')}")
    print(f"DIFFICULTY={props.get('difficulty', 'easy')}")
    print(f"GAMEMODE={props.get('gamemode', 'survival')}")
    print(f"ALLOW_CHEATS={props.get('allow-cheats', 'false')}")
    print(f"ONLINE_MODE={props.get('online-mode', 'false')}")
    print(f"HARDCORE={'1' if hc else '0' if hc is not None else '-1'}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print_status()
        sys.exit(0)
    
    cmd = sys.argv[1]
    if cmd == "status":
        print_status()
    elif cmd == "players":
        plist = get_player_status()
        for idx, p in enumerate(plist, 1):
            on_str = "ONLINE" if p["online"] else "OFFLINE"
            op_str = "OP" if p["is_op"] else "USER"
            print(f"{idx}|{p['name']}|{on_str}|{op_str}|{p['xuid']}")
    elif cmd == "set_hardcore":
        val = (sys.argv[2] == "1") if len(sys.argv) > 2 else True
        res = set_hardcore(val)
        print("SUCCESS" if res else "FAIL")
    elif cmd == "set_prop":
        if len(sys.argv) >= 4:
            k = sys.argv[2]
            v = sys.argv[3]
            write_prop(k, v)
            print("OK")
    elif cmd == "set_op":
        name = sys.argv[2]
        grant = (sys.argv[3] == "1") if len(sys.argv) > 3 else True
        plist = get_player_status()
        target = next((p for p in plist if p["name"] == name), None)
        
        if is_server_running():
            op_cmd = "op" if grant else "deop"
            subprocess.run(["tmux", "send-keys", "-t", "mc", f"{op_cmd} {name}", "Enter"])
            time.sleep(0.3)
        
        xuid = target["xuid"] if target else ""
        if not xuid:
            db = load_players_db()
            xuid = db.get(name, {}).get("xuid", "")
        
        if xuid:
            set_offline_op(xuid, grant)
            if is_server_running():
                subprocess.run(["tmux", "send-keys", "-t", "mc", "permission reload", "Enter"])
        print("OK")
