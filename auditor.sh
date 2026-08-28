#!/bin/bash

# ======================================================
# SysGuard Auditor - System Health & Security Auditor
# ======================================================
# This script will collect system statistics and detect
# potential issues. Currently a skeleton to be expanded.


# Function to get system uptime
get_uptime() {
    uptime -p
}

# Function to get load averages (1, 5, 15 minutes)
get_load_average() {
    cat /proc/loadavg | awk '{print $1", "$2", "$3}'
}

# Function to get CPU usage percentage
get_cpu_usage() {
    # top -bn1 runs once in batch mode
    # The line starting with "Cpu(s)" contains idle percentage in $8
    local idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
    # Convert to integer and compute usage
    local usage=$((100 - ${idle%.*}))
    echo "${usage}%"
}

# Function to display system infomation
display_system_info() {
    echo "=== System Uptime & Load ==="
    echo "Uptime: $(get_uptime)"
    echo "Load Average (1,5,15 min): $(get_load_average)"
    echo ""
    echo "=== CPU Usage ==="
    echo "CPU Usage: $(get_cpu_usage)"
    echo ""
}

main() {
    echo "======================================================"
    echo "       SysGuard Auditor - System Health Report"
    echo "======================================================"
    echo ""
    display_system_info
}

# Run main function
main
