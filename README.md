# homelab-docker

набор докер configs для моей лабы

monitoring: prometheus + grafana + node_exporter, поднимается одной командой, собирает базовые метрики
web: nginx

как запускать:

- перейти в нужную папку
- docker-compose up -d

все настроено так, чтобы работать на стандартных портах

Configure env:
cp .env.example .env

Setup directories:
mkdir -p data/{traefik,prometheus,jellyfin}

Deploy:
docker compose up -d
