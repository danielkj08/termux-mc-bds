#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=========================================================="
echo "    🚀 마인크래프트 BDS 자동 복구 & 원클릭 설치기"
echo "=========================================================="
echo "스마트폰을 초기화했거나 새로 설치할 때 이 스크립트 하나로"
echo "우분투, Box64, 마인크래프트 BDS, 통합 관리자(mc)까지"
echo "전부 자동으로 설치됩니다."
echo "=========================================================="
echo ""

# 1. Termux 패키지 설치
echo ""
echo "[1/6] Termux 기본 필수 패키지 설치 중..."
pkg update -y
pkg install proot-distro tmux curl wget unzip tar openssh python -y

# 2. 우분투 컨테이너 설치
echo ""
echo "[2/6] 우분투 경량 컨테이너 설치 중 (약 40MB)..."
if ! proot-distro list | grep -q "ubuntu.*installed"; then
    proot-distro install ubuntu
else
    echo "[+] 우분투가 이미 설치되어 있습니다."
fi

# 3. 우분투 내부 필수 라이브러리 및 Box64 설치
echo ""
echo "[3/6] 우분투 내부 라이브러리 및 Box64 번역 엔진 설치 중..."
proot-distro login ubuntu -- bash -c '
apt update && apt install -y ca-certificates curl wget gnupg libcurl4 libssl3 libatomic1 unzip
wget -q https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list
wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg
apt update && apt install -y box64
'

# 4. 마인크래프트 BDS 최신버전 다운로드 및 세팅
echo ""
echo "[4/6] 마인크래프트 공식 BDS 서버 다운로드 및 설치 중..."
proot-distro login ubuntu -- bash -c '
mkdir -p /root/minecraft_bds
cd /root/minecraft_bds
if [ ! -f bedrock_server ]; then
    echo "Downloading Minecraft BDS..."
    curl -H "User-Agent: Mozilla/5.0" -L -o bedrock-server.zip "https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-1.26.61.1.zip"
    unzip -q -o bedrock-server.zip
    rm -f bedrock-server.zip
    chmod +x bedrock_server
    # 기본 설정 튜닝 (비정품 허용, 화이트리스트 끄기, 서버이름 변경)
    sed -i "s/allow-list=true/allow-list=false/g" server.properties
    sed -i "s/online-mode=true/online-mode=false/g" server.properties
    sed -i "s/server-name=Dedicated Server/server-name=Termux BDS Server/g" server.properties
fi
'

# 5. 백업 디렉토리 생성
mkdir -p /data/data/com.termux/files/home/bds_backups

# 6. 개별 관리 스크립트들 생성
echo ""
echo "[5/6] 서버 관리 스크립트 자동 생성 중..."

# start.sh
cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/bash
if tmux has-session -t mc 2>/dev/null; then
    echo "[!] 이미 마인크래프트 서버가 실행 중입니다."
    echo "    콘솔 확인: ./console.sh"
else
    echo "[*] 마인크래프트 BDS 서버를 백그라운드(tmux)에서 시작합니다..."
    tmux new-session -d -s mc "proot-distro login ubuntu -- bash -c 'cd /root/minecraft_bds && BOX64_DYNAREC=1 box64 ./bedrock_server'"
    sleep 3
    echo "[+] 서버가 시작되었습니다!"
fi
EOF

# stop.sh
cat << 'EOF' > ~/stop.sh
#!/data/data/com.termux/files/usr/bin/bash
if tmux has-session -t mc 2>/dev/null; then
    echo "[*] 서버에 안전 저장 및 종료 명령(stop)을 전송합니다..."
    tmux send-keys -t mc "stop" C-m
    while tmux has-session -t mc 2>/dev/null; do
        sleep 1
    done
    echo "[+] 마인크래프트 서버가 안전하게 종료되었습니다."
else
    echo "[!] 실행 중인 마인크래프트 서버가 없습니다."
fi
EOF

# console.sh
cat << 'EOF' > ~/console.sh
#!/data/data/com.termux/files/usr/bin/bash
if tmux has-session -t mc 2>/dev/null; then
    echo "[*] 마인크래프트 서버 콘솔에 연결합니다."
    echo "    [안내] 서버를 끄지 않고 나가려면: 볼륨다운+B 누른 뒤 d 키"
    sleep 1
    tmux attach-session -t mc
else
    echo "[!] 서버가 실행 중이지 않습니다."
fi
EOF

# backup.sh
cat << 'EOF' > ~/backup.sh
#!/data/data/com.termux/files/usr/bin/bash
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/data/data/com.termux/files/home/bds_backups"
mkdir -p "$BACKUP_DIR"
echo "[*] 월드를 백업 중입니다..."
proot-distro login ubuntu -- bash -c "
if [ -d /root/minecraft_bds/worlds ]; then
    tar -czf /root/world_backup_${TIMESTAMP}.tar.gz -C /root/minecraft_bds worlds
    mv /root/world_backup_${TIMESTAMP}.tar.gz /data/data/com.termux/files/home/bds_backups/
    echo '[+] 백업 성공: bds_backups/world_backup_${TIMESTAMP}.tar.gz'
else
    echo '[!] 백업할 월드가 없습니다.'
fi
"
EOF

# restore.sh
cat << 'EOF' > ~/restore.sh
#!/data/data/com.termux/files/usr/bin/bash
BACKUP_DIR="/data/data/com.termux/files/home/bds_backups"
FILES=("$BACKUP_DIR"/*.tar.gz)
if [ ! -e "${FILES[0]}" ]; then
    echo "[!] 저장된 백업 파일이 없습니다."
    exit 1
fi
echo "복구 가능한 백업 목록:"
INDEX=1
for file in "${FILES[@]}"; do
    echo " [$INDEX] $(basename "$file")"
    INDEX=$((INDEX + 1))
done
read -p "복구할 번호 선택 (취소 q): " choice
if [ "$choice" != "q" ] && [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$INDEX" ]; then
    SELECTED_FILE="${FILES[$((choice - 1))]}"
    if tmux has-session -t mc 2>/dev/null; then
        tmux send-keys -t mc "stop" C-m
        while tmux has-session -t mc 2>/dev/null; do sleep 1; done
    fi
    cp "$SELECTED_FILE" /data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/root/restore_target.tar.gz
    proot-distro login ubuntu -- bash -c "
    rm -rf /root/minecraft_bds/worlds
    tar -xzf /root/restore_target.tar.gz -C /root/minecraft_bds/
    rm -f /root/restore_target.tar.gz
    "
    echo "[+] 복구 완료! ./start.sh 로 켜세요."
fi
EOF

# reset_world.sh
cat << 'EOF' > ~/reset_world.sh
#!/data/data/com.termux/files/usr/bin/bash
read -p "정말 월드를 초기화하시겠습니까? (y/N): " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    if tmux has-session -t mc 2>/dev/null; then
        tmux send-keys -t mc "stop" C-m
        while tmux has-session -t mc 2>/dev/null; do sleep 1; done
    fi
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    proot-distro login ubuntu -- bash -c "
    if [ -d /root/minecraft_bds/worlds ]; then
        tar -czf /root/world_backup_${TIMESTAMP}.tar.gz -C /root/minecraft_bds worlds
        mv /root/world_backup_${TIMESTAMP}.tar.gz /data/data/com.termux/files/home/bds_backups/
        rm -rf /root/minecraft_bds/worlds
    fi
    "
    echo "[+] 월드가 초기화되었습니다! (백업 완료) ./start.sh 로 시작하세요."
fi
EOF

# export_backup.sh
cat << 'EOF' > ~/export_backup.sh
#!/data/data/com.termux/files/usr/bin/bash
BACKUP_DIR="/data/data/com.termux/files/home/bds_backups"
echo " [1] 스마트폰 다운로드 폴더로 복사"
echo " [2] 웹 다운로드 서버 열기 (http://IP:8080)"
read -p "선택: " m
if [ "$m" = "1" ]; then
    termux-setup-storage 2>/dev/null || true
    mkdir -p ~/storage/downloads/Minecraft_Backups 2>/dev/null || mkdir -p /sdcard/Download/Minecraft_Backups 2>/dev/null
    cp "$BACKUP_DIR"/*.tar.gz ~/storage/downloads/Minecraft_Backups/ 2>/dev/null || cp "$BACKUP_DIR"/*.tar.gz /sdcard/Download/Minecraft_Backups/ 2>/dev/null
    echo "[+] 다운로드 폴더로 복사 완료!"
elif [ "$m" = "2" ]; then
    cd "$BACKUP_DIR" && python -m http.server 8080
fi
EOF

# 7. menu.sh 및 bin/mc 설치
echo ""
echo "[6/6] 통합 관리자(mc) 메뉴 등록 중..."
curl -sL https://raw.githubusercontent.com/danielkj08/termux-mc-bds/main/menu.sh -o ~/menu.sh
sed -i 's/\r$//' ~/menu.sh

cat << 'EOF' > /data/data/com.termux/files/usr/bin/mc
#!/data/data/com.termux/files/usr/bin/bash
exec /data/data/com.termux/files/home/menu.sh "$@"
EOF
sed -i 's/\r$//' /data/data/com.termux/files/usr/bin/mc

chmod +x ~/*.sh /data/data/com.termux/files/usr/bin/mc 2>/dev/null || true
grep -q "alias mc=" ~/.bashrc 2>/dev/null || echo 'alias mc="~/menu.sh"' >> ~/.bashrc

# 절전 방지 활성화
termux-wake-lock 2>/dev/null || true

echo ""
echo "=========================================================="
echo "🎉 모든 자동 복구 및 설치가 완료되었습니다!"
echo "   이제 Termux에서 'mc' 를 입력하시면"
echo "   마인크래프트 서버 관리자가 바로 실행됩니다!"
echo "=========================================================="
