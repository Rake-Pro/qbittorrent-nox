#!/bin/sh
set -eu

umask "${UMASK:-022}"

lock="/config/qBittorrent/lockfile"
logdir="/config/qBittorrent/logs"

# Optional first-boot hooks: every executable file mounted at
# /custom-cont-init.d runs here, as this user, before qBittorrent starts
# (same mount path the previous image used, no root involved).
if [ -d /custom-cont-init.d ]; then
    for hook in /custom-cont-init.d/*; do
        [ -f "$hook" ] || continue
        echo "Running init hook: $hook"
        sh "$hook"
    done
fi

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
