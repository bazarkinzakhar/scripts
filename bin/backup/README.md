# infrastructure-backup-tool

профессиональный инструмент для инкрементального резервного копирования с дедупликацией, шифрованием и мониторингом.

## особенности
* **restic engine:** использование современного движка вместо tar (инкрементальные копии, дедупликация)
* **модульная архитектура:** разделение логики на функции (валидация, работа, ротация, метрики)
* **атомарный лок:** защита от дублирования процессов через `mkdir`
* **safety:** строгий режим bash (pipefail) и проверка прав (UID check) для системных директорий
* **observability:** экспорт метрик в формате `.prom` для prometheus node_exporter
* **dry run:** режим тестирования без внесения изменений

## требования
* **os:** linux / macos
* **зависимости:** `restic`, `awk`, `df`
* **shellcheck:** для статического анализа кода

## использование и опции

### параметры запуска (cli)
| флаг | описание |
| :--- | :--- |
| `-s` | путь к исходным данным (source) |
| `-d` | путь к репозиторию бэкапов (destination) |
| `-r` | срок хранения ежедневных копий (days) |
| `-m` | путь для сохранения .prom метрик |
| `-n` | dry run (режим эмуляции) |
| `-h` | справка |

### переменные окружения и конфиг
скрипт приоритизирует переменные из окружения (удобно для CI/CD):
* `BACKUP_SRC` — источник бэкапа
* `BACKUP_DEST` — репозиторий
* `RESTIC_PASSWORD` — пароль шифрования (обязателен)
* `RETENTION_DAYS` — срок ротации (дефолт 7)
* `PROM_METRICS_DIR` — путь для метрик

### подготовка
* `chmod +x backup.sh` — права на запуск
* `export RESTIC_PASSWORD="your_password"` — установка ключа шифрования
* `aws configure` — если репозиторий находится в S3

## примеры команд
```bash
# локальный бэкап с ротацией 14 дней
./backup.sh -s /var/www/app -d /mnt/backup_drive/repo -r 14

# бэкап с выгрузкой в s3 и метриками
./backup.sh -s /data -d s3:[s3.amazonaws.com/bucket-name](https://s3.amazonaws.com/bucket-name) -m /var/lib/node_exporter/textfile_collector

# запуск в режиме тестирования
./backup.sh -s /etc -d /tmp/test_repo -n

## план восстановления
* 1. Просмотр доступных копий
Bash
restic -r /path/to/repo snapshots
* 2. Полное восстановление (последняя копия)
'''bash
restic -r /path/to/repo restore latest --target /tmp/recovery-folder
* 3. Монтирование для поиска файлов
'''bash
mkdir /mnt/restic
restic -r /path/to/repo mount /mnt/restic
