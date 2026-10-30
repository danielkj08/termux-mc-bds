#!/data/data/com.termux/files/usr/bin/bash

# 마인크래프트 BDS 월드 초기화 및 생성 마법사 v2.2
BDS_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/root/minecraft_bds"
PROPS_FILE="$BDS_ROOT/server.properties"
BACKUP_DIR="/data/data/com.termux/files/home/bds_backups"
mkdir -p "$BACKUP_DIR"

clear
echo "====================================================="
echo "   🌍 마인크래프트 새 월드 생성 & 초기 설정 마법사"
echo "====================================================="
echo "  기존 월드는 자동으로 안전하게 백업 압축된 후,"
echo "  원하시는 설정(시드, 난이도, 하드코어 등)으로"
echo "  완전히 새로운 월드가 생성됩니다."
echo "====================================================="
echo ""
read -p "계속 진행하시겠습니까? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "[-] 취소되었습니다."
    exit 0
fi

echo ""
echo "---------------- [1. 월드 이름 및 시드] ----------------"
read -p "1) 월드 이름 [기본값: Bedrock level]: " in_name
[ -z "$in_name" ] && in_name="Bedrock level"

read -p "2) 월드 시드(Seed) 번호 [엔터: 무작위 야생]: " in_seed

echo ""
echo "---------------- [2. 게임 모드 및 난이도] ----------------"
echo "게임 모드를 선택하세요:"
echo " [1] 🌲 서바이벌 (Survival - 기본)"
echo " [2] 🏰 크리에이티브 (Creative)"
echo " [3] 🗺️  모험 (Adventure)"
read -p "선택 (기본 1): " mode_choice
case "$mode_choice" in
    2) in_mode="creative";;
    3) in_mode="adventure";;
    *) in_mode="survival";;
esac

echo ""
echo "💀 하드코어 모드 (목숨 1개, 사망 시 관전 모드 강제 전환):"
read -p "하드코어 모드로 플레이하시겠습니까? (y/N): " in_hc

if [ "$in_hc" = "y" ] || [ "$in_hc" = "Y" ]; then
    is_hardcore="1"
    in_diff="hard"
    in_mode="survival"
    echo " -> 💀 하드코어 모드 활성화 (난이도 '어려움' 및 서바이벌 자동 고정)"
else
    is_hardcore="0"
    echo ""
    echo "난이도를 선택하세요:"
    echo " [1] 평화로움 (Peaceful)"
    echo " [2] 쉬움 (Easy)"
    echo " [3] 보통 (Normal - 기본)"
    echo " [4] 어려움 (Hard)"
    read -p "선택 (기본 3): " diff_choice
    case "$diff_choice" in
        1) in_diff="peaceful";;
        2) in_diff="easy";;
        4) in_diff="hard";;
        *) in_diff="normal";;
    esac
fi

echo ""
echo "---------------- [3. 도전 과제 & 치트] ----------------"
echo "도전 과제(Xbox 업적)를 정상적으로 달성하려면 치트가 꺼져 있어야 합니다."
read -p "도전 과제를 활성화하시겠습니까? (Y/n, 기본 Y): " in_achieve
if [ "$in_achieve" = "n" ] || [ "$in_achieve" = "N" ]; then
    in_cheats="true"
    echo " -> ⚠️ 치트 허용 모드 (명령어 사용 가능 / 도전과제 비활성화)"
else
    in_cheats="false"
    echo " -> 🏆 도전과제 활성화 모드 (치트 비활성화)"
fi

echo ""
echo "====================================================="
HC_TEXT="비활성화 (OFF)"
if [ "$is_hardcore" = "1" ]; then
    HC_TEXT="💀 활성화 (ON)"
fi

ACHIEVE_TEXT="⚠️ 비활성화"
if [ "$in_cheats" = "false" ]; then
    ACHIEVE_TEXT="🏆 활성화"
fi

echo "설정 요약:"
echo " - 월드 이름 : $in_name"
echo " - 월드 시드 : ${in_seed:-무작위 (Random)}"
echo " - 게임 모드 : $in_mode"
echo " - 난이도    : $in_diff"
echo " - 하드코어  : $HC_TEXT"
echo " - 도전 과제 : $ACHIEVE_TEXT"
echo "====================================================="
read -p "이 설정으로 새 월드를 생성할까요? (Y/n): " final_confirm
if [ "$final_confirm" = "n" ] || [ "$final_confirm" = "N" ]; then
    echo "[-] 생성이 취소되었습니다."
    exit 0
fi

# 1. 서버 종료
if tmux has-session -t mc 2>/dev/null; then
    echo "[*] 실행 중인 서버를 안전하게 저장하고 종료합니다..."
    /data/data/com.termux/files/home/stop.sh
fi

# 2. 기존 월드 자동 안전 백업
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo "[*] 기존 월드를 안전 백업 중입니다..."
if [ -d "$BDS_ROOT/worlds" ]; then
    tar -czf "$BACKUP_DIR/world_backup_${TIMESTAMP}.tar.gz" -C "$BDS_ROOT" worlds 2>/dev/null
    echo "[+] 기존 월드가 백업되었습니다: ~/bds_backups/world_backup_${TIMESTAMP}.tar.gz"
fi

# 3. 기존 월드 폴더 제거
echo "[*] 이전 월드 데이터 정리 중..."
rm -rf "$BDS_ROOT/worlds"

# 4. server.properties 설정 업데이트
python ~/mc_helper.py set_prop "level-name" "$in_name"
python ~/mc_helper.py set_prop "level-seed" "$in_seed"
python ~/mc_helper.py set_prop "difficulty" "$in_diff"
python ~/mc_helper.py set_prop "gamemode" "$in_mode"
python ~/mc_helper.py set_prop "allow-cheats" "$in_cheats"

# 5. 하드코어 처리
if [ "$is_hardcore" = "1" ]; then
    echo "[*] 💀 하드코어 월드 생성을 위해 서버를 1차 가동하여 맵을 생성합니다..."
    /data/data/com.termux/files/home/start.sh >/dev/null 2>&1
    
    TARGET_DAT="$BDS_ROOT/worlds/$in_name/level.dat"
    echo -n "[*] 월드 데이터 생성 대기 중"
    COUNT=0
    while [ ! -f "$TARGET_DAT" ] && [ $COUNT -lt 30 ]; do
        echo -n "."
        sleep 1
        COUNT=$((COUNT + 1))
    done
    echo ""
    sleep 3
    
    echo "[*] 하드코어 NBT 플래그 주입을 위해 일시 정지..."
    /data/data/com.termux/files/home/stop.sh >/dev/null 2>&1
    
    echo "[*] 💀 IsHardcore=1 및 어려움 난이도 주입 중..."
    python ~/mc_helper.py set_hardcore 1
    
    echo "[*] 하드코어 서버 최종 시작 중..."
    /data/data/com.termux/files/home/start.sh
else
    echo "[*] 서버를 시작하여 새 월드를 생성합니다..."
    /data/data/com.termux/files/home/start.sh
fi

WORLD_TYPE_TEXT="일반 야생"
if [ "$is_hardcore" = "1" ]; then
    WORLD_TYPE_TEXT="💀 하드코어"
fi

echo ""
echo "====================================================="
echo "🎉 새로운 마인크래프트 월드가 성공적으로 생성되었습니다!"
echo "   - 월드: $in_name ($WORLD_TYPE_TEXT)"
echo "   - 난이도: $in_diff | 모드: $in_mode"
echo "====================================================="
