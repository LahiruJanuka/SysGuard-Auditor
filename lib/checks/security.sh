#!/usr/bin/env bash

# Failed-login check.

get_auth_source() {
    if [[ -f /var/log/auth.log ]]; then
        echo "/var/log/auth.log"
    elif [[ -f /var/log/secure ]]; then
        echo "/var/log/secure"
    elif have journalctl; then
        echo "journal"
    fi
}

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

check_security() {
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
    echo ""
}
