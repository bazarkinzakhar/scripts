#!/usr/bin/env bash

set -Eeuo pipefail

# дефолты из окружения
SOURCE_DIR="${BACKUP_SRC:-}"
REPO_DIR="${BACKUP_DEST:-}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
PROM_DIR="${PROM_METRICS_DIR:-}"
MIN_FREE_GB=1
DRY_RUN=false
LOCK_DIR="/tmp/backup_restic_atomic.lock"

log() {
    local level=$1; shift
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
    if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
        echo "$msg" >&2
    else
        echo "$msg"
    fi
}

usage() {
    cat <<EOF
Usage: $0 [options]
Options:
  -s <path>  Source directory
  -d <path>  Destination repository
  -r <int>   Retention days (default: 7)
  -m <path>  Prometheus metrics directory
  -n         Dry run mode
EOF
    exit 1
}

cleanup() {
    local exit_code=$?
    rm -rf "$LOCK_DIR"
    [[ $exit_code -eq 0 ]] || log "ERROR" "script failed with exit code $exit_code"
}

check_dependencies() {
    local deps=(restic awk df)
    for tool in "${deps[@]}"; do
        command -v "$tool" >/dev/null 2>&1 || { log "FATAL" "$tool not installed"; exit 1; }
    done
}

validate_preflight() {
    [[ -z "$SOURCE_DIR" || -z "$REPO_DIR" ]] && usage
    
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log "FATAL" "lock directory $LOCK_DIR exists"
        exit 1
    fi
    trap cleanup EXIT

    if [[ "$SOURCE_DIR" == "/etc" || "$SOURCE_DIR" == "/var" ]] && [[ "$EUID" -ne 0 ]]; then
        log "FATAL" "root privileges required for system directories"
        exit 1
    fi

    local free_kb
    free_kb=$(df -k "$(dirname "$REPO_DIR")" | awk 'NR==2 {print $4}')
    if [[ "$free_kb" -lt $((MIN_FREE_GB * 1024 * 1024)) ]]; then
        log "FATAL" "less than ${MIN_FREE_GB}GB free space on destination"
        exit 1
    fi
}

backup_run() {
    local run_prefix=""
    $DRY_RUN && run_prefix="echo [DRY-RUN] "

    if ! restic -r "$REPO_DIR" snapshots >/dev/null 2>&1; then
        log "INFO" "initializing repository"
        $run_prefix restic -r "$REPO_DIR" init
    fi

    log "INFO" "starting backup"
    $run_prefix restic -r "$REPO_DIR" backup "$SOURCE_DIR" --verbose
}

backup_rotate() {
    local run_prefix=""
    $DRY_RUN && run_prefix="echo [DRY-RUN] "
    
    log "INFO" "rotating snapshots"
    $run_prefix restic -r "$REPO_DIR" forget --keep-daily "$RETENTION_DAYS" --prune
}

notify_metrics() {
    local status=$1
    [[ -z "$PROM_DIR" || ! -d "$PROM_DIR" ]] && return
    
    log "INFO" "exporting metrics"
    cat <<EOF > "${PROM_DIR}/backup_restic.prom.tmp"
backup_last_success_timestamp{repo="$REPO_DIR"} $(date +%s)
backup_status{repo="$REPO_DIR"} $status
EOF
    mv "${PROM_DIR}/backup_restic.prom.tmp" "${PROM_DIR}/backup_restic.prom"
}

main() {
    while getopts "s:d:r:m:nh" opt; do
        case ${opt} in
            s ) SOURCE_DIR=$OPTARG ;;
            d ) REPO_DIR=$OPTARG ;;
            r ) RETENTION_DAYS=$OPTARG ;;
            m ) PROM_DIR=$OPTARG ;;
            n ) DRY_RUN=true ;;
            h ) usage ;;
            * ) usage ;;
        esac
    done

    check_dependencies
    validate_preflight
    
    if backup_run && backup_rotate; then
        log "INFO" "all stages completed"
        notify_metrics 1
    else
        notify_metrics 0
        exit 1
    fi
}

main "$@"