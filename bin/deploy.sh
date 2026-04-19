#!/usr/bin/env bash
set -euo pipefail

APP_DIR=${APP_DIR:-/opt/app}
REPO=${REPO:-https://github.com/example/app.git}
BRANCH=${BRANCH:-main}
LOG_FILE=/var/log/deploy.log

if [ ! -d "$APP_DIR/.git" ]; then
  git clone -b "$BRANCH" "$REPO" "$APP_DIR"
fi

cd "$APP_DIR"

git fetch origin
git reset --hard origin/$BRANCH

if [ -f package.json ]; then
  npm ci
  npm run build
fi

if [ -f docker-compose.yml ]; then
  docker compose pull
  docker compose up -d --remove-orphans
fi

echo "deploy completed $(date)" >> "$LOG_FILE"
