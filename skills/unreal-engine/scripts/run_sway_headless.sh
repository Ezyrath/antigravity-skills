#!/usr/bin/env bash
# ====================================================================
# RUN_SWAY_HEADLESS.SH
# Launches an isolated headless Sway compositor with persistent wl-inject
# and executes any graphical command (UnrealEditor, etc.) without GUI popups.
# ====================================================================
set -euo pipefail

DISPLAY_NAME="${SWAY_HEADLESS_DISPLAY:-wayland-1}"
RESOLUTION="${SWAY_HEADLESS_RES:-1920x1080}"
CONF_FILE="/tmp/sway-headless-${DISPLAY_NAME}.conf"
FIFO_FILE="/tmp/wl-inject-${DISPLAY_NAME}.fifo"
LOG_DIR="/tmp/sway-headless-${DISPLAY_NAME}"

mkdir -p "$LOG_DIR"

cleanup() {
    echo "==> Cleaning up Sway headless (${DISPLAY_NAME})..."
    if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID" 2>/dev/null || true
    fi
    if [[ -n "${INJECT_PID:-}" ]] && kill -0 "$INJECT_PID" 2>/dev/null; then
        kill "$INJECT_PID" 2>/dev/null || true
    fi
    if [[ -n "${HOLDER_PID:-}" ]] && kill -0 "$HOLDER_PID" 2>/dev/null; then
        kill "$HOLDER_PID" 2>/dev/null || true
    fi
    if [[ -n "${SWAY_PID:-}" ]] && kill -0 "$SWAY_PID" 2>/dev/null; then
        kill "$SWAY_PID" 2>/dev/null || true
        wait "$SWAY_PID" 2>/dev/null || true
    fi
    rm -f "$FIFO_FILE" "$CONF_FILE"
    rm -f "${XDG_RUNTIME_DIR}/${DISPLAY_NAME}" "${XDG_RUNTIME_DIR}/${DISPLAY_NAME}.lock"
    echo "==> Sway headless cleanup complete."
}
trap cleanup EXIT INT TERM

# Clean stale sockets
rm -f "${XDG_RUNTIME_DIR}/${DISPLAY_NAME}" "${XDG_RUNTIME_DIR}/${DISPLAY_NAME}.lock" "$FIFO_FILE"

# 1. Generate Sway config
cat << EOF > "$CONF_FILE"
output HEADLESS-1 resolution ${RESOLUTION}
xwayland enable
seat * hide_cursor 1000
exec bash -c 'echo "\$DISPLAY" > "${LOG_DIR}/x11_display"'
EOF

echo "==> 1. Launching Sway Headless on ${DISPLAY_NAME} (${RESOLUTION})..."
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WAYLAND_DISPLAY="${DISPLAY_NAME}" sway -c "$CONF_FILE" > "${LOG_DIR}/sway.log" 2>&1 &
SWAY_PID=$!

# Wait for socket
for i in {1..20}; do
    if [[ -S "${XDG_RUNTIME_DIR}/${DISPLAY_NAME}" ]]; then
        break
    fi
    sleep 0.1
done

if [[ ! -S "${XDG_RUNTIME_DIR}/${DISPLAY_NAME}" ]]; then
    echo "ERROR: Sway failed to create socket ${XDG_RUNTIME_DIR}/${DISPLAY_NAME}" >&2
    exit 1
fi
echo "==> Sway Headless socket ready: ${XDG_RUNTIME_DIR}/${DISPLAY_NAME}"

# Wait for Xwayland DISPLAY file
X11_DISP=""
for i in {1..20}; do
    if [[ -f "${LOG_DIR}/x11_display" && -s "${LOG_DIR}/x11_display" ]]; then
        X11_DISP="$(cat "${LOG_DIR}/x11_display")"
        break
    fi
    sleep 0.1
done
if [[ -n "$X11_DISP" ]]; then
    echo "==> Sway Xwayland isolated display ready: ${X11_DISP}"
fi

# 2. Setup persistent wl-inject FIFO
mkfifo "$FIFO_FILE"
bash -c "exec 3>\"$FIFO_FILE\"; sleep 999999" >/dev/null 2>&1 &
HOLDER_PID=$!

WL_INJECT_BIN="${WL_INJECT_BIN:-}"
if [[ -z "$WL_INJECT_BIN" ]]; then
    if [[ -x "$HOME/.cargo/bin/wl-inject" ]]; then
        WL_INJECT_BIN="$HOME/.cargo/bin/wl-inject"
    elif [[ -x "$HOME/Documents/wl-inject/target/release/wl-inject" ]]; then
        WL_INJECT_BIN="$HOME/Documents/wl-inject/target/release/wl-inject"
    else
        WL_INJECT_BIN="$(which wl-inject 2>/dev/null || true)"
    fi
fi

if [[ -n "$WL_INJECT_BIN" && -x "$WL_INJECT_BIN" ]]; then
    echo "==> 2. Starting persistent wl-inject daemon from ${WL_INJECT_BIN}..."
    env WAYLAND_DISPLAY="${DISPLAY_NAME}" "$WL_INJECT_BIN" < "$FIFO_FILE" > "${LOG_DIR}/wl-inject.log" 2>&1 &
    INJECT_PID=$!
else
    echo "WARNING: wl-inject binary not found. Input injection will be unavailable."
    INJECT_PID=""
fi

# 3. Environment export helpers
ENV_FILE="${LOG_DIR}/env.sh"
cat << EOF > "$ENV_FILE"
export WAYLAND_DISPLAY="${DISPLAY_NAME}"
$(if [[ -n "$X11_DISP" ]]; then echo "export DISPLAY=\"${X11_DISP}\""; fi)
export FIFO_INJECT="${FIFO_FILE}"
inject() {
    echo "\$@" > "${FIFO_FILE}"
}
screenshot() {
    env WAYLAND_DISPLAY="${DISPLAY_NAME}" grim "\${1:-/tmp/screenshot.png}"
}
EOF
echo "==> Environment helper script written to: ${ENV_FILE}"
echo "    Source it with: source ${ENV_FILE}"

# 4. If command passed as argument, execute it
if [[ $# -gt 0 ]]; then
    echo "==> 3. Executing target app on ${DISPLAY_NAME} (X11: ${X11_DISP:-none}): $@"
    env WAYLAND_DISPLAY="${DISPLAY_NAME}" DISPLAY="${X11_DISP:-}" "$@" &
    APP_PID=$!
    wait "$APP_PID"
else
    echo "==> Headless session active. Press Ctrl+C or kill this process to stop."
    wait "$SWAY_PID"
fi
