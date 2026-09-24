#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# The settings skill used to ask an agent to edit the settings file itself. A
# script writes it now, so the file a hook reads is written the same way every
# time.
printf "Test group: the script writes what a hook then reads\n"

DISTRIBUTION="$(distributions | head -1)"
WRITER="$BUILT/$DISTRIBUTION/set-setting.sh"
LIB="$BUILT/$DISTRIBUTION/hooks/lib/settings.sh"
HOME_DIR="$WORK/written"

declared() { jq --raw-output '.settings // {} | keys[]' "$MANIFEST"; }

[ -f "$WRITER" ]
assert "the build wrote the script" "$?" "the skill has nothing to run"

writes() { env "${PREFIX}_HOME=$HOME_DIR" bash "$WRITER" "$1" "$2"; }
reads() { env "${PREFIX}_HOME=$HOME_DIR" bash -c ". \"$LIB\" && setting_value $1"; }

# One key of each kind, with a value that kind takes.
while read -r key; do
  [ -n "$key" ] || continue
  case "$(jq --raw-output --arg k "$key" '.settings[$k].kind // "text"' "$MANIFEST")" in
    count) held=4 ;;
    switch) held=off ;;
    choice) held="$(jq --raw-output --arg k "$key" '.settings[$k].values[-1]' "$MANIFEST")" ;;
    *) continue ;;
  esac

  writes "$key" "$held" >/dev/null
  [ "$(reads "$key")" = "$held" ]
  assert "$key is written as $held and read back" "$?" "it read '$(reads "$key")'"
done < <(declared)

printf "\nTest group: what it refuses, it does not write\n"

# A text setting takes any value, so there is nothing for it to refuse. The
# first key of another kind is the one tried, where there is one.
first="$(jq --raw-output '.settings // {} | to_entries | (map(select((.value.kind // "text") != "text")) + .)[0].key // empty' "$MANIFEST")"
kind="$(jq --raw-output --arg k "$first" '.settings[$k].kind // "text"' "$MANIFEST")"

held="$(reads "$first")"
writes "$first" 'not-a-value-any-kind-takes' >/dev/null 2>&1
[ "$?" != "0" ] || [ "$kind" = "text" ]
assert "a value the setting cannot take is refused" "$?" "it wrote it anyway"

[ "$(reads "$first")" = "$held" ]
assert "and the value that was there still is" "$?" "it read '$(reads "$first")'"

writes 'NOT_A_KEY_THIS_PLUGIN_HAS' something >/dev/null 2>&1
[ "$?" != "0" ]
assert "a key this plugin does not have is refused" "$?" "it wrote a key nothing reads"

grep --quiet --fixed-strings 'NOT_A_KEY_THIS_PLUGIN_HAS' "$HOME_DIR/settings"
[ "$?" = "1" ]
assert "and nothing about it is in the file" "$?" "the file holds a key no hook reads"

printf "\nTest group: the rest of the file is left as it was\n"

printf '# a person wrote this\n\n%s_%s = %s\n# and this\n' \
  "$PREFIX" "$first" "$(reads "$first")" > "$HOME_DIR/settings"

case "$kind" in
  count) other=9 ;;
  switch) other=on ;;
  choice) other="$(jq --raw-output --arg k "$first" '.settings[$k].values[0]' "$MANIFEST")" ;;
  *) other=something ;;
esac

writes "$first" "$other" >/dev/null
[ "$(grep --count . "$HOME_DIR/settings")" = "3" ]
assert "the comments are still there" "$?" \
  "it wrote $(grep --count . "$HOME_DIR/settings") lines where three were expected"

# The old assignment was the third line of the fixture above.
[ "$(sed -n '3p' "$HOME_DIR/settings")" = "${PREFIX}_$first = $other" ]
assert "and the new value sits where the old one sat" "$?" \
  "it reads '$(sed -n '3p' "$HOME_DIR/settings")'"

printf "\nTest group: the skill says to run it, where there is a path to run\n"

for distribution in $(distributions); do
  skill="$BUILT/$distribution/skills/settings/SKILL.md"
  [ -f "$skill" ] || continue
  if [ -f "$BUILT/$distribution/set-setting.sh" ] \
    && grep --quiet --fixed-strings 'set-setting.sh' "$skill"; then
    grep --quiet --extended-regexp 'bash "[^"]+/set-setting.sh"' "$skill"
    assert "$distribution names a directory to run it from" "$?" \
      "the steps say to run a script at a path that is not one"
  else
    grep --quiet --fixed-strings 'read the file, replace or add the setting' "$skill"
    assert "$distribution says what to do instead" "$?" \
      "the steps say neither how to run it nor what it would have done"
  fi
done

counted
