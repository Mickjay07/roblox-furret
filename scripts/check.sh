#!/usr/bin/env bash
# Runs every check that works without Roblox Studio. Exit code is non-zero on any failure.
# Set SKIP_SELENE_IF_OFFLINE=1 to fall back to an approximate Roblox std when selene cannot
# fetch the Roblox API dump (cloud sessions whose network policy blocks roblox.com hosts).
set -euo pipefail
cd "$(dirname "$0")/.."
PATH="$HOME/.local/bin:$PATH"

# Fail early with a clear message when a tool is missing or built for another platform
# (for example Linux binaries on a Mac, which otherwise fail with "cannot execute binary file").
missing=""
for tool in stylua selene rojo luau-lsp lune; do
	if ! path=$(command -v "$tool"); then
		echo "MISSING: $tool is not on PATH" >&2
		missing="$missing $tool"
	elif ! "$path" --version >/dev/null 2>&1; then
		echo "BROKEN: $path does not run on this machine ($(uname -s) $(uname -m))" >&2
		command -v file >/dev/null 2>&1 && echo "        $(file -b "$path" | cut -c1-80)" >&2
		missing="$missing $tool"
	fi
done
if [ -n "$missing" ]; then
	echo "Run scripts/install-tools.sh to install or repair:$missing" >&2
	exit 1
fi

echo "==> stylua (format check)"
stylua --check src tests

echo "==> selene (lint)"
if ! out=$(selene src 2>&1); then
	echo "$out"
	if [ "${SKIP_SELENE_IF_OFFLINE:-0}" = "1" ] && grep -q "Could not collect standard library" <<<"$out"; then
		echo "WARNING: Roblox API dump unreachable; linting with the offline approximation"
		echo "         (scripts/selene-offline). Roblox API members are NOT checked."
		tmp="$(mktemp -d)"
		cp scripts/selene-offline/* "$tmp/"
		cp -r src "$tmp/src"
		(cd "$tmp" && selene src)
		rm -rf "$tmp"
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
