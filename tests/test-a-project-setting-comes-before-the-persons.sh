#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A project commits its own settings, so everyone working in it is held to the
# same values. A person's local file for the project wins over it, their own
# file still stands where neither says anything, and the environment wins over
# all three.
printf "Test group: a setting is read from the nearest file that holds it\n"

DISTRIBUTION="$(distributions | head -1)"
LIB="$BUILT/$DISTRIBUTION/hooks/lib/settings.sh"
WRITER="$BUILT/$DISTRIBUTION/set-setting.sh"

key="$(jq --raw-output '.settings // {} | to_entries[] | select(.value.kind == "count") | .key' "$MANIFEST" | head -1)"
if [ -z "$key" ]; then
  printf "  SKIP  %s declares no count setting to read\n" "$NAME"
  counted
  exit $?
fi
named="${PREFIX}_$key"
default="$(jq --raw-output --arg k "$key" '.settings[$k].default // ""' "$MANIFEST")"

person="$WORK/person"
project="$WORK/person/work/project"
mkdir -p "$person/.$NAME" "$project/.$NAME" "$project/deeper"

# The value read by a hook run in the directory named first, with any
# environment named after it.
reads_in() {
  local directory="$1"
  shift
  (
    unset "$named"
    cd "$directory" && env HOME="$person" "$@" bash -c ". \"$LIB\" && setting_value $key" 2>/dev/null
  )
}

[ "$(reads_in "$project")" = "$default" ]
assert "with neither file, the default stands" "$?" "it read '$(reads_in "$project")'"

printf '{"%s": 41}\n' "$key" > "$person/.$NAME/settings.json"
[ "$(reads_in "$project")" = "41" ]
assert "the person's own file is read where the project says nothing" "$?" \
  "it read '$(reads_in "$project")'"

printf '{"%s": "42"}\n' "$key" > "$project/.$NAME/settings.json"
[ "$(reads_in "$project")" = "42" ]
assert "the project's file comes before the person's" "$?" "it read '$(reads_in "$project")'"

[ "$(reads_in "$project/deeper")" = "42" ]
assert "and is found from a directory under the project root" "$?" \
  "it read '$(reads_in "$project/deeper")'"

[ "$(reads_in "$project" "$named=43")" = "43" ]
assert "the environment wins over both" "$?" "it read '$(reads_in "$project" "$named=43")'"

[ "$(reads_in "$person/work")" = "41" ]
assert "a directory above the project reads the person's file alone" "$?" \
  "it read '$(reads_in "$person/work")'"

printf '{"%s": 46}\n' "$key" > "$project/.$NAME/settings.local.json"
[ "$(reads_in "$project")" = "46" ]
assert "the project's local file comes before the project's" "$?" "it read '$(reads_in "$project")'"
rm "$project/.$NAME/settings.local.json"

printf '{"%s": "many"}\n' "$key" > "$project/.$NAME/settings.json"
[ "$(reads_in "$project")" = "$default" ]
assert "a value the setting cannot take is refused, as in the person's file" "$?" \
  "it read '$(reads_in "$project")'"

printf '%s = 47\n' "$named" > "$project/.$NAME/settings.json"
[ "$(reads_in "$project")" = "41" ]
assert "a file that is not JSON is passed over for the next one" "$?" "it read '$(reads_in "$project")'"

said="$(cd "$project" && unset "$named" && env HOME="$person" bash -c ". \"$LIB\" && setting_value $key" 2>&1 >/dev/null)"
printf '%s' "$said" | grep --quiet --fixed-strings "$project/.$NAME/settings.json"
assert "and named, rather than read as saying nothing" "$?" "it said '$said'"

printf "\nTest group: a hook names the project the payload names\n"

printf '{"%s": 44}\n' "$key" > "$project/.$NAME/settings.json"
named_outright="$(
  unset "$named"
  cd "$person/work" && env HOME="$person" \
    bash -c ". \"$LIB\" && settings_from_project \"$project\" && setting_value $key"
)"
[ "$named_outright" = "44" ]
assert "settings_from_project reads that project's file" "$?" "it read '$named_outright'"

gone="$(
  unset "$named"
  cd "$project" && env HOME="$person" \
    bash -c ". \"$LIB\" && settings_from_project \"$WORK/not-there\" && setting_value $key"
)"
[ "$gone" = "44" ]
assert "a directory that is not there leaves the one the hook runs in" "$?" "it read '$gone'"

printf "\nTest group: the script writes the project's file when asked to\n"

rm -rf "$project/.$NAME"
if [ -f "$WRITER" ]; then
  env HOME="$person" bash "$WRITER" --project "$project" "$key" 45 >/dev/null
  [ "$(jq --raw-output --arg k "$key" '.[$k]' "$project/.$NAME/settings.json" 2>/dev/null)" = "45" ]
  assert "--project writes .$NAME/settings.json at the project root" "$?" "nothing was written there"

  env HOME="$person" bash "$WRITER" --local "$project" "$key" 48 >/dev/null
  [ "$(jq --raw-output --arg k "$key" '.[$k]' "$project/.$NAME/settings.local.json" 2>/dev/null)" = "48" ]
  assert "--local writes .$NAME/settings.local.json beside it" "$?" "nothing was written there"

  grep --quiet --fixed-strings "45" "$person/.$NAME/settings.json"
  [ "$?" = "1" ]
  assert "and leaves the person's own file alone" "$?" "it wrote there as well"
fi

counted
