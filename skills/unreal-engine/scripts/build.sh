#!/usr/bin/env bash
set -euo pipefail

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

PROJECT_DIR="$(dirname "$UPROJECT")"
PROJECT_NAME="$(basename "$UPROJECT" .uproject)"
TARGET="${PROJECT_NAME}Editor-Linux-Development"

echo "==> Project: $UPROJECT"
echo "==> Target:  $TARGET"

cd "$PROJECT_DIR"
if [[ -f "Makefile" ]]; then
  make "$TARGET"
else
  UNREAL_DIR="${UNREAL_INSTALL_DIR:-$HOME/.local/share/unreal-engine/16d75d84714512edfb744e1fd0a59e9c74d57873}"
  "$UNREAL_DIR/Engine/Build/BatchFiles/RunUBT.sh" "${PROJECT_NAME}Editor" Linux Development -Project="$UPROJECT"
fi

echo "==> Build succeeded!"
