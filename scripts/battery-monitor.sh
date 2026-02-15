#!/bin/bash
# Varsler når batteriet er lavt

varsel_vist=false

while true; do
    battery=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null)
    status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null)
    
    # Sjekk om vi er på batteri og lavt nivå
    if [[ $status == "Discharging" ]]; then
        if [[ $battery -le 15 ]] && [[ $varsel_vist == false ]]; then
            notify-send -u critical "⚠️ LAVT BATTERI!" "Bare ${battery}% igjen! Koble til lader!" -a "Batteri" -t 10000
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null
            varsel_vist=true
        elif [[ $battery -le 10 ]]; then
            notify-send -u critical "🔴 KRITISK LAVT!" "${battery}% - Lagre arbeidet ditt NÅ!" -a "Batteri" -t 10000
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null
        fi
    else
        varsel_vist=false
    fi
    
    sleep 120
done
