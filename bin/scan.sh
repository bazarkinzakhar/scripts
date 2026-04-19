#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-127.0.0.1}
PORTS=${2:-"22 80 443"}
TIMEOUT=1

for PORT in $PORTS; do
  timeout $TIMEOUT bash -c "echo > /dev/tcp/$TARGET/$PORT" 2>/dev/null && echo "$PORT open" || echo "$PORT closed"
done
