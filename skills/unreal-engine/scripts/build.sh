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

  "$UNREAL_INSTALL_DIR/Engine/Build/BatchFiles/RunUBT.sh" "${PROJECT_NAME}Editor" Linux Development -Project="$UPROJECT"
fi

echo "==> Build succeeded!"
