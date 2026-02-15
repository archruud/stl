#!/bin/bash
# DropdownTmux.sh - Dropdown terminal med persistent tmux
# Usage: 
#   ./DropdownTmux.sh          - Toggle dropdown
#   ./DropdownTmux.sh full     - Toggle fullscreen/normal
#   ./DropdownTmux.sh reset    - DREP session og start på nytt (sletter alt!)

DEBUG=false
TMUX_SESSION="dropdown"
TERMINAL_CMD="kitty"
ADDR_FILE="/tmp/dropdown_tmux_addr"
SIZE_FILE="/tmp/dropdown_tmux_size"
MODE_FILE="/tmp/dropdown_tmux_mode"

# Standard størrelse (endre disse for å endre default størrelse!)
DEFAULT_WIDTH=80   # Endre til 90 om du vil
DEFAULT_HEIGHT=80  # Endre til 90 om du vil
DEFAULT_X=10       # 10% fra venstre = sentrert
DEFAULT_Y=5        # 5% fra topp

# Fullskjerm størrelse
FULLSCREEN_WIDTH=95
FULLSCREEN_HEIGHT=90
FULLSCREEN_X=2
FULLSCREEN_Y=5

# Parse argumenter
ACTION="${1:-toggle}"

if [ "$1" = "-d" ]; then
    DEBUG=true
    ACTION="${2:-toggle}"
fi

debug_echo() {
    if [ "$DEBUG" = true ]; then
        echo "$@"
    fi
}

# Sjekk hvilken mode vi er i
get_current_mode() {
    if [ -f "$MODE_FILE" ]; then
        cat "$MODE_FILE"
    else
        echo "normal"
    fi
}

set_mode() {
    echo "$1" > "$MODE_FILE"
}

# Last eller lag size config
load_size_config() {
    if [ -f "$SIZE_FILE" ]; then
        source "$SIZE_FILE"
    else
        WIDTH_PERCENT=$DEFAULT_WIDTH
        HEIGHT_PERCENT=$DEFAULT_HEIGHT
        X_PERCENT=$DEFAULT_X
        Y_PERCENT=$DEFAULT_Y
        save_size_config
    fi
}

save_size_config() {
    cat > "$SIZE_FILE" <<EOF
WIDTH_PERCENT=$WIDTH_PERCENT
HEIGHT_PERCENT=$HEIGHT_PERCENT
X_PERCENT=$X_PERCENT
Y_PERCENT=$Y_PERCENT
EOF
}

# Hent monitor info
get_monitor_info() {
    hyprctl monitors -j | jq -r '.[0] | "\(.x) \(.y) \(.width) \(.height)"'
}

# Beregn posisjon
calculate_position() {
    local monitor_info=$(get_monitor_info)
    local mon_x=$(echo $monitor_info | cut -d' ' -f1)
    local mon_y=$(echo $monitor_info | cut -d' ' -f2)
    local mon_width=$(echo $monitor_info | cut -d' ' -f3)
    local mon_height=$(echo $monitor_info | cut -d' ' -f4)

    local width=$((mon_width * WIDTH_PERCENT / 100))
    local height=$((mon_height * HEIGHT_PERCENT / 100))
    local x=$((mon_x + (mon_width * X_PERCENT / 100)))
    local y=$((mon_y + (mon_height * Y_PERCENT / 100)))

    echo "$x $y $width $height"
}

# Sjekk om tmux-sesjon finnes
tmux_session_exists() {
    tmux has-session -t "$TMUX_SESSION" 2>/dev/null
    return $?
}

# Hent terminal address
get_terminal_addr() {
    if [ -f "$ADDR_FILE" ]; then
        cat "$ADDR_FILE"
    fi
}

# Sjekk om terminal eksisterer
terminal_exists() {
    local addr=$(get_terminal_addr)
    if [ -n "$addr" ]; then
        hyprctl clients -j | jq -e --arg ADDR "$addr" 'any(.[]; .address == $ADDR)' >/dev/null 2>&1
        return $?
    fi
    return 1
}

# Sjekk om terminal er synlig
terminal_visible() {
    local addr=$(get_terminal_addr)
    if [ -n "$addr" ]; then
        local ws=$(hyprctl clients -j | jq -r --arg ADDR "$addr" '.[] | select(.address == $ADDR) | .workspace.name')
        if [ "$ws" != "special:scratchpad" ]; then
            return 0
        fi
    fi
    return 1
}

# Start dropdown terminal med tmux
spawn_dropdown() {
    debug_echo "Spawner ny dropdown terminal med tmux"
    
    pos_info=$(calculate_position)
    width=$(echo $pos_info | cut -d' ' -f3)
    height=$(echo $pos_info | cut -d' ' -f4)

    hyprctl dispatch exec "[float; size $width $height; workspace special:scratchpad silent] $TERMINAL_CMD -e tmux new-session -A -s $TMUX_SESSION"
    
    sleep 0.3
    
    local new_addr=$(hyprctl clients -j | jq -r 'sort_by(.focusHistoryID) | .[-1] | .address')
    
    if [ -n "$new_addr" ] && [ "$new_addr" != "null" ]; then
        echo "$new_addr" > "$ADDR_FILE"
        debug_echo "Terminal spawnet med address: $new_addr"
        return 0
    fi
    
    return 1
}

# Vis dropdown
show_dropdown() {
    local addr=$(get_terminal_addr)
    local current_ws=$(hyprctl activeworkspace -j | jq -r '.id')
    
    pos_info=$(calculate_position)
    local x=$(echo $pos_info | cut -d' ' -f1)
    local y=$(echo $pos_info | cut -d' ' -f2)
    local width=$(echo $pos_info | cut -d' ' -f3)
    local height=$(echo $pos_info | cut -d' ' -f4)
    
    debug_echo "Viser dropdown på workspace $current_ws"
    
    hyprctl dispatch movetoworkspacesilent "$current_ws,address:$addr"
    hyprctl dispatch resizewindowpixel "exact $width $height,address:$addr"
    hyprctl dispatch movewindowpixel "exact $x $y,address:$addr"
    hyprctl dispatch pin "address:$addr"
    hyprctl dispatch focuswindow "address:$addr"
}

# Skjul dropdown
hide_dropdown() {
    local addr=$(get_terminal_addr)
    
    debug_echo "Skjuler dropdown"
    
    hyprctl dispatch pin "address:$addr"
    hyprctl dispatch movetoworkspacesilent "special:scratchpad,address:$addr"
}

# Toggle fullscreen/normal
toggle_fullscreen() {
    local current_mode=$(get_current_mode)
    
    if [ "$current_mode" = "fullscreen" ]; then
        # Gå tilbake til normal størrelse
        debug_echo "Går tilbake til normal størrelse"
        WIDTH_PERCENT=$DEFAULT_WIDTH
        HEIGHT_PERCENT=$DEFAULT_HEIGHT
        X_PERCENT=$DEFAULT_X
        Y_PERCENT=$DEFAULT_Y
        set_mode "normal"
    else
        # Gå til fullskjerm
        debug_echo "Går til fullskjerm"
        WIDTH_PERCENT=$FULLSCREEN_WIDTH
        HEIGHT_PERCENT=$FULLSCREEN_HEIGHT
        X_PERCENT=$FULLSCREEN_X
        Y_PERCENT=$FULLSCREEN_Y
        set_mode "fullscreen"
    fi
    
    save_size_config
    
    # Oppdater vinduet hvis det er synlig
    if terminal_exists; then
        if terminal_visible; then
            local addr=$(get_terminal_addr)
            pos_info=$(calculate_position)
            local x=$(echo $pos_info | cut -d' ' -f1)
            local y=$(echo $pos_info | cut -d' ' -f2)
            local width=$(echo $pos_info | cut -d' ' -f3)
            local height=$(echo $pos_info | cut -d' ' -f4)
            
            hyprctl dispatch resizewindowpixel "exact $width $height,address:$addr"
            hyprctl dispatch movewindowpixel "exact $x $y,address:$addr"
        else
            # Hvis skjult, vis den i ny størrelse
            show_dropdown
        fi
    fi
}

# Reset session - DREPER alt og starter på nytt!
reset_session() {
    debug_echo "RESETTER tmux - dreper session og lukker terminal"
    
    # Drep tmux-sesjonen
    if tmux_session_exists; then
        tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
        debug_echo "Tmux-sesjon drept"
    fi
    
    # Lukk terminal
    if terminal_exists; then
        local addr=$(get_terminal_addr)
        hyprctl dispatch closewindow "address:$addr"
        rm -f "$ADDR_FILE"
        debug_echo "Terminal lukket"
    fi
    
    # Reset størrelse til default
    WIDTH_PERCENT=$DEFAULT_WIDTH
    HEIGHT_PERCENT=$DEFAULT_HEIGHT
    X_PERCENT=$DEFAULT_X
    Y_PERCENT=$DEFAULT_Y
    set_mode "normal"
    save_size_config
    
    echo "✓ Tmux-sesjon RESET!"
    echo "✓ Alle SSH-sesjoner LUKKET!"
    echo "✓ Størrelse tilbakestilt til ${DEFAULT_WIDTH}%"
    echo ""
    echo "Trykk SUPER+ALT+RETURN for å starte på nytt"
}

# Main logic
main() {
    load_size_config
    
    case "$ACTION" in
        full|fullscreen|f)
            toggle_fullscreen
            ;;
        reset|r)
            reset_session
            ;;
        toggle|*)
            # Sjekk om terminal finnes
            if ! terminal_exists; then
                debug_echo "Ingen terminal funnet, spawner ny"
                spawn_dropdown
                sleep 0.2
                show_dropdown
                exit 0
            fi
            
            # Terminal finnes - toggle synlighet
            if terminal_visible; then
                hide_dropdown
            else
                # Sørg for at tmux-sesjon finnes
                if ! tmux_session_exists; then
                    debug_echo "Tmux-sesjon finnes ikke lenger, spawner ny"
                    rm -f "$ADDR_FILE"
                    spawn_dropdown
                    sleep 0.2
                fi
                show_dropdown
            fi
            ;;
    esac
}

main
