#!/usr/bin/env bash

# Root partition usage check.

get_disk_stats() {
    df -Pk / | awk 'NR==2 {gsub("%","",$5); print $2, $3, $4, $5}'
}

human_kb() {
    awk -v k="$1" 'BEGIN {
        if (k >= 1048576) printf "%.1fG\n", k/1048576;
        else if (k >= 1024) printf "%.1fM\n", k/1024;
        else printf "%dK\n", k }'
}

get_disk_usage_int() { get_disk_stats | awk '{print $4}'; }
get_disk_usage_percent() { echo "$(get_disk_usage_int)%"; }
get_disk_total() { human_kb "$(get_disk_stats | awk '{print $1}')"; }
get_disk_free() { human_kb "$(get_disk_stats | awk '{print $3}')"; }

check_disk() {
    local used status
    used=$(get_disk_usage_percent)
    status=$(get_status "$used" "$DISK_WARN" "$DISK_CRIT")
    update_overall "$status"
    echo "=== Disk Usage (Root Partition) ==="
    echo "Total Space: $(get_disk_total)"
    echo "Used Space: $used [$status]"
    echo "Free Space: $(get_disk_free)"
    echo ""
}
