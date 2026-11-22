#!/usr/bin/env bash
# Builds dist/ForeverCraftTimers-<version>.zip for friends: unzip into Interface/AddOns.
# Holds only what the game loads (toc, lua, Libs), not dev/tests/docs.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
version="$(git -C "$repo" describe --tags --always 2>/dev/null || echo dev)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/ForeverCraftTimers" "$repo/dist"
cp "$repo"/*.lua "$repo/ForeverCraftTimers.toc" "$repo/README.md" "$work/ForeverCraftTimers/"
cp -r "$repo/Libs" "$work/ForeverCraftTimers/"
out="$repo/dist/ForeverCraftTimers-$version.zip"
rm -f "$out"
(cd "$work" && zip -qr "$out" ForeverCraftTimers)
echo "$out"
