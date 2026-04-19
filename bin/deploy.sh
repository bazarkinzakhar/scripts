#!/usr/bin/env bash

set -euo pipefail

readonly LOG_FILE="/tmp/deploy_$(date +%F).log"
readonly APP_DIR="${APP_DIR:-/opt/ml_app}"

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1" | tee -a "$LOG_FILE"
}

error_handler() {
    log "CRITICAL: Script failed at line $1"
    exit 1
}
trap 'error_handler $LINENO' ERR

check_deps() {
    for cmd in docker git python3; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR: $cmd is not installed."
            exit 1
        fi
    done
}

main() {
    log "Starting deployment process..."
    check_deps
    
    if [[ ! -d "$APP_DIR" ]]; then
        log "Creating directory $APP_DIR..."
        mkdir -p "$APP_DIR"
    fi

    log "Deployment finished successfully."
}

main "$@"
