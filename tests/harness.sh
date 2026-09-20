#!/usr/bin/env bash

# Everything set here is read by the test files that source it, so nothing in
# this file can be seen being used from inside it.
# shellcheck disable=SC2034

# What every test needs: the SDK, a plugin to build, and that plugin built.
# A test takes the plugin directory as its first argument, so the same tests
# run against any plugin; with none, they run against the example.

SDK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$(cd "${1:-$SDK/example}" && pwd)"
MANIFEST="$PLUGIN/plugin.json"

NAME="$(jq --raw-output '.name' "$MANIFEST")"
VERSION="$(jq --raw-output '.version' "$MANIFEST")"
PREFIX="$(printf '%s' "$NAME" | tr '[:lower:]-' '[:upper:]_')"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BUILT="$WORK/distributions"
"$SDK/build" "$PLUGIN" "$BUILT" "$WORK/INSTALL.md" >/dev/null

pass=0
fail=0

assert() {
  local label="$1" outcome="$2" detail="$3"
  if [ "$outcome" = "0" ]; then
    printf "  PASS  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  FAIL  %s — %s\n" "$label" "$detail"
    fail=$((fail + 1))
  fi
}

counted() {
  printf "\n%d passed, %d failed\n" "$pass" "$fail"
  [ "$fail" -eq 0 ]
}

# Every distribution the build wrote for this plugin.
distributions() { for folder in "$BUILT"/*/; do basename "$folder"; done; }

# Every command a harness registers, as the path it runs.
commands_of() {
  jq --raw-output '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$1" \
    | sed -e 's/^bash "//' -e 's/"$//'
}
