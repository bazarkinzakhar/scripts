#!/bin/bash

mkdir -p data/prometheus data/grafana data/html data/jellyfin/config data/jellyfin/cache data/media
chmod -R 777 data/

echo "✅ Структура папок готова. Можно запускать docker compose up -d"
