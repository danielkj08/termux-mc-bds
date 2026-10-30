#!/data/data/com.termux/files/usr/bin/bash

# 마인크래프트 올인원 통합 관리자 v2.0
BACKUP_DIR="/data/data/com.termux/files/home/bds_backups"
mkdir -p "$BACKUP_DIR"

# BDS server.properties 경로
PROPS_FILE="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/root/minecraft_bds/server.properties"

# 접속자 목록 가져오기 함수
get_online_players() {
    tmux send-keys -t mc "list" C-m
    sleep 0.5
    LINE=$(tmux capture-pane -pt mc -S -15 | grep -E "There are [0-9]+/[0-9]+ players online" | tail -n 1)
    NAMES=$(echo "$LINE" | sed -E 's/.*players online:? ?//' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
    echo "$NAMES"
}

# 플레이어 번호 선택 공통 함수
select_player() {
    if ! tmux has-session -t mc 2>/dev/null; then
        echo "[!] 서버가 꺼져 있습니다."
        return 1
    fi

    echo "[*] 현재 서버 접속자 목록을 불러오는 중..."
    RAW_NAMES=$(get_online_players)
    PLIST=()
    while IFS= read -r line; do
        [ -n "$line" ] && PLIST+=("$line")
    done <<< "$RAW_NAMES"

    echo ""
    echo "-----------------------------------------------------"
    echo "대상 플레이어를 선택하세요:"
    echo " [0] 👥 모든 플레이어 (@a)"
    INDEX=1
    if [ ${#PLIST[@]} -gt 0 ]; then
        for p in "${PLIST[@]}"; do
            echo " [$INDEX] 👤 $p (현재 접속 중)"
            INDEX=$((INDEX + 1))
        done
    else
        echo " (현재 접속 중인 플레이어가 없습니다)"
    fi
    echo " [m] ⌨️  닉네임 직접 타이핑하기"
    echo "-----------------------------------------------------"
    read -p "번호 선택 (기본 0): " pchoice

    if [ "$pchoice" = "m" ] || [ "$pchoice" = "M" ]; then
        read -p "닉네임을 직접 입력하세요: " custom_p
        if [ -z "$custom_p" ]; then
            echo "[!] 닉네임이 비어있습니다."
            return 1
        fi
        SELECTED_PLAYER="$custom_p"
    elif [ -z "$pchoice" ] || [ "$pchoice" = "0" ]; then
        SELECTED_PLAYER="@a"
    elif [[ "$pchoice" =~ ^[0-9]+$ ]] && [ "$pchoice" -ge 1 ] && [ "$pchoice" -lt "$INDEX" ]; then
        SELECTED_PLAYER="${PLIST[$((pchoice - 1))]}"
    else
        echo "[!] 올바른 번호가 아닙니다."
        return 1
    fi
    return 0
}

while true; do
    clear
    # 1. 서버 실행 상태
    if tmux has-session -t mc 2>/dev/null; then
        SERVER_STATUS="[✔ 켜짐 (Online)]"
    else
        SERVER_STATUS="[❌ 꺼짐 (Offline)]"
    fi

    # 2. IP 확인
    MY_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    if [ -z "$MY_IP" ]; then
        MY_IP="192.168.0.253"
    fi

    # 3. server.properties 설정 상태 읽기
    CUR_DIFF="알 수 없음"
    CUR_MODE="알 수 없음"
    CUR_ONLINE="알 수 없음"
    if [ -f "$PROPS_FILE" ]; then
        RAW_DIFF=$(grep -E '^difficulty=' "$PROPS_FILE" | cut -d'=' -f2 | tr -d '\r')
        case "$RAW_DIFF" in
            peaceful) CUR_DIFF="[✔ 평화로움]";;
            easy) CUR_DIFF="[✔ 쉬움 (Easy)]";;
            normal) CUR_DIFF="[✔ 보통 (Normal)]";;
            hard) CUR_DIFF="[✔ 어려움 (Hard)]";;
            *) CUR_DIFF="[✔ $RAW_DIFF]";;
        esac

        RAW_MODE=$(grep -E '^gamemode=' "$PROPS_FILE" | cut -d'=' -f2 | tr -d '\r')
        case "$RAW_MODE" in
            survival) CUR_MODE="[✔ 서바이벌]";;
            creative) CUR_MODE="[✔ 크리에이티브]";;
            adventure) CUR_MODE="[✔ 모험]";;
            *) CUR_MODE="[✔ $RAW_MODE]";;
        esac

        RAW_ON=$(grep -E '^online-mode=' "$PROPS_FILE" | cut -d'=' -f2 | tr -d '\r')
        if [ "$RAW_ON" = "true" ]; then
            CUR_ONLINE="[✔ 정품 인증 모드 (true)]"
        else
            CUR_ONLINE="[❌ 오프라인/비정품 허용 (false)]"
        fi
    fi

    echo "====================================================="
    echo "       🎮 마인크래프트 BDS 초간편 통합 관리자 🎮"
    echo "====================================================="
    echo "  서버 상태 : $SERVER_STATUS"
    echo "  접속 주소 : ${MY_IP}:19132"
    echo "  현재 난이도: $CUR_DIFF | 게임모드: $CUR_MODE"
    echo "  계정 인증 : $CUR_ONLINE"
    echo "====================================================="
    echo " [1]  서버 켜기 (Start)"
    echo " [2]  서버 끄기 (Stop)"
    echo " [3]  서버 재시작 (Restart)"
    echo " [4]  실시간 콘솔 화면 들어가기 (전체 화면 로그)"
    echo "-----------------------------------------------------"
    echo " [5]  👑 관리자(OP) 권한 부여 (접속자 번호 선택)"
    echo " [6]  ⚡ 물약 효과/버프 주기 (신속, 야간투시 등)"
    echo " [7]  ⚙️  난이도 / 게임모드 체크마크 설정 변경"
    echo " [8]  ⌨️  직접 마인크래프트 명령어 한 줄 실행 (time, give 등)"
    echo " [9]  📊 서버 렉 / CPU 및 메모리 부하 확인"
    echo "-----------------------------------------------------"
    echo " [10] 💾 현재 월드 백업하기"
    echo " [11] ⏪ 이전 백업으로 되돌리기 (목록 번호 복구)"
    echo " [12] 📤 백업 파일 스마트폰(내 파일)이나 PC로 꺼내기"
    echo " [13] ⚠️  월드 리셋 (기존 맵 자동 백업 후 새 맵 시작)"
    echo "-----------------------------------------------------"
    echo " [0]  종료 (메뉴 닫기)"
    echo "====================================================="
    read -p "👉 원하는 작업 번호를 입력하세요: " menu_choice

    case "$menu_choice" in
        1)
            echo ""
            if tmux has-session -t mc 2>/dev/null; then
                echo "[!] 이미 서버가 [✔ 켜짐] 상태입니다!"
            else
                echo "[*] 마인크래프트 서버를 시작하는 중입니다..."
                tmux new-session -d -s mc "proot-distro login ubuntu -- bash -c 'cd /root/minecraft_bds && BOX64_DYNAREC=1 box64 ./bedrock_server'"
                sleep 3
                echo "[+] 서버가 성공적으로 켜졌습니다! [✔ 켜짐]"
            fi
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        2)
            echo ""
            if tmux has-session -t mc 2>/dev/null; then
                echo "[*] 맵 데이터를 안전하게 저장하고 서버를 종료합니다..."
                tmux send-keys -t mc "stop" C-m
                while tmux has-session -t mc 2>/dev/null; do
                    sleep 1
                done
                echo "[+] 서버가 안전하게 종료되었습니다. [❌ 꺼짐]"
            else
                echo "[!] 이미 서버가 [❌ 꺼짐] 상태입니다."
            fi
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        3)
            echo ""
            echo "[*] 서버를 재시작합니다..."
            if tmux has-session -t mc 2>/dev/null; then
                tmux send-keys -t mc "stop" C-m
                while tmux has-session -t mc 2>/dev/null; do
                    sleep 1
                done
            fi
            tmux new-session -d -s mc "proot-distro login ubuntu -- bash -c 'cd /root/minecraft_bds && BOX64_DYNAREC=1 box64 ./bedrock_server'"
            sleep 3
            echo "[+] 서버가 성공적으로 재시작되었습니다!"
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        4)
            echo ""
            if tmux has-session -t mc 2>/dev/null; then
                echo "====================================================="
                echo " ⚠️  콘솔 화면에서 서버 끄지 않고 빠져나오는 법:"
                echo "     '볼륨다운키 + B' 누른 뒤 손 떼고 'D' 키 누르기!"
                echo "====================================================="
                sleep 2
                tmux attach-session -t mc
            else
                echo "[!] 서버가 꺼져 있습니다. 먼저 1번으로 켜주세요."
                read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            fi
            ;;
        5)
            echo ""
            if select_player; then
                tmux send-keys -t mc op Space "$SELECTED_PLAYER" Enter
                echo "[+] '$SELECTED_PLAYER' 님에게 관리자(OP) 권한을 부여했습니다!"
            fi
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        6)
            echo ""
            if select_player; then
                echo ""
                echo "부여할 효과를 번호로 선택하세요:"
                echo " [1]  ⚡ 신속 (이동속도 증가)"
                echo " [2]  👁️  야간 투시 (어두운 곳 대낮처럼)"
                echo " [3]  🦘 점프 강화 (높이 점프)"
                echo " [4]  💖 체력 완전 회복 (즉시 힐)"
                echo " [5]  🛡️  재생 (체력이 계속 참)"
                echo " [6]  ⚔️  힘 (초강력 공격력)"
                echo " [7]  🔥 화염 저항 (용암/불 면역)"
                echo " [8]  🤿 수중 호흡 (물속 숨쉬기)"
                echo " [9]  👻 투명화 (몸 숨기기)"
                echo " [10] 🪶 느린 낙하 (낙뎀 0)"
                echo " [11] ⛏️  성급함 (초고속 채굴)"
                echo " [12] ❌ 모든 효과 제거 (원래 상태로 복귀)"
                echo "-----------------------------------------------------"
                read -p "효과 번호 선택: " eff_num

                EFF_NAME=""
                EFF_AMP="1"
                EFF_SEC="99999"

                case "$eff_num" in
                    1)
                        EFF_NAME="speed"
                        echo "속도 레벨: [1] 일반 빠름 (Level 1)  [2] 매우 빠름 (Level 3)  [3] 광속 질주 (Level 5)"
                        read -p "선택 (기본 2): " s_lv
                        [ "$s_lv" = "1" ] && EFF_AMP="0"
                        [ "$s_lv" = "3" ] && EFF_AMP="4"
                        [ -z "$s_lv" ] || [ "$s_lv" = "2" ] && EFF_AMP="2"
                        ;;
                    2) EFF_NAME="night_vision";;
                    3) EFF_NAME="jump_boost"; EFF_AMP="2";;
                    4) EFF_NAME="instant_health"; EFF_SEC="1"; EFF_AMP="255";;
                    5) EFF_NAME="regeneration"; EFF_AMP="4";;
                    6) EFF_NAME="strength"; EFF_AMP="4";;
                    7) EFF_NAME="fire_resistance";;
                    8) EFF_NAME="water_breathing";;
                    9) EFF_NAME="invisibility";;
                    10) EFF_NAME="slow_falling";;
                    11) EFF_NAME="haste"; EFF_AMP="3";;
                    12) EFF_NAME="clear";;
                    *) echo "[!] 잘못된 번호입니다.";;
                esac

                if [ "$EFF_NAME" = "clear" ]; then
                    tmux send-keys -t mc effect Space "$SELECTED_PLAYER" Space clear Enter
                    echo "[+] '$SELECTED_PLAYER'의 모든 효과를 제거했습니다."
                elif [ -n "$EFF_NAME" ]; then
                    tmux send-keys -t mc effect Space "$SELECTED_PLAYER" Space "$EFF_NAME" Space "$EFF_SEC" Space "$EFF_AMP" Space true Enter
                    echo "[+] '$SELECTED_PLAYER'에게 $EFF_NAME 효과를 부여했습니다!"
                fi
            fi
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        7)
            echo ""
            echo "현재 설정된 상태를 확인하고 번호로 변경하세요:"
            echo "-----------------------------------------------------"
            echo " [1] 난이도: 평화로움 $( [ "$RAW_DIFF" = "peaceful" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo " [2] 난이도: 쉬움 (Easy) $( [ "$RAW_DIFF" = "easy" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo " [3] 난이도: 보통 (Normal) $( [ "$RAW_DIFF" = "normal" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo " [4] 난이도: 어려움 (Hard) $( [ "$RAW_DIFF" = "hard" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo "-----------------------------------------------------"
            echo " [5] 기본모드: 서바이벌 $( [ "$RAW_MODE" = "survival" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo " [6] 기본모드: 크리에이티브 $( [ "$RAW_MODE" = "creative" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo "-----------------------------------------------------"
            echo " [7] 엑박 정품 인증(online-mode): 켜기(true) $( [ "$RAW_ON" = "true" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo " [8] 엑박 정품 인증(online-mode): 끄기(false, 비정품/자유) $( [ "$RAW_ON" = "false" ] && echo "[✔ 현재]" || echo "[ ]" )"
            echo "-----------------------------------------------------"
            read -p "변경할 번호 선택 (취소는 q): " set_choice

            case "$set_choice" in
                1) tmux send-keys -t mc difficulty Space peaceful Enter; sed -i 's/^difficulty=.*/difficulty=peaceful/' "$PROPS_FILE"; echo "[+] 평화로움으로 변경되었습니다.";;
                2) tmux send-keys -t mc difficulty Space easy Enter; sed -i 's/^difficulty=.*/difficulty=easy/' "$PROPS_FILE"; echo "[+] 쉬움 난이도로 변경되었습니다.";;
                3) tmux send-keys -t mc difficulty Space normal Enter; sed -i 's/^difficulty=.*/difficulty=normal/' "$PROPS_FILE"; echo "[+] 보통 난이도로 변경되었습니다.";;
                4) tmux send-keys -t mc difficulty Space hard Enter; sed -i 's/^difficulty=.*/difficulty=hard/' "$PROPS_FILE"; echo "[+] 어려움 난이도로 변경되었습니다.";;
                5) tmux send-keys -t mc defaultgamemode Space survival Enter; sed -i 's/^gamemode=.*/gamemode=survival/' "$PROPS_FILE"; echo "[+] 서바이벌 모드로 변경되었습니다.";;
                6) tmux send-keys -t mc defaultgamemode Space creative Enter; sed -i 's/^gamemode=.*/gamemode=creative/' "$PROPS_FILE"; echo "[+] 크리에이티브 모드로 변경되었습니다.";;
                7) sed -i 's/^online-mode=.*/online-mode=true/' "$PROPS_FILE"; echo "[+] online-mode=true 로 변경되었습니다. (서버 재시작 시 적용)";;
                8) sed -i 's/^online-mode=.*/online-mode=false/' "$PROPS_FILE"; echo "[+] online-mode=false 로 변경되었습니다. (서버 재시작 시 적용)";;
                q|Q) echo "[-] 취소되었습니다.";;
                *) echo "[!] 잘못된 번호입니다.";;
            esac
            read -p "엔터를 누르면 메뉴로 돌아갑니다..." dummy
            ;;
        8)
            echo ""
            if ! tmux has-session -t mc 2>/dev/null; then
                echo "[!] 서버가 켜져 있어야 명령어를 실행할 수 있습니다."
            else
                echo "====================================================="
                echo " ⌨️  마인크래프트 명령어 직접 한 줄 입력"
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
                    echo "--- 📋 최근 서버 로그 (실행 결과) ---"
                    tmux capture-pane -pt mc -S -6
                    echo "--------------------------------------"
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
            tmux send-keys -t mc "list" C-m
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
