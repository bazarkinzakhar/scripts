#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")
LOCK_DIR="/tmp/${SCRIPT_NAME}.lock"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# дефолтные переменные
BACKUP_SRC=""
BACKUP_DEST=""
RETENTION_DAYS=7
S3_BUCKET=""
PROM_METRICS_DIR=""
MIN_SPACE_KB=1048576

log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

usage() {
    cat <<EOF
Использование: $SCRIPT_NAME -s <source> -d <destination> [опции]

Обязательные:
  -s  источник
  -d  назначение

Опции:
  -r  дни хранения (дефолт: $RETENTION_DAYS)
  -b  s3 бакет
  -m  папка метрик node_exporter
  -h  справка
EOF
    exit 1
}

cleanup() {
    local exit_code=$?
    
    rm -rf "$LOCK_DIR"
    
    if [[ -n "$PROM_METRICS_DIR" && -d "$PROM_METRICS_DIR" ]]; then
        local metric_file="${PROM_METRICS_DIR}/backup_status.prom"
        local status=1
        [[ $exit_code -eq 0 ]] || status=0
        
        cat <<EOF > "${metric_file}.tmp"
# HELP backup_success Status of the last backup run
# TYPE backup_success gauge
backup_success{source="$BACKUP_SRC"} $status
# HELP backup_last_run_timestamp_seconds Timestamp
# TYPE backup_last_run_timestamp_seconds gauge
backup_last_run_timestamp_seconds{source="$BACKUP_SRC"} $(date +%s)
EOF
        mv "${metric_file}.tmp" "$metric_file"
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "скрипт упал с кодом $exit_code"
    fi
    exit "$exit_code"
}

check_dependencies() {
    local deps=("tar" "find" "df" "awk")
    [[ -n "$S3_BUCKET" ]] && deps+=("aws")
    
    for cmd in "${deps[@]}"; builtin command -v "$cmd" >/dev/null 2>&1 || {
        log "FATAL" "нет $cmd в PATH"
        exit 1
    }
}

main() {
    while getopts "s:d:r:b:m:h" opt; do
        case ${opt} in
            s ) BACKUP_SRC=$OPTARG ;;
            d ) BACKUP_DEST=$OPTARG ;;
            r ) RETENTION_DAYS=$OPTARG ;;
            b ) S3_BUCKET=$OPTARG ;;
            m ) PROM_METRICS_DIR=$OPTARG ;;
            h ) usage ;;
            * ) usage ;;
        esac
    done

    if [[ -z "$BACKUP_SRC" || -z "$BACKUP_DEST" ]]; then
        log "FATAL" "не заданы обязательные параметры"
        usage
    fi

    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log "FATAL" "бэкап уже запущен"
        exit 1
    fi
    trap cleanup EXIT

    check_dependencies

    if [[ ! -d "$BACKUP_SRC" ]]; then
        log "FATAL" "нет исходной директории $BACKUP_SRC"
        exit 1
    fi

    mkdir -p "$BACKUP_DEST"

    local available_kb
    available_kb=$(df -kP "$BACKUP_DEST" | awk 'NR==2 {print $4}')
    if [[ "$available_kb" -lt "$MIN_SPACE_KB" ]]; then
        log "FATAL" "мало места в $BACKUP_DEST ($available_kb KB)"
        exit 1
    fi

    local archive_path="$BACKUP_DEST/backup-${TIMESTAMP}.tar.gz"
    log "INFO" "начали бэкап: $BACKUP_SRC -> $archive_path"
    
    set +e
    tar -czf "$archive_path" -C "$(dirname "$BACKUP_SRC")" "$(basename "$BACKUP_SRC")"
    local tar_exit_code=$?
    set -e

    if [[ $tar_exit_code -eq 1 ]]; then
        log "WARN" "файлы изменились во время чтения, продолжаем"
    elif [[ $tar_exit_code -gt 1 ]]; then
        log "FATAL" "ошибка tar (код: $tar_exit_code)"
        rm -f "$archive_path"
        exit 1
    else
        log "INFO" "архив готов"
    fi

    if [[ -n "$BACKUP_DEST" && "$BACKUP_DEST" != "/" ]]; then
        log "INFO" "чистим архивы старше $RETENTION_DAYS дней"
        find "$BACKUP_DEST" -maxdepth 1 -type f -name "backup-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete
    else
        log "FATAL" "ошибка переменной пути, пропускаем ротацию"
        exit 1
    fi

    if [[ -n "$S3_BUCKET" ]]; then
        log "INFO" "заливаем в s3 $S3_BUCKET"
        if aws s3 cp "$archive_path" "${S3_BUCKET%/}/$(basename "$archive_path")" --quiet; then
            log "INFO" "залито"
        else
            log "ERROR" "ошибка загрузки в s3"
        fi
    fi

    log "INFO" "успешно завершено"
}

main "$@"