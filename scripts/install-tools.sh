#!/usr/bin/env bash
# Downloads the pinned toolchain straight from GitHub releases into ~/.local/bin.
# Used by CI and cloud sessions; local developers can use `rokit install` instead.
# Idempotent: tools already at the pinned version are skipped.
set -euo pipefail

ROJO=7.4.4
STYLUA=0.20.0
SELENE=0.27.1
LUNE=0.8.9
LUAU_LSP=1.70.1

BIN="${TOOLS_BIN:-$HOME/.local/bin}"
mkdir -p "$BIN"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

install_tool() { # name version-substring url
	local name=$1 version=$2 url=$3
	if command -v "$BIN/$name" >/dev/null 2>&1 && "$BIN/$name" --version 2>&1 | grep -q "$version"; then
		echo "$name $version already installed"
		return
	fi
	echo "Installing $name $version"
	curl -sSfL -o "$TMP/$name.zip" "$url"
	unzip -oq "$TMP/$name.zip" -d "$TMP/$name"
	install -m 755 "$(find "$TMP/$name" -type f -name "$name" | head -1)" "$BIN/$name"
}

GH=https://github.com
install_tool rojo "$ROJO" "$GH/rojo-rbx/rojo/releases/download/v$ROJO/rojo-$ROJO-linux-x86_64.zip"
install_tool stylua "$STYLUA" "$GH/JohnnyMorganz/StyLua/releases/download/v$STYLUA/stylua-linux-x86_64.zip"
install_tool selene "$SELENE" "$GH/Kampfkarren/selene/releases/download/$SELENE/selene-$SELENE-linux.zip"
install_tool lune "$LUNE" "$GH/lune-org/lune/releases/download/v$LUNE/lune-$LUNE-linux-x86_64.zip"
install_tool luau-lsp "$LUAU_LSP" "$GH/JohnnyMorganz/luau-lsp/releases/download/$LUAU_LSP/luau-lsp-linux-x86_64.zip"

# Roblox API type definitions for `luau-lsp analyze`, pinned to the same luau-lsp release.
DEFS_DIR="$(cd "$(dirname "$0")/.." && pwd)/.cache"
mkdir -p "$DEFS_DIR"
DEFS="$DEFS_DIR/globalTypes-$LUAU_LSP.d.luau"
if [ ! -s "$DEFS" ]; then
	echo "Downloading Roblox type definitions"
	curl -sSfL -o "$DEFS" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP/scripts/globalTypes.d.luau"
fi

cp "$DEFS" "$DEFS_DIR/globalTypes.d.luau"

case ":$PATH:" in *":$BIN:"*) ;; *) echo "NOTE: add $BIN to PATH" ;; esac
