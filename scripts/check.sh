#!/usr/bin/env bash
# Runs every check that works without Roblox Studio. Exit code is non-zero on any failure.
# Set SKIP_SELENE_IF_OFFLINE=1 to downgrade "selene cannot fetch the Roblox API dump" to a
# warning (needed in cloud sessions whose network policy blocks roblox.com hosts).
set -euo pipefail
cd "$(dirname "$0")/.."
PATH="$HOME/.local/bin:$PATH"

echo "==> stylua (format check)"
stylua --check src tests

echo "==> selene (lint)"
if ! out=$(selene src 2>&1); then
	echo "$out"
	if [ "${SKIP_SELENE_IF_OFFLINE:-0}" = "1" ] && grep -q "Could not collect standard library" <<<"$out"; then
		echo "WARNING: selene SKIPPED - Roblox API dump unreachable from this network."
	else
		exit 1
	fi
else
	echo "$out"
fi

echo "==> rojo build"
mkdir -p build
rojo build default.project.json -o build/FerretCardTycoon.rbxl
rojo sourcemap default.project.json -o sourcemap.json

echo "==> luau-lsp analyze (strict type check against Roblox API definitions)"
if [ ! -s .cache/globalTypes.d.luau ]; then
	echo "Missing .cache/globalTypes.d.luau - run scripts/install-tools.sh" >&2
	exit 1
fi
luau-lsp analyze --definitions=.cache/globalTypes.d.luau --sourcemap=sourcemap.json src

echo "==> lune tests (unit + built-place structure)"
lune run tests/run

echo "All checks passed."
