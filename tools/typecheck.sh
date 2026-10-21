#!/usr/bin/env bash
# Type-checks src/ with luau-lsp and the Roblox type definitions.
# Needs: rojo, luau-lsp, and globalTypes.d.luau (see docs/DEVELOPMENT.md).
set -euo pipefail
cd "$(dirname "$0")/.."
DEFS="${ROBLOX_DEFS:-$HOME/tools/globalTypes.d.luau}"
rojo sourcemap default.project.json -o sourcemap.json >/dev/null
luau-lsp analyze --sourcemap=sourcemap.json --definitions="$DEFS" --ignore="**/ShotgunAnimData.luau" src 2>&1 \
  | grep -E "TypeError|SyntaxError" -A3 | sed "s#$(pwd)/##" || true
