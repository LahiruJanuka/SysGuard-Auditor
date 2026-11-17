#!/usr/bin/env bash

# Listening ports check.

get_open_ports() {
    if have ss; then
        ss -tuln | awk 'NR>1 {print $1, $5}' | sort -u
    elif have netstat; then
        netstat -tuln 2>/dev/null | awk '$1 ~ /^(tcp|udp)/ {print $1, $4}' | sort -u
    else
        echo "N/A (install iproute2 or net-tools)"
    fi
}

check_network() {
    echo "=== Open Network Ports ==="
    get_open_ports
    echo ""
}
