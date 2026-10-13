#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A list setting ships a list, and each layer turns its items on or off by name
# rather than replacing it, so a project that takes one item off still gets
# the items a later version ships.
printf "Test group: each layer turns an item on or off, and the last to name it decides\n"

DISTRIBUTION="$(distributions | head -1)"
LIB="$BUILT/$DISTRIBUTION/hooks/lib/settings.sh"

key="$(jq --raw-output '.settings // {} | to_entries[] | select(.value.kind == "list") | .key' "$MANIFEST" | head -1)"
if [ -z "$key" ]; then
  printf "  SKIP  %s declares no list setting to read\n" "$NAME"
  counted
  exit $?
fi
named="${PREFIX}_$key"
first="$(jq --raw-output --arg k "$key" '.settings[$k].default[0]' "$MANIFEST")"
shipped="$(jq --raw-output --arg k "$key" '.settings[$k].default | join(" ")' "$MANIFEST")"
rest="$(jq --raw-output --arg k "$key" '.settings[$k].default[1:] | join(" ")' "$MANIFEST")"

person="$WORK/person"
project="$person/work/project"
mkdir -p "$person/.$NAME" "$project/.$NAME"

listed() {
  (
    unset "$named" "${named}_SHIPPED"
    cd "$project" && env HOME="$person" "$@" bash -c ". \"$LIB\" && setting_value $key" 2>/dev/null
  )
}

[ "$(listed)" = "$shipped" ]
assert "with no layer, the shipped list stands" "$?" "it read '$(listed)'"

printf '{"%s": {"%s": false, "added": true}}\n' "$key" "$first" > "$person/.$NAME/settings.json"
[ "$(listed)" = "${rest:+$rest }added" ]
assert "the person's file takes an item off and adds one, and keeps the rest" "$?" "it read '$(listed)'"

printf '{"%s": {"%s": true}}\n' "$key" "$first" > "$project/.$NAME/settings.json"
[ "$(listed)" = "$shipped added" ]
assert "the project's file turns it back on, item by item" "$?" "it read '$(listed)'"

printf '{"%s": {"added": false}}\n' "$key" > "$project/.$NAME/settings.local.json"
[ "$(listed)" = "$shipped" ]
assert "the project's local file comes after the project's" "$?" "it read '$(listed)'"

[ "$(listed "$named={\"$first\": false}")" = "$rest" ]
assert "the environment comes last, as a JSON object" "$?" "it read '$(listed "$named={\"$first\": false}")'"

[ "$(listed "$named={\"$first\": {\"note\": \"kept\"}}")" = "$shipped" ]
assert "an item holding an object of its own is on" "$?" "it read '$(listed "$named={\"$first\": {\"note\": \"kept\"}}")'"

[ "$(listed "$named=$first")" = "$shipped" ]
assert "an environment value that is not JSON is passed over" "$?" "it read '$(listed "$named=$first")'"

said="$(cd "$project" && env HOME="$person" "$named=$first" bash -c ". \"$LIB\" && setting_value $key" 2>&1 >/dev/null)"
printf '%s' "$said" | grep --quiet --fixed-strings "$named"
assert "and named, rather than read as saying nothing" "$?" "it said '$said'"

printf "\nTest group: the shipped switch leaves out what the plugin ships\n"

rm "$project/.$NAME/settings.local.json" "$project/.$NAME/settings.json"
printf '{"%s_SHIPPED": "off", "%s": {"added": true}}\n' "$key" "$key" > "$person/.$NAME/settings.json"
[ "$(listed)" = "added" ]
assert "${key}_SHIPPED off leaves only what is turned on" "$?" "it read '$(listed)'"

[ "$(listed "${named}_SHIPPED=on")" = "$shipped added" ]
assert "and on brings the shipped items back" "$?" \
  "it read '$(listed "${named}_SHIPPED=on")'"

printf "\nTest group: a file written before 0.8.0 is converted once\n"

converter="$WORK/converter"
mkdir -p "$converter"
printf '# written by hand\n%s = shipped-item another\n%s_SOMETHING_OLD = kept\n' "$named" "$PREFIX" \
  > "$converter/settings"
env "${PREFIX}_HOME=$converter" bash -c ". \"$LIB\" && settings_converted"

[ "$(jq --compact-output --arg k "$key" '.[$k]' "$converter/settings.json")" = '{"shipped-item":true,"another":true}' ]
assert "a list comes across as its items, turned on" "$?" "it holds $(cat "$converter/settings.json")"

[ "$(jq --raw-output --arg k "${key}_SHIPPED" '.[$k]' "$converter/settings.json")" = "off" ]
assert "with the shipped list left out, as the old value replaced it" "$?" "it holds $(cat "$converter/settings.json")"

[ "$(jq --raw-output '.SOMETHING_OLD' "$converter/settings.json")" = "kept" ]
assert "a key the plugin no longer declares comes across for its own migration" "$?" \
  "it holds $(cat "$converter/settings.json")"

[ -f "$converter/settings.old" ] && [ ! -f "$converter/settings" ]
assert "and the old file is kept beside it as settings.old" "$?" "it is $(ls "$converter")"

before="$(cat "$converter/settings.json")"
printf 'X = 1\n' > "$converter/settings"
env "${PREFIX}_HOME=$converter" bash -c ". \"$LIB\" && settings_converted"
[ "$(cat "$converter/settings.json")" = "$before" ]
assert "a settings.json already there is never written over" "$?" "it holds $(cat "$converter/settings.json")"

counted
