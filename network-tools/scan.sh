#!/bin/bash
target=$1
shift
ports=("$@")

if [ -z "$target" ] || [ ${#ports[@]} -eq 0 ]; then
    echo "usage: $0 [host] [port1] [port2] ..."
    exit 1
fi

echo "scanning $target..."
for port in "${ports[@]}"; do
    if nc -zv -w 2 "$target" "$port" >/dev/null 2>&1; then
        echo "[+] $port: open"
    else
        echo "[-] $port: closed"
    fi
done
