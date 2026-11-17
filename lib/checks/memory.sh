#!/usr/bin/env bash

# Memory usage check.

get_memory_stats() {
    if [[ -r /proc/meminfo ]]; then
        awk '/^MemTotal:/ {t=$2}
             /^MemAvailable:/ {a=$2; has=1}
             /^MemFree:/ {f=$2}
             /^Buffers:/ {b=$2}
             /^Cached:/ {c=$2}
             END {if (!has) a=f+b+c; printf "%d %d\n", t/1024, (t-a)/1024}' /proc/meminfo
    else
        echo "0 0"
    fi
}

get_memory_total() { get_memory_stats | awk '{print $1}'; }
get_memory_used() { get_memory_stats | awk '{print $2}'; }

get_memory_percent() {
    local total used
    read -r total used < <(get_memory_stats)
    if [[ "$total" -gt 0 ]]; then
        echo "$((100 * used / total))%"
    else
        echo "N/A"
    fi
}

check_memory() {
    local mem status
    mem=$(get_memory_percent)
    status=$(get_status "$mem" "$MEM_WARN" "$MEM_CRIT")
    update_overall "$status"
    echo "=== Memory Usage ==="
    echo "Total Memory: $(get_memory_total) MB"
    echo "Used Memory: $(get_memory_used) MB"
    echo "Memory Usage: $mem [$status]"
    echo ""
}
