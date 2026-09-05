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

# Function to get total memory in MB
get_memory_total() {
    free -m | awk '/^Mem:/ {print $2}'
}

# Function to get used memory in MB
get_memory_used() {
    free -m | awk '/^Mem:/ {print $3}'
}

# Function to get memory usage percentage
get_memory_percent() {
    local total=$(get_memory_total)
    local used=$(get_memory_used)
    local percent=$((100 * used / total))
    echo "${percent}%"
}

# Function to get disk usage percentage for root partition
get_disk_usage_percent() {
    df -h / | awk 'NR==2 {print $5}'
}

# Function to get total disk space for root partition
get_disk_total() {
    df -h / | awk 'NR==2 {print $2}'
}

# Function to get free disk space for root partition
get_disk_free() {
    df -h / | awk 'NR==2 {print $4}'
}

# Function to get disk usage percentage as integer (for threshold comparison)
get_disk_usage_int() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to get listening ports
get_open_ports() {
    ss -tuln | awk 'NR>1 {print $1, $5}' | sort -u
}

# Function to display disk information
display_disk_info() {
    echo "=== Disk Usage (Root Partition) ==="
    echo "Total Space: $(get_disk_total)"
    echo "Used Space: $(get_disk_usage_percent)"
    echo "Free Space: $(get_disk_free)"
    echo ""
}

# Function to display system information
display_system_info() {
    echo "=== System Uptime & Load ==="
    echo "Uptime: $(get_uptime)"
    echo "Load Average (1,5,15 min): $(get_load_average)"
    echo ""
}

# Function to display CPU information
display_cpu_info() {
    echo "=== CPU Usage ==="
    echo "CPU Usage: $(get_cpu_usage)"
    echo ""
}

# Function to display memory information
display_memory_info() {
    echo "=== Memory Usage ==="
    echo "Total Memory: $(get_memory_total) MB"
    echo "Used Memory: $(get_memory_used) MB"
    echo "Memory Usage: $(get_memory_percent)"
    echo ""
}

# Function to display network information
display_network_info() {
    echo "=== Open Network Ports ==="
    echo "$(get_open_ports)"
    echo ""
}

main() {
    echo "============================================"
    echo "  SysGuard Auditor - System Health Report"
    echo "============================================"
    echo ""
    display_system_info
    display_cpu_info
    display_memory_info
    display_disk_info
    display_network_info
}

# Run main function
main
