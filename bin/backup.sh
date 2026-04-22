#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

BACKUP_SRC="${BACKUP_SRC:-$HOME/data}"
BACKUP_DEST="${BACKUP_DEST:-$HOME/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="$BACKUP_DEST/backup-$TIMESTAMP.tar.gz"
LOCK_FILE="/tmp/backup_infrastructure.lock"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$1] ${*:2}"
}

cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

main() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        log "ERROR" "Backup already running"
        exit 1
    fi

    if [[ ! -d "$BACKUP_SRC" ]]; then
        log "ERROR" "Source $BACKUP_SRC not found"
        exit 1
    fi

    mkdir -p "$BACKUP_DEST"

    local available_kb
    available_kb=$(df -k "$BACKUP_DEST" | awk 'NR==2 {print $4}')
    if [[ "$available_kb" -lt 1048576 ]]; then
        log "ERROR" "Low disk space"
        exit 1
    fi

    if tar -czf "$ARCHIVE" -C "$(dirname "$BACKUP_SRC")" "$(basename "$BACKUP_SRC")"; then
        log "INFO" "Backup created: $ARCHIVE"
    else
        log "ERROR" "Tar failed"
        exit 1
    fi

    find "$BACKUP_DEST" -type f -name "backup-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete
    log "INFO" "Rotation complete"
}

main "$@"
