#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# Pi installs a plugin from its repository and loads only what package.json
# names under "pi". The build writes the extension and the skills, and cannot
# write package.json, so this holds the plugin to naming both.
MANIFEST="$PLUGIN/package.json"

printf "Test group: Pi is told where the extension and the skills are\n"

if [ ! -d "$BUILT/pi" ]; then
  printf "  SKIP  this plugin builds no Pi distribution\n\n"
  exit 0
fi

if [ ! -f "$MANIFEST" ]; then
  printf "  SKIP  %s has no package.json, so a Pi install of it loads nothing\n\n" "$(basename "$PLUGIN")"
  exit 0
fi

names() { jq --exit-status --arg part "$1" --arg path "$2" \
  '(.pi[$part] // []) | map(ltrimstr("./")) | index($path) != null' "$MANIFEST" >/dev/null; }

names extensions distributions/pi/src/index.ts
assert "package.json names the extension under pi.extensions" "$?" \
  "Pi runs none of this plugin's hooks"

if [ -d "$BUILT/pi/skills" ]; then
  names skills distributions/pi/skills
  assert "and the skills under pi.skills" "$?" \
    "Pi loads the extension and none of the skills beside it"
fi

counted
