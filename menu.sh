#!/data/data/com.termux/files/usr/bin/bash

# 마인크래프트 올인원 통합 관리자 v2.3
BDS_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/root/minecraft_bds"
PROPS_FILE="$BDS_ROOT/server.properties"
HELPER="/data/data/com.termux/files/home/mc_helper.py"

# 플레이어 선택 공통 함수 (버프 및 게임모드 대상 선택용)
select_target_player() {
    echo "[*] 플레이어 목록을 확인하는 중..."
    RAW_PLAYERS=$(python "$HELPER" players)
    
    NAMES=()
    echo ""
    echo "-----------------------------------------------------"
    echo "대상을 선택하세요:"
    echo " [0] 👥 모든 플레이어 (@a)"
    
    INDEX=1
    if [ -n "$RAW_PLAYERS" ]; then
        while IFS='|' read -r idx name status op xuid; do
            [ -z "$name" ] && continue
            NAMES+=("$name")
            STATUS_BADGE="⚪ 최근 접속"
            [ "$status" = "ONLINE" ] && STATUS_BADGE="🟢 접속 중"
            OP_BADGE=""
            [ "$op" = "OP" ] && OP_BADGE="👑 [OP]"
            echo " [$INDEX] 👤 $name [$STATUS_BADGE] $OP_BADGE"
            INDEX=$((INDEX + 1))
        done <<< "$RAW_PLAYERS"
    fi
    echo " [m] ⌨️  닉네임 직접 타이핑하기"
    echo " [q] 🔙 취소"
    echo "-----------------------------------------------------"
    read -p "번호 선택 (기본 0): " pchoice

    if [ "$pchoice" = "q" ] || [ "$pchoice" = "Q" ]; then
        return 1
    elif [ "$pchoice" = "m" ] || [ "$pchoice" = "M" ]; then
        read -p "닉네임을 직접 입력하세요: " custom_p
        if [ -z "$custom_p" ]; then
            echo "[!] 닉네임이 비어있습니다."
            return 1
        fi
        SELECTED_PLAYER="$custom_p"
    elif [ -z "$pchoice" ] || [ "$pchoice" = "0" ]; then
        SELECTED_PLAYER="@a"
    elif [[ "$pchoice" =~ ^[0-9]+$ ]] && [ "$pchoice" -ge 1 ] && [ "$pchoice" -lt "$INDEX" ]; then
        SELECTED_PLAYER="${NAMES[$((pchoice - 1))]}"
    else
        echo "[!] 올바른 번호가 아닙니다."
        return 1
    fi
    return 0
}

while true; do
    clear
    # 1. helper로부터 실시간 상태 파싱
    STATUS_OUT=$(python "$HELPER" status 2>/dev/null)
    eval "$STATUS_OUT"

    # 서버 실행 상태
    if [ "$RUNNING" = "1" ]; then
        SERVER_STATUS="[✔ 켜짐 (Online)]"
    else
        SERVER_STATUS="[❌ 꺼짐 (Offline)]"
    fi

    # 접속 IP (LAN wlan0 및 Tailscale IP 병기)
    LAN_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    [ -z "$LAN_IP" ] && LAN_IP="192.168.0.253"
    TS_IP=$(tailscale ip -4 2>/dev/null)

    # 난이도 표시
    case "$DIFFICULTY" in
        peaceful) DISP_DIFF="[✔ 평화로움 (Peaceful)]";;
        easy) DISP_DIFF="[✔ 쉬움 (Easy)]";;
        normal) DISP_DIFF="[✔ 보통 (Normal)]";;
        hard) DISP_DIFF="[✔ 어려움 (Hard)]";;
        *) DISP_DIFF="[✔ $DIFFICULTY]";;
    esac

    # 게임 모드
    case "$GAMEMODE" in
        survival) DISP_MODE="서바이벌 (Survival)";;
        creative) DISP_MODE="크리에이티브 (Creative)";;
        adventure) DISP_MODE="모험 (Adventure)";;
        *) DISP_MODE="$GAMEMODE";;
    esac

    # 하드코어
    if [ "$HARDCORE" = "1" ]; then
        DISP_HC="[💀 하드코어 ON]"
    else
        DISP_HC="[일반 (Hardcore OFF)]"
    fi

    # 도전과제 (치트 비활성 여부)
    if [ "$ALLOW_CHEATS" = "false" ]; then
        DISP_ACHIEVE="[✔ 활성화 (치트 비활성)]"
    else
        DISP_ACHIEVE="[❌ 비활성 (치트 허용)]"
    fi

    # 계정 인증 모드
    if [ "$ONLINE_MODE" = "true" ]; then
        DISP_ONLINE="[✔ 정품 인증 필수 (true)]"
    else
        DISP_ONLINE="[❌ 비정품/오프라인 허용 (false)]"
    fi

    echo "====================================================="
    echo "       🎮 마인크래프트 BDS 초간편 통합 관리자 v2.3 🎮"
    echo "====================================================="
    echo "  서버 상태 : $SERVER_STATUS"
    echo "  내부 접속 : ${LAN_IP}:19132"
    [ -n "$TS_IP" ] && echo "  외부 테일 : ${TS_IP}:19132"
    echo "  월드 이름 : $LEVEL_NAME (${LEVEL_SEED:-시드: 무작위})"
    echo "  현재 난이도: $DISP_DIFF"
    echo "  서버 유형 : [✔ $DISP_MODE] | $DISP_HC"
    echo "  도전 과제 : $DISP_ACHIEVE"
    echo "  계정 인증 : $DISP_ONLINE"
    echo "====================================================="
    echo " [1]  서버 켜기 (Start)"
    echo " [2]  서버 끄기 (Stop)"
    echo " [3]  서버 재시작 (Restart)"
    echo " [4]  실시간 콘솔 화면 들어가기 (전체 화면 로그)"
    echo "-----------------------------------------------------"
    echo " [5]  👑 관리자(OP) 권한 관리 (접속자/최근 유저 목록 선택)"
    echo " [6]  ⚡ 물약 효과/버프 주기 (신속, 야간투시 등)"
    echo " [7]  ⚙️  게임 설정 실시간 변경 (난이도, 모드 전환, 하드코어)"
    echo " [8]  ⌨️  마크 콘솔 명령어 직접 한 줄 실행"
    echo "-----------------------------------------------------"
    echo " [9]  📊 스마트폰/서버 실시간 부하 상태 확인 (CPU, RAM)"
    echo " [10] 💾 월드 즉시 수동 백업하기"
    echo " [11] 🔄 이전 백업 시점으로 월드 복구하기 (Restore)"
    echo " [12] 📦 백업 파일 폰 다운로드 폴더로 내보내기 / 다운로드"
    echo " [13] 🌍 월드 초기화 및 새 월드 만들기 (시드/하드코어 설정 마법사)"
    echo "-----------------------------------------------------"
    echo " [0]  종료 (Exit)"
    echo "====================================================="
    read -p "원하시는 작업의 번호를 입력하세요: " choice

    case "$choice" in
        1)
            echo ""
            /data/data/com.termux/files/home/start.sh
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        2)
            echo ""
            /data/data/com.termux/files/home/stop.sh
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        3)
            echo ""
            echo "[*] 마인크래프트 서버를 재시작합니다..."
            /data/data/com.termux/files/home/stop.sh
            sleep 2
            /data/data/com.termux/files/home/start.sh
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        4)
            echo ""
            echo "[*] 콘솔 화면으로 들어갑니다. (나오실 때는 볼륨다운+B 누른 후 D 를 누르세요)"
            sleep 1
            /data/data/com.termux/files/home/console.sh
            ;;
        5)
            echo ""
            echo "====================================================="
            echo " 👑 관리자(OP) 권한 관리"
            echo "====================================================="
            RAW_PLAYERS=$(python "$HELPER" players)
            NAMES=()
            XUIDS=()
            IS_OPS=()
            echo "플레이어를 선택하세요:"
            INDEX=1
            if [ -n "$RAW_PLAYERS" ]; then
                while IFS='|' read -r idx name status op xuid; do
                    [ -z "$name" ] && continue
                    NAMES+=("$name")
                    XUIDS+=("$xuid")
                    IS_OPS+=("$op")
                    STATUS_BADGE="⚪ 최근 접속"
                    [ "$status" = "ONLINE" ] && STATUS_BADGE="🟢 접속 중"
                    OP_BADGE="[일반]"
                    [ "$op" = "OP" ] && OP_BADGE="👑 [OP 보유]"
                    echo " [$INDEX] 👤 $name [$STATUS_BADGE] $OP_BADGE"
                    INDEX=$((INDEX + 1))
                done <<< "$RAW_PLAYERS"
            else
                echo " (기록된 플레이어가 없습니다)"
            fi
            echo " [m] ⌨️  닉네임 직접 타이핑하기"
            echo " [q] 🔙 메인 메뉴로 돌아가기"
            echo "-----------------------------------------------------"
            read -p "번호 선택: " pchoice

            TARGET_NAME=""
            CURRENT_IS_OP="USER"
            if [ "$pchoice" = "q" ] || [ "$pchoice" = "Q" ]; then
                continue
            elif [ "$pchoice" = "m" ] || [ "$pchoice" = "M" ]; then
                read -p "닉네임을 직접 입력하세요: " TARGET_NAME
            elif [[ "$pchoice" =~ ^[0-9]+$ ]] && [ "$pchoice" -ge 1 ] && [ "$pchoice" -lt "$INDEX" ]; then
                TARGET_NAME="${NAMES[$((pchoice - 1))]}"
                CURRENT_IS_OP="${IS_OPS[$((pchoice - 1))]}"
            else
                echo "[!] 올바른 번호가 아닙니다."
                sleep 1
                continue
            fi

            if [ -n "$TARGET_NAME" ]; then
                echo ""
                OP_LABEL="일반 유저"
                if [ "$CURRENT_IS_OP" = "OP" ]; then
                    OP_LABEL="👑 OP 보유"
                fi
                echo "선택된 플레이어: $TARGET_NAME (현재 상태: $OP_LABEL)"
                echo " [1] 👑 OP 권한 부여하기 (op $TARGET_NAME)"
                echo " [2] ❌ OP 권한 박탈하기 (deop $TARGET_NAME)"
                echo " [q] 취소"
                read -p "작업 선택: " op_action
                case "$op_action" in
                    1)
                        python "$HELPER" set_op "$TARGET_NAME" 1
                        echo "[+] $TARGET_NAME 님에게 관리자(OP) 권한을 부여했습니다!"
                        echo "    (월드에 접속 중이면 즉시 적용되며, 재접속 시에도 영구 유지됩니다)"
                        ;;
                    2)
                        python "$HELPER" set_op "$TARGET_NAME" 0
                        echo "[+] $TARGET_NAME 님의 관리자(OP) 권한을 회수했습니다."
                        ;;
                    *)
                        echo "[-] 취소되었습니다."
                        ;;
                esac
            fi
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        6)
            echo ""
            echo "====================================================="
            echo " ⚡ 마인크래프트 포션 버프/효과 주기"
            echo "====================================================="
            if select_target_player; then
                echo ""
                echo "부여할 효과를 선택하세요 (대상: $SELECTED_PLAYER):"
                echo " [1]  👟 신속 (Speed) - 이동 속도 대폭 증가"
                echo " [2]  ⛏️  성급함 (Haste) - 채굴 및 공격 속도 증가"
                echo " [3]  💪 힘 (Strength) - 근접 공격력 증가"
                echo " [4]  💖 재생 (Regeneration) - 체력 자동 회복"
                echo " [5]  🛡️  저항 (Resistance) - 받는 피해 대폭 감소"
                echo " [6]  🔥 화염 저항 (Fire Resistance) - 용암/불 면역"
                echo " [7]  🫁 수중 호흡 (Water Breathing) - 물속 호흡 가능"
                echo " [8]  👀 야간 투시 (Night Vision) - 어두운 곳/물속 시야 확보"
                echo " [9]  🦘 도약 강화 (Jump Boost) - 점프 높이 증가"
                echo " [10] 🍖 포화 (Saturation) - 배고픔 무한 유지"
                echo " [11] ✨ 발광 (Glowing) - 벽 뒤에서도 위치 보임"
                echo " [12] 🧹 모든 효과 제거 (Clear All Effects)"
                echo " [q]  취소"
                read -p "효과 번호 선택: " eff_num

                EFF_NAME=""
                case "$eff_num" in
                    1) EFF_NAME="speed";;
                    2) EFF_NAME="haste";;
                    3) EFF_NAME="strength";;
                    4) EFF_NAME="regeneration";;
                    5) EFF_NAME="resistance";;
                    6) EFF_NAME="fire_resistance";;
                    7) EFF_NAME="water_breathing";;
                    8) EFF_NAME="night_vision";;
                    9) EFF_NAME="jump_boost";;
                    10) EFF_NAME="saturation";;
                    11) EFF_NAME="glowing";;
                    12) EFF_NAME="clear";;
                    q|Q) EFF_NAME="";;
                    *) echo "[!] 잘못된 선택입니다.";;
                esac

                if [ "$EFF_NAME" = "clear" ]; then
                    tmux send-keys -t mc "effect \"$SELECTED_PLAYER\" clear" Enter
                    echo "[+] $SELECTED_PLAYER 님의 모든 포션 효과를 제거했습니다."
                elif [ -n "$EFF_NAME" ]; then
                    read -p "효과 강도 레벨 (1~5 권장, 기본 3): " eff_amp
                    [ -z "$eff_amp" ] && eff_amp=3
                    tmux send-keys -t mc "effect \"$SELECTED_PLAYER\" $EFF_NAME 99999 $eff_amp true" Enter
                    echo "[+] $SELECTED_PLAYER 님에게 $EFF_NAME (레벨 $eff_amp, 입자 숨김) 효과를 부여했습니다!"
                fi
            fi
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        7)
            echo ""
            echo "====================================================="
            echo " ⚙️  게임 설정 및 서바이벌 ↔ 크리에이티브 전환"
            echo "====================================================="
            echo " [ 난이도 설정 ] (현재: $DISP_DIFF)"
            echo "  [1] 평화로움 (Peaceful)"
            echo "  [2] 쉬움 (Easy)"
            echo "  [3] 보통 (Normal)"
            echo "  [4] 어려움 (Hard)"
            echo ""
            echo " [ 🔄 게임모드 즉시 전환 ] (현재: $DISP_MODE)"
            echo "  [5] 🌲 서바이벌 모드로 전환 (Survival)"
            echo "  [6] 🏰 크리에이티브 모드로 전환 (Creative)"
            echo "  [7] 🗺️ 모험 모드로 전환 (Adventure)"
            echo ""
            echo " [ 💀 하드코어 모드 ] (현재: $DISP_HC)"
            echo "  [8] 하드코어 모드 켜기 (목숨 1개 + 난이도 어려움 고정 + 관전)"
            echo "  [9] 하드코어 모드 끄기 (일반 서바이벌로 복귀)"
            echo ""
            echo " [ 🏆 도전 과제 & 치트 ] (현재: $DISP_ACHIEVE)"
            echo "  [10] 도전과제 활성화 (치트 비활성: allow-cheats=false)"
            echo "  [11] 치트 허용 모드 (명령어 사용 가능: allow-cheats=true)"
            echo ""
            echo " [ 🌐 계정 인증 ] (현재: $DISP_ONLINE)"
            echo "  [12] 비정품/오프라인 계정 허용 (online-mode=false)"
            echo "  [13] 정품 Xbox 인증 필수 (online-mode=true)"
            echo "-----------------------------------------------------"
            echo " [q] 메인 메뉴로 돌아가기"
            echo "====================================================="
            read -p "변경할 설정 번호 입력: " sc

            case "$sc" in
                1)
                    python "$HELPER" set_prop "difficulty" "peaceful"
                    tmux send-keys -t mc "difficulty peaceful" Enter 2>/dev/null
                    echo "[+] 평화로움 난이도로 변경되었습니다.";;
                2)
                    python "$HELPER" set_prop "difficulty" "easy"
                    tmux send-keys -t mc "difficulty easy" Enter 2>/dev/null
                    echo "[+] 쉬움 난이도로 변경되었습니다.";;
                3)
                    python "$HELPER" set_prop "difficulty" "normal"
                    tmux send-keys -t mc "difficulty normal" Enter 2>/dev/null
                    echo "[+] 보통 난이도로 변경되었습니다.";;
                4)
                    python "$HELPER" set_prop "difficulty" "hard"
                    tmux send-keys -t mc "difficulty hard" Enter 2>/dev/null
                    echo "[+] 어려움 난이도로 변경되었습니다.";;
                5)
                    echo ""
                    echo "서바이벌 모드를 적용할 대상을 선택하세요:"
                    echo " [0] 👥 모든 플레이어 (@a) 및 기본 서버 모드"
                    echo " [1] 👤 특정 플레이어만 선택"
                    read -p "선택 (기본 0): " gm_target
                    if [ "$gm_target" = "1" ] && select_target_player; then
                        python "$HELPER" set_gamemode "survival" "$SELECTED_PLAYER"
                        echo "[+] $SELECTED_PLAYER 님의 게임모드가 서바이벌(Survival)로 변경되었습니다!"
                    else
                        python "$HELPER" set_gamemode "survival" "@a"
                        echo "[+] 모든 플레이어 및 기본 게임모드가 서바이벌(Survival)로 변경되었습니다!"
                    fi
                    ;;
                6)
                    echo ""
                    echo "크리에이티브 모드를 적용할 대상을 선택하세요:"
                    echo " [0] 👥 모든 플레이어 (@a) 및 기본 서버 모드"
                    echo " [1] 👤 특정 플레이어만 선택"
                    read -p "선택 (기본 0): " gm_target
                    if [ "$gm_target" = "1" ] && select_target_player; then
                        python "$HELPER" set_gamemode "creative" "$SELECTED_PLAYER"
                        echo "[+] $SELECTED_PLAYER 님의 게임모드가 크리에이티브(Creative)로 변경되었습니다!"
                    else
                        python "$HELPER" set_gamemode "creative" "@a"
                        echo "[+] 모든 플레이어 및 기본 게임모드가 크리에이티브(Creative)로 변경되었습니다!"
                        echo "    (하드코어 모드가 켜져 있었다면 자동으로 해제되었습니다)"
                    fi
                    ;;
                7)
                    echo ""
                    echo "모험 모드를 적용할 대상을 선택하세요:"
                    echo " [0] 👥 모든 플레이어 (@a) 및 기본 서버 모드"
                    echo " [1] 👤 특정 플레이어만 선택"
                    read -p "선택 (기본 0): " gm_target
                    if [ "$gm_target" = "1" ] && select_target_player; then
                        python "$HELPER" set_gamemode "adventure" "$SELECTED_PLAYER"
                        echo "[+] $SELECTED_PLAYER 님의 게임모드가 모험(Adventure)으로 변경되었습니다!"
                    else
                        python "$HELPER" set_gamemode "adventure" "@a"
                        echo "[+] 모든 플레이어 및 기본 게임모드가 모험(Adventure)으로 변경되었습니다!"
                    fi
                    ;;
                8)
                    echo "[*] 하드코어 설정을 적용하기 위해 서버를 재시작합니다..."
                    /data/data/com.termux/files/home/stop.sh
                    python "$HELPER" set_hardcore 1
                    /data/data/com.termux/files/home/start.sh
                    echo "[+] 💀 하드코어 모드가 켜졌습니다! (난이도 어려움 고정)";;
                9)
                    echo "[*] 일반 모드로 복구하기 위해 서버를 재시작합니다..."
                    /data/data/com.termux/files/home/stop.sh
                    python "$HELPER" set_hardcore 0
                    /data/data/com.termux/files/home/start.sh
                    echo "[+] 하드코어 모드가 해제되고 일반 모드로 복구되었습니다.";;
                10)
                    python "$HELPER" set_prop "allow-cheats" "false"
                    echo "[+] 치트가 꺼졌습니다. (서버 재시작 시 도전과제가 활성화됩니다)";;
                11)
                    python "$HELPER" set_prop "allow-cheats" "true"
                    echo "[+] 치트가 허용되었습니다. (도전과제 비활성화)";;
                12)
                    python "$HELPER" set_prop "online-mode" "false"
                    echo "[+] 오프라인/비정품 허용으로 설정되었습니다. (서버 재시작 시 적용)";;
                13)
                    python "$HELPER" set_prop "online-mode" "true"
                    echo "[+] 정품 Xbox 인증 필수로 설정되었습니다. (서버 재시작 시 적용)";;
                q|Q) echo "[-] 취소되었습니다.";;
                *) echo "[!] 잘못된 번호입니다.";;
            esac
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        8)
            echo ""
            if [ "$RUNNING" != "1" ]; then
                echo "[!] 서버가 켜져 있어야 명령어를 실행할 수 있습니다."
            else
                echo "====================================================="
                echo " ⌨️  마인크래프트 콘솔 명령어 직접 한 줄 입력"
                echo "    예시: time set day (낮으로 변경)"
                echo "          weather clear (날씨 맑음)"
                echo "          give @a diamond 64 (모두에게 다이아몬드 지급)"
                echo "          kill @e[type=zombie] (좀비 처치)"
                echo "    (슬래시 / 는 안 붙이셔도 됩니다. 취소는 q)"
                echo "====================================================="
                read -p "명령어 입력 > " raw_cmd
                if [ -n "$raw_cmd" ] && [ "$raw_cmd" != "q" ] && [ "$raw_cmd" != "Q" ]; then
                    clean_cmd=$(echo "$raw_cmd" | sed 's/^\///')
                    tmux send-keys -t mc "$clean_cmd" Enter
                    sleep 0.5
                    echo ""
                    echo "--- 📋 최근 서버 콘솔 응답 ---"
                    tmux capture-pane -pt mc -S -6
                    echo "------------------------------"
                fi
            fi
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        9)
            echo ""
            echo "================ 📊 서버 및 폰 부하 상태 ================"
            echo "1. 마인크래프트 프로세스 점유율:"
            ps aux | grep -E 'bedrock_server|box64' | grep -v grep | awk '{print "   - CPU 사용량: "$3"%, RAM 점유율: "$4"%, 실제 메모리: "$6/1024" MB"}'
            echo ""
            echo "2. 스마트폰 전체 메모리(RAM) 여유 상태:"
            free -m | grep -E 'Mem:' | awk '{print "   - 전체 RAM: "$2" MB, 사용 중: "$3" MB, 여유(가용): "$7" MB"}'
            echo ""
            echo "3. 현재 접속자 수:"
            tmux send-keys -t mc "list" Enter 2>/dev/null
            sleep 0.4
            tmux capture-pane -pt mc -S -10 | grep -E "There are [0-9]+/[0-9]+ players online" | tail -n 1
            echo "========================================================="
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        10)
            echo ""
            /data/data/com.termux/files/home/backup.sh
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        11)
            echo ""
            /data/data/com.termux/files/home/restore.sh
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        12)
            echo ""
            /data/data/com.termux/files/home/export_backup.sh
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        13)
            echo ""
            /data/data/com.termux/files/home/reset_world.sh
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        0)
            echo ""
            echo "관리자 메뉴를 종료합니다. 언제든 'mc' 를 치시면 다시 열립니다!"
            exit 0
            ;;
        *)
            echo "[!] 올바른 번호를 입력해 주세요."
            sleep 1
            ;;
    esac
done
