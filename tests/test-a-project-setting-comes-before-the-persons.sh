#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A project commits its own settings, so everyone working in it is held to the
# same values. The person's own file still stands where the project says
# nothing, and the environment still wins over both.
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
    cd "$directory" && env HOME="$person" "$@" bash -c ". \"$LIB\" && setting_value $key"
  )
}

[ "$(reads_in "$project")" = "$default" ]
assert "with neither file, the default stands" "$?" "it read '$(reads_in "$project")'"

printf '%s = 41\n' "$named" > "$person/.$NAME/settings"
[ "$(reads_in "$project")" = "41" ]
assert "the person's own file is read where the project says nothing" "$?" \
  "it read '$(reads_in "$project")'"

printf '%s = 42\n' "$named" > "$project/.$NAME/settings"
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

printf '%s = many\n' "$named" > "$project/.$NAME/settings"
[ "$(reads_in "$project")" = "$default" ]
assert "a value the setting cannot take is refused, as in the person's file" "$?" \
  "it read '$(reads_in "$project")'"

printf "\nTest group: a hook names the project the payload names\n"

printf '%s = 44\n' "$named" > "$project/.$NAME/settings"
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
  grep --quiet --line-regexp --fixed-strings "$named = 45" "$project/.$NAME/settings"
  assert "--project writes .$NAME/settings at the project root" "$?" "nothing was written there"

  grep --quiet --fixed-strings "45" "$person/.$NAME/settings"
  [ "$?" = "1" ]
  assert "and leaves the person's own file alone" "$?" "it wrote there as well"
fi

counted
