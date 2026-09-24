#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A plugin can name the oldest SDK that can build it. An older copy stops
# rather than writing folders by rules it has not got.
printf "Test group: a plugin that asks for more than this copy has is refused\n"

SDK_VERSION="$(jq --raw-output '.version' "$SDK/package.json")"

# The plugin under test, with whatever floor $1 names.
asking() {
  local floor="$1" copy="$WORK/asking"
  rm -rf "$copy"
  mkdir -p "$copy"
  tar --create --file - --exclude .git --directory "$PLUGIN" . | tar --extract --file - --directory "$copy"
  if [ -n "$floor" ]; then
    jq --tab --arg v "$floor" '.["ai-plugin-sdk"].version = $v' "$copy/plugin.json" > "$copy/next" \
      && mv "$copy/next" "$copy/plugin.json"
  else
    jq --tab 'del(.["ai-plugin-sdk"])' "$copy/plugin.json" > "$copy/next" \
      && mv "$copy/next" "$copy/plugin.json"
  fi
  printf '%s' "$copy"
}

built() { "$SDK/build" "$1" "$WORK/asked-out" "$WORK/asked.md" 2>"$WORK/asked-said"; }

built "$(asking 99.0.0)" >/dev/null
outcome="$?"
[ "$outcome" != "0" ]
assert "a floor above this copy stops the build" "$?" \
  "it built anyway, and exited $outcome"

grep --quiet --fixed-strings "99.0.0" "$WORK/asked-said"
assert "and says which version was asked for" "$?" "it said: $(cat "$WORK/asked-said")"

grep --quiet --fixed-strings "$SDK_VERSION" "$WORK/asked-said"
assert "and which one this is" "$?" "it said: $(cat "$WORK/asked-said")"

printf "\nTest group: any copy at or above the floor builds it\n"

for floor in "" 0.0.1 "$SDK_VERSION"; do
  built "$(asking "$floor")" >/dev/null
  assert "a floor of '${floor:-none}' builds" "$?" "it said: $(cat "$WORK/asked-said")"
done

printf "\nTest group: the install page records the copy that wrote it\n"

grep --quiet --fixed-strings "Built with ai-plugin-sdk $SDK_VERSION" "$INSTALL"
assert "the install page names the SDK that built it" "$?" \
  "nothing records which copy wrote the committed folders"

counted
