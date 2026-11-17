#!/usr/bin/env bash

# lib/common.sh - SysGuard Auditor common helpers
# ==================================================
# Sourced by auditor.sh (and future scripts). Contains no top-level
# output and no main function. Safe to source anywhere that expects
# the functions below to become available.
#
# Contract:
#   - Functions mutate the global OVERALL via update_overall().
#   - die() exits the calling shell; never call it interactively.

# Global overall status: 0 = OK, 1 = WARN, 2 = CRIT.
# Preserve an existing status when the library is sourced again.
if [[ ${OVERALL+x} != x ]]; then
    OVERALL=0
fi

# Defaults keep individual check modules sourceable in isolation. The entry
# point assigns these values before loading the config file.
if [[ ${CPU_WARN+x} != x ]]; then CPU_WARN=70; fi
if [[ ${CPU_CRIT+x} != x ]]; then CPU_CRIT=85; fi
if [[ ${MEM_WARN+x} != x ]]; then MEM_WARN=75; fi
if [[ ${MEM_CRIT+x} != x ]]; then MEM_CRIT=90; fi
if [[ ${DISK_WARN+x} != x ]]; then DISK_WARN=80; fi
if [[ ${DISK_CRIT+x} != x ]]; then DISK_CRIT=90; fi

# True if the given command is on PATH.
have() { command -v "$1" >/dev/null 2>&1; }

# True if the argument is a non-negative integer with no sign, no
# decimal, no whitespace. "08" and "010" are valid (and handled via
# 10# at arithmetic time, not rejected here).
is_valid_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

# Print OK / WARN / CRIT / N/A for a value given warn and crit thresholds.
# 10# forces base-10 in arithmetic so "08" does not become a fatal octal
# error. Percent signs are stripped from the input.
get_status() {
    local value=${1%\%} warn=$2 crit=$3
    [[ "$value" =~ ^[0-9]+$ ]] || { echo "N/A"; return; }
    if (( 10#$value >= 10#$crit )); then
        echo "CRIT"
    elif (( 10#$value >= 10#$warn )); then
        echo "WARN"
    else
        echo "OK"
    fi
}

# Raise the global OVERALL to reflect the given status (CRIT > WARN > OK).
update_overall() {
    case "$1" in
        CRIT) OVERALL=2 ;;
        WARN) if (( OVERALL < 1 )); then OVERALL=1; fi ;;
    esac
}

# ------------------------------------------------------
# Logging
# ------------------------------------------------------
# LOG_FILE is set by the caller. If empty or unwritable, logging falls back
# to stderr-only.
LOG_FILE="${LOG_FILE:-}"
__LOG_FILE_READY=""

# Lazily create the log directory and file on first write.
__log_open() {
    if [[ -n "$__LOG_FILE_READY" ]]; then return; fi
    if [[ -z "$LOG_FILE" ]]; then
        __LOG_FILE_READY="no"
        return
    fi
    local dir is_new="no"
    dir=$(dirname -- "$LOG_FILE")
    if [[ ! -d "$dir" ]]; then
        mkdir -p -- "$dir" 2>/dev/null || { __LOG_FILE_READY="no"; return; }
    fi
    if [[ -e "$LOG_FILE" && ! -f "$LOG_FILE" ]]; then
        __LOG_FILE_READY="no"
        return
    fi
    [[ -e "$LOG_FILE" ]] || is_new="yes"
    if ! touch -- "$LOG_FILE" 2>/dev/null; then
        __LOG_FILE_READY="no"
        return
    fi
    if [[ "$is_new" == "yes" ]] && ! chmod 600 -- "$LOG_FILE" 2>/dev/null; then
        __LOG_FILE_READY="no"
        return
    fi
    __LOG_FILE_READY="yes"
}

# Write a timestamped event to stderr and, best-effort, the log file.
__log() {
    local level=$1
    shift
    local ts line
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    line="[$ts] [$level] $*"
    echo "$line" >&2
    __log_open
    if [[ "$__LOG_FILE_READY" == "yes" ]]; then
        if ! echo "$line" 2>/dev/null >> "$LOG_FILE"; then
            __LOG_FILE_READY="no"
        fi
    fi
}

log_info()  { __log INFO  "$@"; }
log_warn()  { __log WARN  "$@"; }
log_error() { __log ERROR "$@"; }

# Fatal error: log and exit. First arg may be an exit code.
#   die "message"        -> exit 1
#   die 65 "message"     -> exit 65
die() {
    local code=1
    if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
        code=$1
        shift
    fi
    log_error "$*"
    exit "$code"
}

# Validate a single threshold. Returns 1 and logs an error on failure.
validate_threshold() {
    local name=$1 value=$2

    if ! is_valid_int "$value"; then
        log_error "Config error: $name='$value' is not a non-negative integer"
        return 1
    fi
    if (( 10#$value > 100 )); then
        log_error "Config error: $name=$value is out of range (must be 0-100)"
        return 1
    fi
    return 0
}

# Validate all thresholds and WARN<=CRIT pairs. Exits 65 on failure.
# Pair checks run per-pair so users see all fixable errors in one pass.
validate_config() {
    local failed=0

    validate_threshold CPU_WARN  "$CPU_WARN"  || failed=1
    validate_threshold CPU_CRIT  "$CPU_CRIT"  || failed=1
    validate_threshold MEM_WARN  "$MEM_WARN"  || failed=1
    validate_threshold MEM_CRIT  "$MEM_CRIT"  || failed=1
    validate_threshold DISK_WARN "$DISK_WARN" || failed=1
    validate_threshold DISK_CRIT "$DISK_CRIT" || failed=1

    if is_valid_int "$CPU_WARN" && is_valid_int "$CPU_CRIT" \
       && (( 10#$CPU_WARN > 10#$CPU_CRIT )); then
        log_error "Config error: CPU_WARN=$CPU_WARN > CPU_CRIT=$CPU_CRIT (WARN must be <= CRIT)"
        failed=1
    fi
    if is_valid_int "$MEM_WARN" && is_valid_int "$MEM_CRIT" \
       && (( 10#$MEM_WARN > 10#$MEM_CRIT )); then
        log_error "Config error: MEM_WARN=$MEM_WARN > MEM_CRIT=$MEM_CRIT (WARN must be <= CRIT)"
        failed=1
    fi
    if is_valid_int "$DISK_WARN" && is_valid_int "$DISK_CRIT" \
       && (( 10#$DISK_WARN > 10#$DISK_CRIT )); then
        log_error "Config error: DISK_WARN=$DISK_WARN > DISK_CRIT=$DISK_CRIT (WARN must be <= CRIT)"
        failed=1
    fi

    if (( failed )); then
        die 65 "Invalid configuration; aborting. Fix the errors above and re-run."
    fi
}

# ------------------------------------------------------
# System identification used by the report header.
# ------------------------------------------------------

get_distro() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        (. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-${NAME:-Linux (unknown distro)}}") \
            || echo "Linux (unknown distro)"
    else
        echo "Linux (unknown distro)"
    fi
}

get_hostname() {
    if [[ -r /proc/sys/kernel/hostname ]]; then
        cat /proc/sys/kernel/hostname 2>/dev/null || echo "unknown"
    else
        hostname 2>/dev/null || echo "unknown"
    fi
}
