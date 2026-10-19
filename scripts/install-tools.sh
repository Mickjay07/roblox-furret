#!/usr/bin/env bash
# Downloads the pinned toolchain straight from GitHub releases into ~/.local/bin.
# Used by CI, cloud sessions and local machines; `rokit install` is an alternative locally.
# Idempotent: tools already at the pinned version and built for this machine are skipped,
# while wrong-platform binaries (for example Linux ELF files on a Mac) are replaced.
#
# Supported: macOS arm64 (Apple Silicon), macOS x86_64, Linux x86_64, Linux arm64.
# Where a tool has no prebuilt release for the platform (selene on Intel macOS; rojo and
# selene on Linux arm64) it is built with `cargo install` if Rust is installed.
#
#   scripts/install-tools.sh            install / repair the toolchain
#   scripts/install-tools.sh --dry-run  print the release URLs for this platform and exit
#                                       (TOOLS_OS=Darwin|Linux TOOLS_ARCH=arm64|x86_64
#                                       override detection in this mode only)
#
# Must stay compatible with macOS's bash 3.2: no associative arrays, no ${x,,}.
set -euo pipefail

ROJO=7.4.4
STYLUA=0.20.0
SELENE=0.27.1
LUNE=0.8.9
LUAU_LSP=1.70.1

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

die() {
	echo "ERROR: $*" >&2
	exit 1
}

# --- Platform detection --------------------------------------------------------------
if [ "$DRY_RUN" = 1 ]; then
	RAW_OS=${TOOLS_OS:-$(uname -s)}
	RAW_ARCH=${TOOLS_ARCH:-$(uname -m)}
else
	RAW_OS=$(uname -s)
	RAW_ARCH=$(uname -m)
fi
case "$RAW_OS" in
Darwin | macos) OS=macos ;;
Linux | linux) OS=linux ;;
*) die "unsupported OS '$RAW_OS' (supported: macOS, Linux)" ;;
esac
case "$RAW_ARCH" in
x86_64 | amd64) ARCH=x86_64 ;;
arm64 | aarch64) ARCH=aarch64 ;;
*) die "unsupported CPU architecture '$RAW_ARCH' (supported: x86_64, arm64)" ;;
esac
# A shell running under Rosetta reports x86_64 on Apple Silicon; install native arm64 tools.
if [ "$OS" = macos ] && [ "$ARCH" = x86_64 ] && [ -z "${TOOLS_ARCH:-}" ] &&
	[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then
	echo "NOTE: shell is running under Rosetta; installing native Apple Silicon (arm64) tools"
	ARCH=aarch64
fi
PLATFORM="$OS-$ARCH"
echo "Platform: $PLATFORM"

# --- Release artifacts -----------------------------------------------------------------
# Prints the release URL for a tool on $PLATFORM, or nothing when no prebuilt binary exists.
# Asset names differ per project; each one below was checked against the pinned release.
GH=https://github.com
asset_url() {
	case "$1:$PLATFORM" in
	rojo:linux-x86_64) echo "$GH/rojo-rbx/rojo/releases/download/v$ROJO/rojo-$ROJO-linux-x86_64.zip" ;;
	rojo:macos-x86_64) echo "$GH/rojo-rbx/rojo/releases/download/v$ROJO/rojo-$ROJO-macos-x86_64.zip" ;;
	rojo:macos-aarch64) echo "$GH/rojo-rbx/rojo/releases/download/v$ROJO/rojo-$ROJO-macos-aarch64.zip" ;;
	stylua:*) echo "$GH/JohnnyMorganz/StyLua/releases/download/v$STYLUA/stylua-$PLATFORM.zip" ;;
	# selene publishes one build per OS: linux = x86_64, macos = arm64 only.
	selene:linux-x86_64) echo "$GH/Kampfkarren/selene/releases/download/$SELENE/selene-$SELENE-linux.zip" ;;
	selene:macos-aarch64) echo "$GH/Kampfkarren/selene/releases/download/$SELENE/selene-$SELENE-macos.zip" ;;
	lune:*) echo "$GH/lune-org/lune/releases/download/v$LUNE/lune-$LUNE-$PLATFORM.zip" ;;
	luau-lsp:linux-x86_64) echo "$GH/JohnnyMorganz/luau-lsp/releases/download/$LUAU_LSP/luau-lsp-linux-x86_64.zip" ;;
	luau-lsp:linux-aarch64) echo "$GH/JohnnyMorganz/luau-lsp/releases/download/$LUAU_LSP/luau-lsp-linux-arm64.zip" ;;
	# Universal (x86_64 + arm64) binary.
	luau-lsp:macos-*) echo "$GH/JohnnyMorganz/luau-lsp/releases/download/$LUAU_LSP/luau-lsp-macos.zip" ;;
	esac
}

if [ "$DRY_RUN" = 1 ]; then
	for spec in "rojo $ROJO" "stylua $STYLUA" "selene $SELENE" "lune $LUNE" "luau-lsp $LUAU_LSP"; do
		set -- $spec
		url=$(asset_url "$1")
		echo "$1 $2: ${url:-<no prebuilt release; built with cargo>}"
	done
	exit 0
fi

BIN="${TOOLS_BIN:-$HOME/.local/bin}"
mkdir -p "$BIN"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Binary verification -----------------------------------------------------------------
# Succeeds when the file is an executable built for $PLATFORM (universal Mach-O included).
is_native_binary() {
	local path=$1 info magic
	[ -f "$path" ] || return 1
	if command -v file >/dev/null 2>&1; then
		info=$(file -b "$path")
		case "$PLATFORM" in
		macos-aarch64) grep -q "Mach-O" <<<"$info" && grep -q "arm64" <<<"$info" ;;
		macos-x86_64) grep -q "Mach-O" <<<"$info" && grep -q "x86_64" <<<"$info" ;;
		linux-x86_64) grep -q "ELF 64-bit" <<<"$info" && grep -q "x86-64" <<<"$info" ;;
		linux-aarch64) grep -q "ELF 64-bit" <<<"$info" && grep -q "aarch64" <<<"$info" ;;
		*) return 1 ;;
		esac
		return
	fi
	# No `file` command: check the container format from the magic bytes; the
	# --version smoke test below then proves the architecture.
	magic=$(od -An -tx1 -N4 "$path" | tr -d ' \n')
	case "$OS:$magic" in
	linux:7f454c46) return 0 ;;
	macos:cffaedfe | macos:cafebabe) return 0 ;;
	*) return 1 ;;
	esac
}

describe_binary() {
	if command -v file >/dev/null 2>&1; then file -b "$1"; else echo "(file command unavailable)"; fi
}

# Succeeds when the binary runs here and reports the expected version.
reports_version() { # path version
	local out
	# Capture first: with pipefail, `grep -q` closing the pipe early could fail the check.
	out=$("$1" --version 2>&1) || return 1
	grep -qF "$2" <<<"$out"
}

# --- Installation ------------------------------------------------------------------------------
# Puts a candidate binary for $name at $TMP/candidate-$name. Returns non-zero on failure.
fetch_prebuilt() { # name url
	local name=$1 url=$2 found
	curl -sSfL -o "$TMP/$name.zip" "$url" || return 1
	rm -rf "${TMP:?}/$name"
	unzip -oq "$TMP/$name.zip" -d "$TMP/$name" || return 1
	found=$(find "$TMP/$name" -type f -name "$name" | head -1)
	[ -n "$found" ] || {
		echo "  archive did not contain a '$name' binary" >&2
		return 1
	}
	mv "$found" "$TMP/candidate-$name"
}

build_with_cargo() { # name version
	local name=$1 version=$2
	if ! command -v cargo >/dev/null 2>&1; then
		echo "  $name $version has no prebuilt release for $PLATFORM. Install Rust" >&2
		echo "  (https://rustup.rs) and re-run this script to build it with cargo." >&2
		return 1
	fi
	echo "  no prebuilt release for $PLATFORM; building with cargo (takes a few minutes)"
	cargo install --locked --quiet --version "$version" --root "$TMP/cargo-$name" "$name" || return 1
	mv "$TMP/cargo-$name/bin/$name" "$TMP/candidate-$name"
}

install_tool() { # name version
	local name=$1 version=$2 url candidate
	local target="$BIN/$name"
	if is_native_binary "$target" && reports_version "$target" "$version"; then
		echo "$name $version already installed"
		return 0
	fi
	if [ -e "$target" ]; then
		echo "Replacing $target: $(describe_binary "$target" | cut -c1-70)"
	fi
	echo "Installing $name $version"

	url=$(asset_url "$name")
	if [ -n "$url" ]; then
		fetch_prebuilt "$name" "$url" || return 1
	else
		build_with_cargo "$name" "$version" || return 1
	fi
	candidate="$TMP/candidate-$name"

	chmod 755 "$candidate"
	# Downloads made by curl are not quarantined, but clear the flag in case of a proxy/tool
	# that adds it, so Gatekeeper doesn't block the binary.
	if [ "$OS" = macos ] && command -v xattr >/dev/null 2>&1; then
		xattr -d com.apple.quarantine "$candidate" 2>/dev/null || true
	fi
	if ! is_native_binary "$candidate"; then
		echo "  refusing to install: expected a $PLATFORM executable, got: $(describe_binary "$candidate")" >&2
		return 1
	fi
	if ! reports_version "$candidate" "$version"; then
		echo "  refusing to install: '$name --version' did not run or did not report $version:" >&2
		"$candidate" --version 2>&1 | head -3 | sed 's/^/    /' >&2 || true
		return 1
	fi
	install -m 755 "$candidate" "$target" || return 1
	echo "  installed $target ($(describe_binary "$target" | cut -c1-60))"
}

FAILED=""
for spec in "rojo $ROJO" "stylua $STYLUA" "selene $SELENE" "lune $LUNE" "luau-lsp $LUAU_LSP"; do
	set -- $spec
	if ! install_tool "$1" "$2"; then
		FAILED="$FAILED $1"
	fi
done

# Roblox API type definitions for `luau-lsp analyze`, pinned to the same luau-lsp release.
DEFS_DIR="$(cd "$(dirname "$0")/.." && pwd)/.cache"
mkdir -p "$DEFS_DIR"
DEFS="$DEFS_DIR/globalTypes-$LUAU_LSP.d.luau"
if [ ! -s "$DEFS" ]; then
	echo "Downloading Roblox type definitions"
	curl -sSfL -o "$DEFS.part" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP/scripts/globalTypes.d.luau"
	mv "$DEFS.part" "$DEFS"
fi

cp "$DEFS" "$DEFS_DIR/globalTypes.d.luau"

case ":$PATH:" in *":$BIN:"*) ;; *) echo "NOTE: add $BIN to PATH" ;; esac

if [ -n "$FAILED" ]; then
	die "could not install:$FAILED (see messages above)"
fi
echo "All tools installed for $PLATFORM."
