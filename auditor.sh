#!/usr/bin/env bash

# ======================================================
# SysGuard Auditor - System Health & Security Auditor
# ======================================================
# Linux only: works on any distribution and on desktops or servers.
# Each collector uses the best method available and falls back to "N/A".

# Stop early on non-Linux systems.
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "SysGuard Auditor supports Linux only (detected: $(uname -s))." >&2
    exit 1
fi

# Locate this script's directory.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Source shared helpers. Fail fast if the install is incomplete.
if [[ ! -r "$SCRIPT_DIR/lib/common.sh" ]]; then
    echo "Fatal: lib/common.sh not found in $SCRIPT_DIR/lib/" >&2
    echo "       Reinstall or run from the repository root." >&2
    exit 70
fi
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

VERSION="0.2.0"

# Configuration loading.
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config/auditor.conf}"

CPU_WARN=70;  CPU_CRIT=85
MEM_WARN=75;  MEM_CRIT=90
DISK_WARN=80; DISK_CRIT=90

if [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    if ! source "$CONFIG_FILE"; then
        echo "Warning: failed to source config: $CONFIG_FILE" >&2
        echo "         Continuing with built-in defaults." >&2
    fi
fi

validate_config

# Load modules in deterministic order. Checks run in the current shell so
# their updates to OVERALL are retained by the report summary.
CHECKS=(system cpu memory disk network security)

for __name in "${CHECKS[@]}"; do
    if [[ ! -r "$SCRIPT_DIR/lib/checks/$__name.sh" ]]; then
        die 70 "Missing check module: lib/checks/$__name.sh"
    fi
    # shellcheck source=/dev/null
    if ! source "$SCRIPT_DIR/lib/checks/$__name.sh"; then
        die 70 "Failed to load check module: lib/checks/$__name.sh"
    fi
done
unset __name

# Warn once if not root, since some checks need it.
check_privileges() {
    if (( EUID != 0 )); then
        echo "Note: Running as non-root. Some checks (failed logins,"
        echo "      port owners) may be incomplete. Run with sudo for full results."
        echo ""
    fi
}

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
    local __name

    echo "============================================"
    echo "  SysGuard Auditor - System Health Report"
    echo "  Host: $(get_hostname)  |  $(get_distro)"
    echo "============================================"
    echo ""

    check_privileges

    for __name in "${CHECKS[@]}"; do
        "check_$__name"
    done
    unset __name

    display_summary
}

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
  65 Invalid configuration (EX_DATAERR)
  70 Missing or broken check module (EX_SOFTWARE)
EOF
}

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

main
exit "$OVERALL"
