#!/bin/sh
set -eu

lock="/config/qBittorrent/lockfile"
logdir="/config/qBittorrent/logs"

# A lockfile left by an unclean stop blocks startup.
if [ -f "$lock" ]; then
    echo "Removing stale lockfile"
    rm -f "$lock"
fi

# Mirror the application log to stdout so the container log carries it.
mkdir -p "$logdir"
if [ ! -e "$logdir/qbittorrent.log" ]; then
    ln -s /proc/self/fd/1 "$logdir/qbittorrent.log"
fi

set -- --webui-port="${WEBUI_PORT:-8080}" "$@"
if [ -n "${TORRENTING_PORT:-}" ]; then
    set -- --torrenting-port="${TORRENTING_PORT}" "$@"
fi

exec /usr/bin/qbittorrent-nox "$@"
