#!/bin/bash
# hint-system.sh - Vis Hyprland keybindings og zsh aliases

MODE="${1:-all}"  # all, binds, aliases

get_keybinds() {
    hyprctl binds -j | jq -r '.[] | 
        "\(.modmask | 
            if . >= 64 then "SUPER+" else "" end +
            if (. % 64) >= 8 then "ALT+" else "" end +
            if (. % 8) >= 4 then "CTRL+" else "" end +
            if (. % 4) >= 1 then "SHIFT+" else "" end
        )\(.key): \(.description // .dispatcher) → \(.arg)"' | 
        sed 's/+:/:/g'
}

get_aliases() {
    zsh -ic 'alias' 2>/dev/null | while IFS='=' read -r name value; do
        echo "alias $name → ${value:0:60}"
    done
}

case "$MODE" in
    binds)   OUTPUT=$(get_keybinds) ;;
    aliases) OUTPUT=$(get_aliases) ;;
    all)     OUTPUT=$(echo "=== KEYBINDINGS ===" && get_keybinds && \
                      echo "" && echo "=== ALIASES ===" && get_aliases) ;;
esac

echo "$OUTPUT" | fuzzel --dmenu --width 60 --lines 25 \
    --prompt "🔍 Hints: " --layer overlay --anchor center
