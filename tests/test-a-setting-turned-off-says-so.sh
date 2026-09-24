#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A plugin can say that one setting turns another off. The settings skill shows
# that pair as an example, so a person reading a value of "n.a." knows why.
printf "Test group: the skill shows a pair where one setting turns the other off\n"

SKILL="$BUILT/$(distributions | head -1)/skills/settings/SKILL.md"
SECTION="$WORK/idle-section"

sed -n '/A key another setting has turned off/,/## What not to do/p' "$SKILL" > "$SECTION"

# The pairs the manifest declares, in the order the skill takes them.
pairs() {
  jq --raw-output '.settings // {} | to_entries[] | select(.value.idle) | .key' "$MANIFEST"
}

count="$(pairs | grep --count . || true)"

if [ "$count" = "0" ]; then
  grep --quiet --fixed-strings 'A key another setting has turned off' "$SKILL"
  [ "$?" = "1" ]
  assert "a plugin with no such pair has no such section" "$?" \
    "the skill shows an example it has nothing to fill in"
  counted
  exit
fi

first="$(pairs | head -1)"
turns="$(jq --raw-output --arg k "$first" '.settings[$k].idle.key' "$MANIFEST")"
value="$(jq --raw-output --arg k "$first" '.settings[$k].idle.value' "$MANIFEST")"
default="$(jq --raw-output --arg k "$first" '.settings[$k].default // ""' "$MANIFEST")"

grep --quiet --fixed-strings "| \`${PREFIX}_$turns\` | \`$value\` (set) |" "$SECTION"
assert "the row for the key that was set shows its value" "$?" \
  "a reader cannot see which setting did the turning off"

if [ -n "$default" ]; then
  said="| \`${PREFIX}_$first\` | \`$default\` (set - n.a. because \`${PREFIX}_$turns\` is set to \`$value\`) |"
else
  said="| \`${PREFIX}_$first\` | set - n.a. because \`${PREFIX}_$turns\` is set to \`$value\` |"
fi
grep --quiet --fixed-strings "$said" "$SECTION"
assert "the row for the key it turned off says which key and which value" "$?" \
  "it reads '$(grep --fixed-strings "${PREFIX}_$first" "$SECTION")'"

case "$count" in
  1) counted_as="One pair does this." ;;
  2) counted_as="Two pairs do this." ;;
  *) counted_as="$count pairs do this." ;;
esac
grep --quiet --fixed-strings "$counted_as" "$SECTION"
assert "the sentence counts the pairs" "$?" "it does not say '$counted_as'"

printf "\nTest group: and says in words what each pair does\n"

while read -r key; do
  [ -n "$key" ] || continue
  turns="$(jq --raw-output --arg k "$key" '.settings[$k].idle.key' "$MANIFEST")"
  value="$(jq --raw-output --arg k "$key" '.settings[$k].idle.value' "$MANIFEST")"
  because="$(jq --raw-output --arg k "$key" '.settings[$k].idle.because' "$MANIFEST")"
  so="$(jq --raw-output --arg k "$key" '.settings[$k].idle.so' "$MANIFEST")"

  grep --quiet --fixed-strings \
    "\`${PREFIX}_$turns = $value\` $because, so \`${PREFIX}_$key\` $so." "$SECTION"
  assert "$key is explained by what turned it off" "$?" \
    "the skill does not say why ${PREFIX}_$key reads n.a."
done < <(pairs)

printf "\nTest group: each piece of that section can be asked for on its own\n"

# The builder's parts, loaded the way build loads them, so a piece can be
# called without running a whole build.
piece() {
  sdk="$SDK" plugin="$PLUGIN" bash -c '
    sdk="$sdk"; plugin="$plugin"
    . "$sdk/builder/manifest.sh"
    . "$sdk/builder/skills.sh"
    '"$1"
}

[ "$(piece 'idle_count 1')" = "One pair does this." ]
assert "one pair is counted in words" "$?" "it said '$(piece 'idle_count 1')'"

[ "$(piece 'idle_count 2')" = "Two pairs do this." ]
assert "two pairs are counted in words" "$?" "it said '$(piece 'idle_count 2')'"

[ "$(piece 'idle_count 7')" = "7 pairs do this." ]
assert "more than two are counted in figures" "$?" "it said '$(piece 'idle_count 7')'"

[ "$(piece 'idle_keys' | grep --count .)" = "$count" ]
assert "every declared pair is listed" "$?" "it listed $(piece 'idle_keys' | grep --count .) of $count"

[ "$(piece "idle_rows $first" | grep --count .)" = "4" ]
assert "the table is a header, a rule and two rows" "$?" \
  "it wrote $(piece "idle_rows $first" | grep --count .) lines"

piece "idle_rows $first" | grep --quiet --fixed-strings "${PREFIX}_$first"
assert "and names the key that was turned off" "$?" "the row is about some other key"

counted
