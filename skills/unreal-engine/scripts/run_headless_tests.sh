#!/usr/bin/env bash
set -euo pipefail

FILTER="${1:-}"

# Find the nearest .uproject in current or parent directories
DIR="$PWD"
UPROJECT=""
while [[ "$DIR" != "/" ]]; do
  MATCH=$(find "$DIR" -maxdepth 1 -name "*.uproject" | head -n 1)
  if [[ -n "$MATCH" ]]; then
    UPROJECT="$MATCH"
    break
  fi
  DIR="$(dirname "$DIR")"
done

if [[ -z "$UPROJECT" ]]; then
  echo "Error: No .uproject file found in $PWD or any parent directory." >&2
  exit 1
fi

if [[ -z "${UNREAL_INSTALL_DIR:-}" ]]; then
  if [[ -d "$HOME/.local/share/unreal-engine" ]]; then
    UNREAL_INSTALL_DIR="$(find "$HOME/.local/share/unreal-engine" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -n 1)"
  elif [[ -d "/opt/unreal-engine" ]]; then
    UNREAL_INSTALL_DIR="/opt/unreal-engine"
  fi
fi

if [[ -z "${UNREAL_INSTALL_DIR:-}" || ! -d "$UNREAL_INSTALL_DIR" ]]; then
  echo "Error: Unreal Engine install directory not found. Please set UNREAL_INSTALL_DIR." >&2
  exit 1
fi

EDITOR_BIN="$UNREAL_INSTALL_DIR/Engine/Binaries/Linux/UnrealEditor"

if [[ ! -f "$EDITOR_BIN" ]]; then
  echo "Error: UnrealEditor binary not found at $EDITOR_BIN" >&2
  exit 1
fi

EXEC_CMD="Automation RunTests ${FILTER}; Quit"
if [[ -z "$FILTER" ]]; then
  EXEC_CMD="Automation RunAll; Quit"
fi

echo "==> Project: $UPROJECT"
echo "==> Exec:    $EXEC_CMD"

"$EDITOR_BIN" "$UPROJECT" \
  -ExecCmds="$EXEC_CMD" \
  -unattended -nopause -testexit="Automation Test Queue Empty" \
  -log -log=Automation.log -nullrhi -nosplash

echo "==> Automation tests passed with EXIT CODE: 0"
