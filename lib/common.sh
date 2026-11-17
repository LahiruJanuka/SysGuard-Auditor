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

# Logging (stderr only; stdout is reserved for the report).
# Task 11 will add timestamps and file output.
log_info()  { echo "[INFO]  $*" >&2; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

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

# Validate a single threshold. Returns 1 and prints to stderr on failure.
validate_threshold() {
    local name=$1 value=$2

    if ! is_valid_int "$value"; then
        echo "Config error: $name='$value' is not a non-negative integer" >&2
        return 1
    fi
    if (( 10#$value > 100 )); then
        echo "Config error: $name=$value is out of range (must be 0-100)" >&2
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
        echo "Config error: CPU_WARN=$CPU_WARN > CPU_CRIT=$CPU_CRIT (WARN must be <= CRIT)" >&2
        failed=1
    fi
    if is_valid_int "$MEM_WARN" && is_valid_int "$MEM_CRIT" \
       && (( 10#$MEM_WARN > 10#$MEM_CRIT )); then
        echo "Config error: MEM_WARN=$MEM_WARN > MEM_CRIT=$MEM_CRIT (WARN must be <= CRIT)" >&2
        failed=1
    fi
    if is_valid_int "$DISK_WARN" && is_valid_int "$DISK_CRIT" \
       && (( 10#$DISK_WARN > 10#$DISK_CRIT )); then
        echo "Config error: DISK_WARN=$DISK_WARN > DISK_CRIT=$DISK_CRIT (WARN must be <= CRIT)" >&2
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
        (. /etc/os-release; echo "${PRETTY_NAME:-$NAME}")
    else
        echo "Linux (unknown distro)"
    fi
}

get_hostname() {
    if [[ -r /proc/sys/kernel/hostname ]]; then
        cat /proc/sys/kernel/hostname
    else
        hostname 2>/dev/null || echo "unknown"
    fi
}
