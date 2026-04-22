#!/usr/bin/env bash

log() {
    local level=$1; shift
    echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') [$level] $*" >&2
}

send_notification() {
    local url=$1
    if [[ -n "$url" ]]; then
        log "INFO" "Sending heartbeat to $url"
        curl -fsS -m 10 --retry 5 "$url" >/dev/null 2>&1 || log "WARN" "Heartbeat failed"
    fi
}