#!/usr/bin/env bash

set -Eeuo pipefail
LOCK_DIR="/tmp/backup_atomic.lock"

cleanup() {
    local exit_code=$?
    rm -rf "$LOCK_DIR"
    if [[ $exit_code -ne 0 ]]; then
        echo "Script failed with exit code $exit_code" >&2
    fi
}
trap cleanup EXIT INT TERM

source "$(dirname "$0")/utils.sh"

SOURCE_DIR=""
REPO_DIR=""
RETENTION=7
PROM_DIR=""
HC_URL=""
MIN_FREE_GB=2

usage() {
    echo "Usage: $0 -s <src> -d <dst> [-r <days>] [-m <prom_dir>] [-h <hc_url>]"
    exit 2
}

while getopts "s:d:r:m:h:" opt; do
    case ${opt} in
        s ) SOURCE_DIR=$OPTARG ;;
        d ) REPO_DIR=$OPTARG ;;
        r ) RETENTION=$OPTARG ;;
        m ) PROM_DIR=$OPTARG ;;
        h ) HC_URL=$OPTARG ;;
        * ) usage ;;
    esac
done

validate() {
    [[ -z "$SOURCE_DIR" || -z "$REPO_DIR" ]] && usage
    
    if [[ "$SOURCE_DIR" == "/etc" || "$SOURCE_DIR" == "/root" ]] && [[ "$EUID" -ne 0 ]]; then
        log "ERROR" "Root privileges required for $SOURCE_DIR"
        exit 3
    fi

    local free_kb
    free_kb=$(df -k "$(dirname "$REPO_DIR")" | awk 'NR==2 {print $4}')
    if [[ "$free_kb" -lt $((MIN_FREE_GB * 1024 * 1024)) ]]; then
        log "ERROR" "Not enough disk space. Min required: ${MIN_FREE_GB}GB"
        exit 4
    fi

    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log "ERROR" "Another instance is running"
        exit 5
    fi
}

run_backup() {
    log "INFO" "Starting backup of $SOURCE_DIR"

    if restic -r "$REPO_DIR" backup "$SOURCE_DIR" --quiet; then
        log "INFO" "Backup successful"
        restic -r "$REPO_DIR" forget --keep-daily "$RETENTION" --prune --quiet
        find "$REPO_DIR" -type f -exec chmod 600 {} + 2>/dev/null || true
        return 0
    else
        log "ERROR" "Backup failed"
        return 1
    fi
}

main() {
    validate
    
    if run_backup; then
        send_notification "$HC_URL"
        # Здесь могла бы быть логика метрик Prometheus
        exit 0
    else
        exit 1
    fi
}

main