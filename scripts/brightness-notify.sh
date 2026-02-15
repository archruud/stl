#!/bin/bash
# Brightness notification script for dunst - oppdatert versjon
# Bruker brightnessctl for lysstyrke

get_brightness() {
    brightnessctl -m | cut -d',' -f4 | tr -d '%'
}

send_notification() {
    brightness=$(get_brightness)
    
    if [ "$brightness" -le 20 ]; then
        icon="display-brightness-low"
    elif [ "$brightness" -le 60 ]; then
        icon="display-brightness-medium"
    else
        icon="display-brightness-high"
    fi
    
    dunstify -a "changeBrightness" -u low -i "$icon" \
        -h string:x-canonical-private-synchronous:brightness \
        -h int:value:"$brightness" \
        "Brightness: ${brightness}%"
}

case $1 in
    up)
        brightnessctl set +5%
        send_notification
        ;;
    down)
        brightnessctl set 5%-
        send_notification
        ;;
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
esac
