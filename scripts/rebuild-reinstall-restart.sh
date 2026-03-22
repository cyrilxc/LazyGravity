#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-local}"
LOG_DIR="$HOME/.lazy-gravity"
BOT_LOG="$LOG_DIR/bot.log"
NPM_CACHE_DIR="/tmp/lazy-gravity-npm-cache"

mkdir -p "$LOG_DIR" "$NPM_CACHE_DIR"

cd "$ROOT_DIR"

echo "[refresh] root=$ROOT_DIR target=$TARGET"

stop_existing_bots() {
    local patterns=(
        "lazy-gravity-local start"
        "/bin/lazy-gravity-local"
        "/lib/node_modules/lazy-gravity-local/dist/bin/cli.js"
        "lazy-gravity start"
        "/bin/lazy-gravity"
        "/lib/node_modules/lazy-gravity/dist/bin/cli.js"
        "dist/bin/cli.js start"
        "ts-node src/bin/cli.ts"
    )

    local pids=()
    local pattern
    for pattern in "${patterns[@]}"; do
        while IFS= read -r pid; do
            [[ -n "$pid" ]] || continue
            pids+=("$pid")
        done < <(pgrep -f "$pattern" 2>/dev/null || true)
    done

    if [[ ${#pids[@]} -eq 0 ]]; then
        echo "[refresh] no existing bot process found"
        return
    fi

    local unique_pids=()
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        unique_pids+=("$pid")
    done < <(printf "%s\n" "${pids[@]}" | sort -u)
    echo "[refresh] stopping existing bot pids: ${unique_pids[*]}"
    kill "${unique_pids[@]}" 2>/dev/null || true

    local deadline=$((SECONDS + 10))
    while (( SECONDS < deadline )); do
        local remaining=()
        local pid
        for pid in "${unique_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                remaining+=("$pid")
            fi
        done
        if [[ ${#remaining[@]} -eq 0 ]]; then
            echo "[refresh] existing bot processes stopped"
            return
        fi
        sleep 1
    done

    echo "[refresh] force killing remaining bot pids: ${unique_pids[*]}"
    kill -9 "${unique_pids[@]}" 2>/dev/null || true
}

restart_bot() {
    local binary="$1"
    nohup "$binary" start >> "$BOT_LOG" 2>&1 &
    local pid=$!
    sleep 3
    echo "[refresh] restarted with $binary (pid=$pid)"
    ps -Ao pid,comm,args | rg "$binary start|dist/bin/cli.js start" || true
    echo "[refresh] recent log tail"
    tail -n 20 "$BOT_LOG" || true
}

case "$TARGET" in
    local)
        env npm_config_cache="$NPM_CACHE_DIR" npm run local:pack
        TARBALL="$(ls -1t lazy-gravity-local-*.tgz | head -n 1)"
        if [[ -z "$TARBALL" ]]; then
            echo "error: failed to locate lazy-gravity-local tarball" >&2
            exit 1
        fi
        echo "[refresh] installing $TARBALL"
        env npm_config_cache="$NPM_CACHE_DIR" npm install -g --force "$ROOT_DIR/$TARBALL"
        stop_existing_bots
        restart_bot "lazy-gravity-local"
        echo "[refresh] local rebuild/reinstall/restart complete: $TARBALL"
        ;;
    main)
        echo "[refresh] installing lazy-gravity@latest"
        env npm_config_cache="$NPM_CACHE_DIR" npm install -g --force lazy-gravity@latest
        stop_existing_bots
        restart_bot "lazy-gravity"
        echo "[refresh] main reinstall/restart complete"
        ;;
    *)
        echo "error: unsupported target '$TARGET' (use local or main)" >&2
        exit 1
        ;;
esac
