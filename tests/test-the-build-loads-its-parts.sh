#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# build is the loop. builder/ holds the parts, one file to a subject, and a
# part nothing sources is a part that ships and never runs.
printf "Test group: build sources every part, and every part it sources is there\n"

for part in "$SDK"/builder/*.sh; do
  named="$(basename "$part")"
  grep --quiet --fixed-strings "builder/$named" "$SDK/build"
  assert "build sources $named" "$?" "it sits in builder/ and nothing loads it"
done

while read -r named; do
  [ -f "$SDK/builder/$named" ]
  assert "builder/$named is there" "$?" "build sources a file that does not exist"
done < <(grep --only-matching --extended-regexp 'builder/[a-z-]+\.sh' "$SDK/build" \
  | sed 's|^builder/||' | sort --unique)

printf "\nTest group: manifest.sh comes first, because the rest read what it sets\n"

first="$(grep --only-matching --extended-regexp 'builder/[a-z-]+\.sh' "$SDK/build" | head -1)"
[ "$first" = "builder/manifest.sh" ]
assert "it is sourced before the others" "$?" "the first one sourced is $first"

printf "\nTest group: the loop stays a loop\n"

# The whole point of the split. A build that grows a function back is a build
# on its way to being one file again.
defined="$(grep -cE '^[a-z_]+\(\) \{' "$SDK/build")"
[ "$defined" -le 1 ]
assert "build defines at most one function of its own" "$?" \
  "it defines $defined, which belong in builder/"

counted
