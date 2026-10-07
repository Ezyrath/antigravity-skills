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

UNREAL_DIR="${UNREAL_INSTALL_DIR:-$HOME/.local/share/unreal-engine/16d75d84714512edfb744e1fd0a59e9c74d57873}"
EDITOR_BIN="$UNREAL_DIR/Engine/Binaries/Linux/UnrealEditor"

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
