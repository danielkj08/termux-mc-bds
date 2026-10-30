#!/data/data/com.termux/files/usr/bin/bash

BACKUP_DIR="/data/data/com.termux/files/home/bds_backups"

echo "==========================================="
echo "   마인크래프트 BDS 월드 백업 복구 (Restore)"
echo "==========================================="

if [ ! -d "$BACKUP_DIR" ]; then
    echo "[!] 백업 폴더가 존재하지 않습니다."
    exit 1
fi

# 백업 파일 목록 가져오기
FILES=("$BACKUP_DIR"/*.tar.gz)
if [ ! -e "${FILES[0]}" ]; then
    echo "[!] 저장된 백업 파일이 없습니다."
    exit 1
fi

echo ""
echo "복구 가능한 백업 목록:"
echo "-------------------------------------------"
INDEX=1
for file in "${FILES[@]}"; do
    FILENAME=$(basename "$file")
    FILESIZE=$(ls -lh "$file" | awk '{print $5}')
    FILEDATE=$(ls -lh "$file" | awk '{print $6, $7, $8}')
    echo " [$INDEX] $FILENAME ($FILESIZE, $FILEDATE)"
    INDEX=$((INDEX + 1))
done
echo "-------------------------------------------"

read -p "복구할 백업 번호를 입력하세요 (취소는 q): " choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    echo "[-] 복구가 취소되었습니다."
    exit 0
fi

# 숫자 검증
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$INDEX" ]; then
    echo "[!] 올바른 번호가 아닙니다."
    exit 1
fi

SELECTED_FILE="${FILES[$((choice - 1))]}"
SELECTED_NAME=$(basename "$SELECTED_FILE")

echo ""
echo "선택한 백업: $SELECTED_NAME"
echo "⚠️  경고: 현재 진행 중인 월드가 위 백업 시점으로 덮어씌워집니다!"
read -p "정말 복구하시겠습니까? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "[-] 복구가 취소되었습니다."
    exit 0
fi

# 1. 서버 실행 중이면 안전 종료
if tmux has-session -t mc 2>/dev/null; then
    echo "[*] 실행 중인 서버를 먼저 안전하게 종료합니다..."
    tmux send-keys -t mc "stop" C-m
    while tmux has-session -t mc 2>/dev/null; do
        sleep 1
    done
    echo "[+] 서버가 종료되었습니다."
fi

# 2. 혹시 모를 안전을 위해 현재 상태를 임시 백업
SAFETY_DATE=$(date +"%Y%m%d_%H%M%S")
echo "[*] 만약을 대비해 현재 상태를 safety_backup으로 보관합니다..."
proot-distro login ubuntu -- bash -c "
if [ -d /root/minecraft_bds/worlds ]; then
    tar -czf /root/safety_before_restore_${SAFETY_DATE}.tar.gz -C /root/minecraft_bds worlds
    mv /root/safety_before_restore_${SAFETY_DATE}.tar.gz /data/data/com.termux/files/home/bds_backups/
fi
"

# 3. 선택한 백업 복원
echo "[*] 백업 복원을 진행 중입니다..."
cp "$SELECTED_FILE" /data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/root/restore_target.tar.gz

proot-distro login ubuntu -- bash -c "
rm -rf /root/minecraft_bds/worlds
tar -xzf /root/restore_target.tar.gz -C /root/minecraft_bds/
rm -f /root/restore_target.tar.gz
"

echo ""
echo "==========================================="
echo "🎉 백업 복구가 성공적으로 완료되었습니다!"
echo "   복구된 백업: $SELECTED_NAME"
echo ""
echo "   이제 ./start.sh 를 실행하시면"
echo "   복구된 월드로 서버가 구동됩니다."
echo "==========================================="
