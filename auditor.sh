#!/usr/bin/env bash
 
# ======================================================
# SysGuard Auditor - System Health & Security Auditor
# ======================================================
# Linux only: works on any distribution (Fedora, RHEL/Rocky/Alma,
# Debian/Ubuntu, Arch, SUSE, Alpine) and on desktops or servers.
# Each collector uses the best method available and falls back to "N/A".
 
# Stop early on non-Linux systems
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "SysGuard Auditor supports Linux only (detected: $(uname -s))." >&2
    exit 1
fi
 
# Check whether a command exists
have() { command -v "$1" >/dev/null 2>&1; }

# Version
VERSION="0.2.0"

# ======================================================
# Configuration loading
# ======================================================
# Order of precedence (lowest to highest):
#   1. Built-in defaults below
#   2. Values set in the config file (sourced over the defaults)
#
# Environment-variable overrides (e.g. `CPU_WARN=50 ./auditor.sh`)
# are NOT honored yet -- the config file wins if both are set.

# Absolute directory of this script (resolves ./relative and symlinks best-effort)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Where to look for the config file:
#   1. $CONFIG_FILE if the caller exported it
#   2. <script_dir>/config/auditor.conf otherwise
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config/auditor.conf}"

# 1. Built-in defaults
CPU_WARN=70;  CPU_CRIT=85
MEM_WARN=75;  MEM_CRIT=90
DISK_WARN=80; DISK_CRIT=90

# 2. Config file overrides defaults (if it exists and is readable)
if [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    if ! source "$CONFIG_FILE"; then
        echo "Warning: failed to source config: $CONFIG_FILE" >&2
        echo "         Continuing with built-in defaults." >&2
    fi
fi

# Print usage information
usage() {
        cat <<EOF
SysGuard Auditor $VERSION - System Health & Security Auditor

Usage: $0 [OPTIONS]

Options:
    -h, --help     Show this help message and exit
    -V, --version  Show version information and exit

Thresholds (percent):
    CPU:  WARN >= ${CPU_WARN}%, CRIT >= ${CPU_CRIT}%
    MEM:  WARN >= ${MEM_WARN}%, CRIT >= ${MEM_CRIT}%
    DISK: WARN >= ${DISK_WARN}%, CRIT >= ${DISK_CRIT}%

Exit codes:
    0  All checks OK
    1  At least one WARN
    2  At least one CRIT
EOF
}

# Compare a value (e.g. "42" or "42%") with warn/crit limits
# Prints OK, WARN, CRIT, or N/A when the value is not a number
get_status() {
    local value=${1%\%} warn=$2 crit=$3
    [[ "$value" =~ ^[0-9]+$ ]] || { echo "N/A"; return; }
    if (( value >= crit )); then
        echo "CRIT"
    elif (( value >= warn )); then
        echo "WARN"
    else
        echo "OK"
    fi
}

# Overall result of the run: 0 = OK, 1 = WARN, 2 = CRIT (also the exit code)
OVERALL=0

# Raise OVERALL if the given status is worse than the current one
update_overall() {
    case "$1" in
        CRIT)
            OVERALL=2
            ;;
        WARN)
            if (( OVERALL < 1 )); then OVERALL=1; fi
            ;;
    esac
}
 
# Distribution name from /etc/os-release
get_distro() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        (. /etc/os-release; echo "${PRETTY_NAME:-$NAME}")
    else
        echo "Linux (unknown distro)"
    fi
}
 
# Hostname without depending on the 'hostname' command
get_hostname() {
    if [[ -r /proc/sys/kernel/hostname ]]; then
        cat /proc/sys/kernel/hostname
    else
        hostname 2>/dev/null || echo "unknown"
    fi
}
 
# Convert seconds to a readable uptime string
format_uptime() {
    local s=$1
    local d=$((s / 86400)) h=$(((s % 86400) / 3600)) m=$(((s % 3600) / 60))
    local out="up"
    [[ $d -gt 0 ]] && out="$out $d days,"
    [[ $h -gt 0 ]] && out="$out $h hours,"
    echo "$out $m minutes"
}
 
# Function to get system uptime
get_uptime() {
    if [[ -r /proc/uptime ]]; then
        format_uptime "$(awk '{print int($1)}' /proc/uptime)"
    else
        echo "N/A"
    fi
}
 
# Function to get load averages (1, 5, 15 minutes)
get_load_average() {
    if [[ -r /proc/loadavg ]]; then
        awk '{print $1", "$2", "$3}' /proc/loadavg
    else
        echo "N/A"
    fi
}
 
# Function to get CPU usage percentage
# Samples /proc/stat twice (independent of 'top' version and locale)
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
 
# Prints "<total_mb> <used_mb>" (used = total - available)
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
 
# Function to get total memory in MB
get_memory_total() {
    get_memory_stats | awk '{print $1}'
}
 
# Function to get used memory in MB
get_memory_used() {
    get_memory_stats | awk '{print $2}'
}
 
# Function to get memory usage percentage
get_memory_percent() {
    local total used
    read -r total used < <(get_memory_stats)
    if [[ "$total" -gt 0 ]]; then
        echo "$((100 * used / total))%"
    else
        echo "N/A"
    fi
}
 
# Root partition stats via POSIX df (-P avoids line wrapping)
# Prints "<total_kb> <used_kb> <free_kb> <percent>"
get_disk_stats() {
    df -Pk / | awk 'NR==2 {gsub("%","",$5); print $2, $3, $4, $5}'
}
 
# Convert KB to a human-readable string
human_kb() {
    awk -v k="$1" 'BEGIN {
        if (k >= 1048576) printf "%.1fG\n", k/1048576;
        else if (k >= 1024) printf "%.1fM\n", k/1024;
        else printf "%dK\n", k }'
}
 
# Function to get disk usage percentage for root partition
get_disk_usage_percent() {
    echo "$(get_disk_usage_int)%"
}
 
# Function to get total disk space for root partition
get_disk_total() {
    human_kb "$(get_disk_stats | awk '{print $1}')"
}
 
# Function to get free disk space for root partition
get_disk_free() {
    human_kb "$(get_disk_stats | awk '{print $3}')"
}
 
# Function to get disk usage percentage as integer (for threshold comparison)
get_disk_usage_int() {
    get_disk_stats | awk '{print $4}'
}
 
# Function to get listening ports (ss, or netstat on minimal systems)
get_open_ports() {
    if have ss; then
        ss -tuln | awk 'NR>1 {print $1, $5}' | sort -u
    elif have netstat; then
        netstat -tuln 2>/dev/null | awk '$1 ~ /^(tcp|udp)/ {print $1, $4}' | sort -u
    else
        echo "N/A (install iproute2 or net-tools)"
    fi
}
 
# Find the auth log source. Prints a file path, "journal", or nothing.
get_auth_source() {
    if [[ -f /var/log/auth.log ]]; then
        echo "/var/log/auth.log"      # Debian, Ubuntu
    elif [[ -f /var/log/secure ]]; then
        echo "/var/log/secure"        # Fedora, RHEL family
    elif have journalctl; then
        echo "journal"                # systemd-only systems (Arch, minimal servers)
    fi
}
 
# Function to get failed authentication attempts (single shared implementation)
# Matches SSH ("Failed password") and local PAM failures (sudo, su, display manager).
# "COMMAND=" lines are excluded so sudo's own audit entries don't inflate the count.
get_failed_logins() {
    local src
    src=$(get_auth_source)
 
    case "$src" in
        "")
            echo "N/A"
            ;;
        journal)
            journalctl -q --no-pager 2>/dev/null \
                | awk '/Failed password|authentication failure|password check failed/ && !/COMMAND=/{count++} END {print count+0}'
            ;;
        *)
            if [[ ! -r "$src" ]]; then
                echo "N/A"
                return
            fi
            awk '/Failed password|authentication failure|password check failed/ && !/COMMAND=/{count++} END {print count+0}' "$src" 2>/dev/null
            ;;
    esac
}

# Warn once if not root, since some checks need it
check_privileges() {
    if (( EUID != 0 )); then
        echo "Note: Running as non-root. Some checks (failed logins,"
        echo "      port owners) may be incomplete. Run with sudo for full results."
        echo ""
    fi
}
 
# Function to display disk information
display_disk_info() {
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
 
# Function to display system information
display_system_info() {
    echo "=== System Uptime & Load ==="
    echo "Uptime: $(get_uptime)"
    echo "Load Average (1,5,15 min): $(get_load_average)"
    echo ""
}
 
# Function to display CPU information
display_cpu_info() {
    local cpu status
    cpu=$(get_cpu_usage)
    status=$(get_status "$cpu" "$CPU_WARN" "$CPU_CRIT")
    update_overall "$status"
    echo "=== CPU Usage ==="
    echo "CPU Usage: $cpu [$status]"
    echo ""
}
 
# Function to display memory information
display_memory_info() {
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
 
# Function to display network information
display_network_info() {
    echo "=== Open Network Ports ==="
    get_open_ports
    echo ""
}
 
# Function to display security information
display_security_info() {
    local src
    src=$(get_auth_source)
 
    echo "=== Security Information ==="
    if [[ -z "$src" ]]; then
        echo "Authentication Log  : Not found"
    else
        echo "Authentication Log  : $src"
        if [[ "$src" != "journal" && ! -r "$src" ]]; then
            echo "Total Login Failures: N/A (run with sudo to read $src)"
        else
            echo "Total Login Failures: $(get_failed_logins)"
        fi
    fi
    echo
}

# Function to display the overall status
display_summary() {
    local label
    case "$OVERALL" in
        0) label="OK" ;;
        1) label="WARN" ;;
        *) label="CRIT" ;;
    esac
    echo "=== Overall Status ==="
    echo "Result: $label (exit code $OVERALL)"
    echo
}
 
main() {
    echo "============================================"
    echo "  SysGuard Auditor - System Health Report"
    echo "  Host: $(get_hostname)  |  $(get_distro)"
    echo "============================================"
    echo ""
    check_privileges
    display_system_info
    display_cpu_info
    display_memory_info
    display_disk_info
    display_network_info
    display_security_info
    display_summary
}
 
# Parse command-line arguments
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage
            exit 0
            ;;
        -V|--version)
            echo "SysGuard Auditor $VERSION"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            usage >&2
            exit 64
            ;;
    esac
done

# Run main function, then exit with the overall status (0 OK, 1 WARN, 2 CRIT)
main
exit "$OVERALL"
 