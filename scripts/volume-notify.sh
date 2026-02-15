#!/bin/bash
# Volume notification script for dunst - oppdatert versjon
# Bruker pamixer for volumkontroll

# Få nåværende volum og mute status
get_volume() {
    pamixer --get-volume
}

is_muted() {
    pamixer --get-mute
}

send_notification() {
    volume=$(get_volume)
    
    if [ "$(is_muted)" = "true" ]; then
        icon="audio-volume-muted"
        text="Muted"
        # Bruk progress bar value 0 for muted
        dunstify -a "changeVolume" -u low -i "$icon" \
            -h string:x-canonical-private-synchronous:volume \
            -h int:value:0 \
            "Volume: $text"
    else
        if [ "$volume" -le 30 ]; then
            icon="audio-volume-low"
        elif [ "$volume" -le 70 ]; then
            icon="audio-volume-medium"
        else
            icon="audio-volume-high"
        fi
        dunstify -a "changeVolume" -u low -i "$icon" \
            -h string:x-canonical-private-synchronous:volume \
            -h int:value:"$volume" \
            "Volume: ${volume}%"
    fi
}

case $1 in
    up)
        pamixer -i 5
        send_notification
        ;;
    down)
        pamixer -d 5
        send_notification
        ;;
    mute)
        pamixer -t
        send_notification
        ;;
    *)
        echo "Usage: $0 {up|down|mute}"
        exit 1
        ;;
esac
