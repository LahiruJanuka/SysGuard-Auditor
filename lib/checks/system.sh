#!/usr/bin/env bash

# Uptime and load average check.

format_uptime() {
    local s=$1
    local d=$((s / 86400)) h=$(((s % 86400) / 3600)) m=$(((s % 3600) / 60))
    local out="up"
    [[ $d -gt 0 ]] && out="$out $d days,"
    [[ $h -gt 0 ]] && out="$out $h hours,"
    echo "$out $m minutes"
}

get_uptime() {
    if [[ -r /proc/uptime ]]; then
        format_uptime "$(awk '{print int($1)}' /proc/uptime)"
    else
        echo "N/A"
    fi
}

get_load_average() {
    if [[ -r /proc/loadavg ]]; then
        awk '{print $1", "$2", "$3}' /proc/loadavg
    else
        echo "N/A"
    fi
}

# Load is informative and does not affect OVERALL.
check_system() {
    echo "=== System Uptime & Load ==="
    echo "Uptime: $(get_uptime)"
    echo "Load Average (1,5,15 min): $(get_load_average)"
    echo ""
}
