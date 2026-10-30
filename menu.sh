#!/data/data/com.termux/files/usr/bin/bash

# ?????? ??? ?? ??? v2.2
BDS_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/root/minecraft_bds"
PROPS_FILE="$BDS_ROOT/server.properties"
HELPER="/data/data/com.termux/files/home/mc_helper.py"

# ???? ?? ?? ?? (?? ? ?? ?? ???)
select_target_player() {
    echo "[*] ???? ??? ???? ?..."
    RAW_PLAYERS=$(python "$HELPER" players)
    
    NAMES=()
    echo ""
    echo "-----------------------------------------------------"
    echo "??? ??? ??? ?????:"
    echo " [0] ?? ?? ???? (@a)"
    
    INDEX=1
    if [ -n "$RAW_PLAYERS" ]; then
        while IFS='|' read -r idx name status op xuid; do
            [ -z "$name" ] && continue
            NAMES+=("$name")
            STATUS_BADGE="? ?? ??"
            [ "$status" = "ONLINE" ] && STATUS_BADGE="?? ?? ?"
            OP_BADGE=""
            [ "$op" = "OP" ] && OP_BADGE="?? [OP]"
            echo " [$INDEX] ?? $name [$STATUS_BADGE] $OP_BADGE"
            INDEX=$((INDEX + 1))
        done <<< "$RAW_PLAYERS"
    fi
    echo " [m] ??  ??? ?? ?????"
    echo " [q] ?? ??"
    echo "-----------------------------------------------------"
    read -p "?? ?? (?? 0): " pchoice

    if [ "$pchoice" = "q" ] || [ "$pchoice" = "Q" ]; then
        return 1
    elif [ "$pchoice" = "m" ] || [ "$pchoice" = "M" ]; then
        read -p "???? ?? ?????: " custom_p
        if [ -z "$custom_p" ]; then
            echo "[!] ???? ??????."
            return 1
        fi
        SELECTED_PLAYER="$custom_p"
    elif [ -z "$pchoice" ] || [ "$pchoice" = "0" ]; then
        SELECTED_PLAYER="@a"
    elif [[ "$pchoice" =~ ^[0-9]+$ ]] && [ "$pchoice" -ge 1 ] && [ "$pchoice" -lt "$INDEX" ]; then
        SELECTED_PLAYER="${NAMES[$((pchoice - 1))]}"
    else
        echo "[!] ??? ??? ????."
        return 1
    fi
    return 0
}

while true; do
    clear
    # 1. helper??? ??? ?? ??
    STATUS_OUT=$(python "$HELPER" status 2>/dev/null)
    eval "$STATUS_OUT"

    # ?? ?? ??
    if [ "$RUNNING" = "1" ]; then
        SERVER_STATUS="[? ?? (Online)]"
    else
        SERVER_STATUS="[? ?? (Offline)]"
    fi

    # ?? IP (LAN wlan0 ? Tailscale IP ??)
    LAN_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    [ -z "$LAN_IP" ] && LAN_IP="192.168.0.253"
    TS_IP=$(tailscale ip -4 2>/dev/null)

    # ??? ??
    case "$DIFFICULTY" in
        peaceful) DISP_DIFF="[? ???? (Peaceful)]";;
        easy) DISP_DIFF="[? ?? (Easy)]";;
        normal) DISP_DIFF="[? ?? (Normal)]";;
        hard) DISP_DIFF="[? ??? (Hard)]";;
        *) DISP_DIFF="[? $DIFFICULTY]";;
    esac

    # ?? ??
    case "$GAMEMODE" in
        survival) DISP_MODE="???? (Survival)";;
        creative) DISP_MODE="?????? (Creative)";;
        adventure) DISP_MODE="?? (Adventure)";;
        *) DISP_MODE="$GAMEMODE";;
    esac

    # ????
    if [ "$HARDCORE" = "1" ]; then
        DISP_HC="[?? ???? ON]"
    else
        DISP_HC="[?? (Hardcore OFF)]"
    fi

    # ???? (?? ??? ??)
    if [ "$ALLOW_CHEATS" = "false" ]; then
        DISP_ACHIEVE="[? ??? (?? ???)]"
    else
        DISP_ACHIEVE="[? ??? (?? ??)]"
    fi

    # ?? ?? ??
    if [ "$ONLINE_MODE" = "true" ]; then
        DISP_ONLINE="[? ?? ?? ?? (true)]"
    else
        DISP_ONLINE="[? ???/???? ?? (false)]"
    fi

    echo "====================================================="
    echo "       ?? ?????? BDS ??? ?? ??? v2.2 ??"
    echo "====================================================="
    echo "  ?? ?? : $SERVER_STATUS"
    echo "  ?? ?? : ${LAN_IP}:19132"
    [ -n "$TS_IP" ] && echo "  ?? ?? : ${TS_IP}:19132"
    echo "  ?? ?? : $LEVEL_NAME (${LEVEL_SEED:-??: ???})"
    echo "  ?? ???: $DISP_DIFF"
    echo "  ?? ?? : [? $DISP_MODE] | $DISP_HC"
    echo "  ?? ?? : $DISP_ACHIEVE"
    echo "  ?? ?? : $DISP_ONLINE"
    echo "====================================================="
    echo " [1]  ?? ?? (Start)"
    echo " [2]  ?? ?? (Stop)"
    echo " [3]  ?? ??? (Restart)"
    echo " [4]  ??? ?? ?? ???? (?? ?? ??)"
    echo "-----------------------------------------------------"
    echo " [5]  ?? ???(OP) ?? ?? (???/?? ?? ?? ??)"
    echo " [6]  ? ?? ??/?? ?? (??, ???? ?)"
    echo " [7]  ??  ?? ?? ??? ?? (???, ??, ???? ?)"
    echo " [8]  ??  ?? ?? ??? ?? ? ? ??"
    echo "-----------------------------------------------------"
    echo " [9]  ?? ????/?? ??? ?? ?? ?? (CPU, RAM)"
    echo " [10] ?? ?? ?? ?? ????"
    echo " [11] ?? ?? ?? ???? ?? ???? (Restore)"
    echo " [12] ?? ?? ?? ? ???? ??? ???? / ????"
    echo " [13] ?? ?? ??? ? ? ?? ??? (??/???? ?? ???)"
    echo "-----------------------------------------------------"
    echo " [0]  ?? (Exit)"
    echo "====================================================="
    read -p "???? ??? ??? ?????: " choice

    case "$choice" in
        1)
            echo ""
            /data/data/com.termux/files/home/start.sh
            read -p "??? ??? ??? ?????..." dummy
            ;;
        2)
            echo ""
            /data/data/com.termux/files/home/stop.sh
            read -p "??? ??? ??? ?????..." dummy
            ;;
        3)
            echo ""
            echo "[*] ?????? ??? ??????..."
            /data/data/com.termux/files/home/stop.sh
            sleep 2
            /data/data/com.termux/files/home/start.sh
            read -p "??? ??? ??? ?????..." dummy
            ;;
        4)
            echo ""
            echo "[*] ?? ???? ?????. (??? ?? Ctrl ?? ? B ? ??? ? ? ? D ? ????)"
            sleep 1
            /data/data/com.termux/files/home/console.sh
            ;;
        5)
            echo ""
            echo "====================================================="
            echo " ?? ???(OP) ?? ??"
            echo "====================================================="
            RAW_PLAYERS=$(python "$HELPER" players)
            NAMES=()
            XUIDS=()
            IS_OPS=()
            echo "????? ?????:"
            INDEX=1
            if [ -n "$RAW_PLAYERS" ]; then
                while IFS='|' read -r idx name status op xuid; do
                    [ -z "$name" ] && continue
                    NAMES+=("$name")
                    XUIDS+=("$xuid")
                    IS_OPS+=("$op")
                    STATUS_BADGE="? ?? ??"
                    [ "$status" = "ONLINE" ] && STATUS_BADGE="?? ?? ?"
                    OP_BADGE="[??]"
                    [ "$op" = "OP" ] && OP_BADGE="?? [OP ??]"
                    echo " [$INDEX] ?? $name [$STATUS_BADGE] $OP_BADGE"
                    INDEX=$((INDEX + 1))
                done <<< "$RAW_PLAYERS"
            else
                echo " (??? ????? ????)"
            fi
            echo " [m] ??  ??? ?? ?????"
            echo " [q] ?? ?? ??? ????"
            echo "-----------------------------------------------------"
            read -p "?? ??: " pchoice

            TARGET_NAME=""
            CURRENT_IS_OP="USER"
            if [ "$pchoice" = "q" ] || [ "$pchoice" = "Q" ]; then
                continue
            elif [ "$pchoice" = "m" ] || [ "$pchoice" = "M" ]; then
                read -p "???? ?? ?????: " TARGET_NAME
            elif [[ "$pchoice" =~ ^[0-9]+$ ]] && [ "$pchoice" -ge 1 ] && [ "$pchoice" -lt "$INDEX" ]; then
                TARGET_NAME="${NAMES[$((pchoice - 1))]}"
                CURRENT_IS_OP="${IS_OPS[$((pchoice - 1))]}"
            else
                echo "[!] ??? ??? ????."
                sleep 1
                continue
            fi

            if [ -n "$TARGET_NAME" ]; then
                echo ""
                echo "??? ????: $TARGET_NAME (?? ??: $([ "$CURRENT_IS_OP" = "OP" ] && echo '?? OP ??' || echo '?? ??'))"
                echo " [1] ?? OP ?? ???? (op $TARGET_NAME)"
                echo " [2] ? OP ?? ???? (deop $TARGET_NAME)"
                echo " [q] ??"
                read -p "?? ??: " op_action
                case "$op_action" in
                    1)
                        python "$HELPER" set_op "$TARGET_NAME" 1
                        echo "[+] $TARGET_NAME ??? ???(OP) ??? ??????!"
                        echo "    (??? ?? ??? ?? ????, ??? ??? ?? ?????)"
                        ;;
                    2)
                        python "$HELPER" set_op "$TARGET_NAME" 0
                        echo "[+] $TARGET_NAME ?? ???(OP) ??? ??????."
                        ;;
                    *)
                        echo "[-] ???????."
                        ;;
                esac
            fi
            read -p "??? ??? ??? ?????..." dummy
            ;;
        6)
            echo ""
            echo "====================================================="
            echo " ? ?????? ?? ??/?? ??"
            echo "====================================================="
            if select_target_player; then
                echo ""
                echo "??? ??? ????? (??: $SELECTED_PLAYER):"
                echo " [1]  ?? ?? (Speed) - ?? ?? ?? ??"
                echo " [2]  ??  ??? (Haste) - ?? ? ?? ?? ??"
                echo " [3]  ?? ? (Strength) - ?? ??? ??"
                echo " [4]  ?? ?? (Regeneration) - ?? ?? ??"
                echo " [5]  ???  ?? (Resistance) - ?? ?? ?? ??"
                echo " [6]  ?? ?? ?? (Fire Resistance) - ??/? ??"
                echo " [7]  ?? ?? ?? (Water Breathing) - ?? ?? ??"
                echo " [8]  ?? ?? ?? (Night Vision) - ??? ?/?? ?? ??"
                echo " [9]  ?? ?? ?? (Jump Boost) - ?? ?? ??"
                echo " [10] ?? ?? (Saturation) - ??? ?? ??"
                echo " [11] ? ?? (Glowing) - ? ???? ?? ??"
                echo " [12] ?? ?? ?? ?? (Clear All Effects)"
                echo " [q]  ??"
                read -p "?? ?? ??: " eff_num

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
                    *) echo "[!] ??? ?????.";;
                esac

                if [ "$EFF_NAME" = "clear" ]; then
                    tmux send-keys -t mc "effect \"$SELECTED_PLAYER\" clear" Enter
                    echo "[+] $SELECTED_PLAYER ?? ?? ?? ??? ??????."
                elif [ -n "$EFF_NAME" ]; then
                    read -p "?? ?? ?? (1~5 ??, ?? 3): " eff_amp
                    [ -z "$eff_amp" ] && eff_amp=3
                    tmux send-keys -t mc "effect \"$SELECTED_PLAYER\" $EFF_NAME 99999 $eff_amp true" Enter
                    echo "[+] $SELECTED_PLAYER ??? $EFF_NAME (?? $eff_amp, ?? ??) ??? ??????!"
                fi
            fi
            read -p "??? ??? ??? ?????..." dummy
            ;;
        7)
            echo ""
            echo "====================================================="
            echo " ??  ?? ?? ??? ??"
            echo "====================================================="
            echo " [ ??? ?? ] (??: $DISP_DIFF)"
            echo "  [1] ???? (Peaceful)"
            echo "  [2] ?? (Easy)"
            echo "  [3] ?? (Normal)"
            echo "  [4] ??? (Hard)"
            echo ""
            echo " [ ?? ???? ?? ] (??: $DISP_MODE)"
            echo "  [5] ???? (Survival)"
            echo "  [6] ?????? (Creative)"
            echo "  [7] ?? (Adventure)"
            echo ""
            echo " [ ?? ???? ?? ] (??: $DISP_HC)"
            echo "  [8] ???? ?? ?? (?? 1? + ??? ??? ?? + ??)"
            echo "  [9] ???? ?? ?? (?? ????? ??)"
            echo ""
            echo " [ ?? ?? ?? & ?? ] (??: $DISP_ACHIEVE)"
            echo "  [10] ???? ??? (?? ???: allow-cheats=false)"
            echo "  [11] ?? ?? ?? (??? ?? ??: allow-cheats=true)"
            echo ""
            echo " [ ?? ?? ?? ] (??: $DISP_ONLINE)"
            echo "  [12] ???/???? ?? ?? (online-mode=false)"
            echo "  [13] ?? Xbox ?? ?? (online-mode=true)"
            echo "-----------------------------------------------------"
            echo " [q] ?? ??? ????"
            echo "====================================================="
            read -p "??? ?? ?? ??: " sc

            case "$sc" in
                1)
                    python "$HELPER" set_prop "difficulty" "peaceful"
                    tmux send-keys -t mc "difficulty peaceful" Enter 2>/dev/null
                    echo "[+] ???? ???? ???????.";;
                2)
                    python "$HELPER" set_prop "difficulty" "easy"
                    tmux send-keys -t mc "difficulty easy" Enter 2>/dev/null
                    echo "[+] ?? ???? ???????.";;
                3)
                    python "$HELPER" set_prop "difficulty" "normal"
                    tmux send-keys -t mc "difficulty normal" Enter 2>/dev/null
                    echo "[+] ?? ???? ???????.";;
                4)
                    python "$HELPER" set_prop "difficulty" "hard"
                    tmux send-keys -t mc "difficulty hard" Enter 2>/dev/null
                    echo "[+] ??? ???? ???????.";;
                5)
                    python "$HELPER" set_prop "gamemode" "survival"
                    tmux send-keys -t mc "defaultgamemode survival" Enter 2>/dev/null
                    echo "[+] ???? ??? ???????.";;
                6)
                    python "$HELPER" set_prop "gamemode" "creative"
                    tmux send-keys -t mc "defaultgamemode creative" Enter 2>/dev/null
                    echo "[+] ?????? ??? ???????.";;
                7)
                    python "$HELPER" set_prop "gamemode" "adventure"
                    tmux send-keys -t mc "defaultgamemode adventure" Enter 2>/dev/null
                    echo "[+] ?? ??? ???????.";;
                8)
                    echo "[*] ???? ??? ???? ?? ??? ??????..."
                    /data/data/com.termux/files/home/stop.sh
                    python "$HELPER" set_hardcore 1
                    /data/data/com.termux/files/home/start.sh
                    echo "[+] ?? ???? ??? ?????! (??? ??? ??)";;
                9)
                    echo "[*] ?? ??? ???? ?? ??? ??????..."
                    /data/data/com.termux/files/home/stop.sh
                    python "$HELPER" set_hardcore 0
                    /data/data/com.termux/files/home/start.sh
                    echo "[+] ???? ??? ???? ?? ??? ???????.";;
                10)
                    python "$HELPER" set_prop "allow-cheats" "false"
                    echo "[+] ??? ?????. (?? ??? ? ????? ??????)";;
                11)
                    python "$HELPER" set_prop "allow-cheats" "true"
                    echo "[+] ??? ???????. (???? ????)";;
                12)
                    python "$HELPER" set_prop "online-mode" "false"
                    echo "[+] ????/??? ???? ???????. (?? ??? ? ??)";;
                13)
                    python "$HELPER" set_prop "online-mode" "true"
                    echo "[+] ?? Xbox ?? ??? ???????. (?? ??? ? ??)";;
                q|Q) echo "[-] ???????.";;
                *) echo "[!] ??? ?????.";;
            esac
            read -p "??? ??? ??? ?????..." dummy
            ;;
        8)
            echo ""
            if [ "$RUNNING" != "1" ]; then
                echo "[!] ??? ?? ??? ???? ??? ? ????."
            else
                echo "====================================================="
                echo " ??  ?????? ?? ??? ?? ? ? ??"
                echo "    ??: time set day (??? ??)"
                echo "          weather clear (?? ??)"
                echo "          give @a diamond 64 (???? ????? ??)"
                echo "          kill @e[type=zombie] (?? ??)"
                echo "    (??? / ? ? ???? ???. ??? q)"
                echo "====================================================="
                read -p "??? ?? > " raw_cmd
                if [ -n "$raw_cmd" ] && [ "$raw_cmd" != "q" ] && [ "$raw_cmd" != "Q" ]; then
                    clean_cmd=$(echo "$raw_cmd" | sed 's/^\///')
                    tmux send-keys -t mc "$clean_cmd" Enter
                    sleep 0.5
                    echo ""
                    echo "--- ?? ?? ?? ?? ?? ---"
                    tmux capture-pane -pt mc -S -6
                    echo "------------------------------"
                fi
            fi
            read -p "??? ??? ??? ?????..." dummy
            ;;
        9)
            echo ""
            echo "================ ?? ?? ? ? ?? ?? ================"
            echo "1. ?????? ???? ???:"
            ps aux | grep -E 'bedrock_server|box64' | grep -v grep | awk '{print "   - CPU ???: "$3"%, RAM ???: "$4"%, ?? ???: "$6/1024" MB"}'
            echo ""
            echo "2. ???? ?? ???(RAM) ?? ??:"
            free -m | grep -E 'Mem:' | awk '{print "   - ?? RAM: "$2" MB, ?? ?: "$3" MB, ??(??): "$7" MB"}'
            echo ""
            echo "3. ?? ??? ?:"
            tmux send-keys -t mc "list" Enter 2>/dev/null
            sleep 0.4
            tmux capture-pane -pt mc -S -10 | grep -E "There are [0-9]+/[0-9]+ players online" | tail -n 1
            echo "========================================================="
            read -p "??? ??? ??? ?????..." dummy
            ;;
        10)
            echo ""
            /data/data/com.termux/files/home/backup.sh
            read -p "??? ??? ??? ?????..." dummy
            ;;
        11)
            echo ""
            /data/data/com.termux/files/home/restore.sh
            read -p "??? ??? ??? ?????..." dummy
            ;;
        12)
            echo ""
            /data/data/com.termux/files/home/export_backup.sh
            read -p "??? ??? ??? ?????..." dummy
            ;;
        13)
            echo ""
            /data/data/com.termux/files/home/reset_world.sh
            read -p "??? ??? ??? ?????..." dummy
            ;;
        0)
            echo ""
            echo "??? ??? ?????. ??? 'mc' ? ??? ?? ????!"
            exit 0
            ;;
        *)
            echo "[!] ??? ??? ??? ???."
            sleep 1
            ;;
    esac
done
