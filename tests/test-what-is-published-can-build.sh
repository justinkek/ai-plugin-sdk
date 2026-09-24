#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# An install from npm gets the paths package.json lists and nothing else. Every
# other test runs the build out of a checkout, where everything is there, so
# this one packs the SDK the way npm would and builds from what came out.
printf "Test group: a packed copy holds everything the build reads\n"

packed="$WORK/packed"
mkdir -p "$packed"

# What the build reaches for, in both spellings it writes them.
reads() {
  grep --recursive --only-matching --extended-regexp '\$sdk"?/[a-zA-Z.-]+' \
    "$SDK/build" "$SDK/builder" | sed -e 's/^[^:]*://' -e 's/\$sdk"\?\///' | sort --unique
}

listed() { jq --raw-output '.files[]' "$SDK/package.json"; }

missing="$(comm -23 <(reads) <(listed | sort --unique))"
[ -z "$missing" ]
assert "package.json lists every path the build reads" "$?" \
  "an install from npm would have no $(printf '%s' "$missing" | tr '\n' ' ')"

[ "$(jq --raw-output '.bin["ai-plugin-sdk"]' "$SDK/package.json")" = "./build" ]
assert "and the command it installs is the build" "$?" "npx would run something else"

printf "\nTest group: and a build from that copy writes what a checkout writes\n"

# The files an install gets: what package.json lists, and nothing beside them.
while read -r path; do
  [ -e "$SDK/$path" ] || continue
  mkdir -p "$packed/$(dirname "$path")"
  cp -R "$SDK/$path" "$packed/$path"
done < <(listed)
cp "$SDK/package.json" "$packed/package.json"

"$packed/build" "$PLUGIN" "$WORK/from-packed" "$WORK/from-packed.md" >/dev/null 2>"$WORK/packed-said"
assert "the packed copy builds" "$?" "it said: $(cat "$WORK/packed-said")"

diff --recursive --unified "$BUILT" "$WORK/from-packed" > "$WORK/packed-drift"
assert "and writes the same folders" "$?" \
  "an install from npm would ship something a checkout does not: $(head -5 "$WORK/packed-drift")"

counted
