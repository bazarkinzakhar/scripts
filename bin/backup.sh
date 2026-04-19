#!/usr/bin/env bash
set -euo pipefail

BACKUP_SRC=${BACKUP_SRC:-/data}
BACKUP_DEST=${BACKUP_DEST:-/backup}
RETENTION_DAYS=${RETENTION_DAYS:-7}
LOCK_FILE=/var/lock/backup.lock
LOG_FILE=/var/log/backup.log

exec 200>$LOCK_FILE
flock -n 200 || exit 1

mkdir -p "$BACKUP_DEST"

AVAILABLE=$(df "$BACKUP_DEST" | awk 'NR==2 {print $4}')
if [ "$AVAILABLE" -lt 1048576 ]; then
  echo "not enough space" >> "$LOG_FILE"
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d%H%M%S)
ARCHIVE="$BACKUP_DEST/backup-$TIMESTAMP.tar.gz"

tar -czf "$ARCHIVE" "$BACKUP_SRC"

find "$BACKUP_DEST" -type f -name "backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "backup completed $TIMESTAMP" >> "$LOG_FILE"
