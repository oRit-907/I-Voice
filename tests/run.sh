#!/usr/bin/env bash
# Runs every check: Lua syntax, server logic, and the built NUI page.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

echo "== Lua syntax =="
# FiveM's backtick hash-string literals aren't valid stock Lua, so swap them for
# a number before handing each file to luac.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

while IFS= read -r file; do
	sed -E 's/`[A-Za-z_0-9]+`/0/g' "$file" > "$tmp/check.lua"
	if luac5.4 -p "$tmp/check.lua" 2>"$tmp/err"; then
		echo "  ok   $file"
	else
		echo "  FAIL $file"
		sed "s#$tmp/check.lua#$file#" "$tmp/err"
		status=1
	fi
done < <(find . -name '*.lua' -not -path './node_modules/*' -not -path './voice-ui/node_modules/*' | sort)

echo
echo "== JavaScript syntax =="
if node --check server/mute.js; then
	echo "  ok   server/mute.js"
else
	status=1
fi

echo
echo "== Server logic =="
lua5.4 tests/server-logic.lua || status=1

echo
echo "== pma-voice compat shim =="
lua5.4 tests/compat-shim.lua || status=1

echo
echo "== UI smoke =="
node tests/ui-smoke.mjs || status=1

exit $status
