#!/usr/bin/env bash

# CPU usage check.

get_cpu_usage() {
    [[ -r /proc/stat ]] || { echo "N/A"; return; }
    local i1 t1 i2 t2
    read -r i1 t1 < <(awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print $5+$6, t}' /proc/stat)
    sleep 1
    read -r i2 t2 < <(awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print $5+$6, t}' /proc/stat)
    local dt=$((t2 - t1)) di=$((i2 - i1))
    if [[ $dt -gt 0 ]]; then
        echo "$((100 * (dt - di) / dt))%"
    else
        echo "N/A"
    fi
}

check_cpu() {
    local cpu status
    cpu=$(get_cpu_usage)
    status=$(get_status "$cpu" "$CPU_WARN" "$CPU_CRIT")
    update_overall "$status"
    echo "=== CPU Usage ==="
    echo "CPU Usage: $cpu [$status]"
    echo ""
}
