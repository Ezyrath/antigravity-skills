#!/usr/bin/env bash
set -euo pipefail

# Universal Bevy + WebAssembly Modding Workspace Validator
# Usage: ./validate_bevy_workspace.sh [project_root]

PROJECT_ROOT="${1:-$PWD}"
cd "$PROJECT_ROOT"

echo "==> [1/4] Building WebAssembly mods (if mods/ directory exists)..."
if [ -d "mods" ]; then
    mkdir -p assets/mods
    for mod_toml in mods/*/Cargo.toml; do
        if [ -f "$mod_toml" ]; then
            mod_name=$(grep -E '^name\s*=' "$mod_toml" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
            echo "    -> Compiling WASM mod: $mod_name"
            cargo build -p "$mod_name" --target wasm32-unknown-unknown --release
            wasm_file="target/wasm32-unknown-unknown/release/${mod_name}.wasm"
            if [ -f "$wasm_file" ]; then
                cp "$wasm_file" assets/mods/
                echo "    -> Installed assets/mods/${mod_name}.wasm ($(du -h "assets/mods/${mod_name}.wasm" | cut -f1))"
            fi
        fi
    done
fi

echo "==> [2/4] Running cargo check --workspace..."
cargo check --workspace

echo "==> [3/4] Running cargo test --workspace..."
cargo test --workspace

echo "==> [4/4] Running dedicated server headless smoke-test (if server binary exists)..."
SERVER_BIN=$(cargo metadata --no-deps --format-version 1 | grep -oE '"name":"[^"]*_server"' | head -n1 | cut -d'"' -f4 || true)
if [ -n "$SERVER_BIN" ]; then
    cargo run --bin "$SERVER_BIN" -- --smoke-test
fi

echo "✅ Bevy workspace validation succeeded!"
