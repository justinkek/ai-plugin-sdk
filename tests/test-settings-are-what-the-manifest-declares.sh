#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

DISTRIBUTION="$(distributions | head -1)"
LIB="$BUILT/$DISTRIBUTION/hooks/lib/settings.sh"
SKILL="$BUILT/$DISTRIBUTION/skills/settings/SKILL.md"

declared() { jq --raw-output '.settings // {} | keys[]' "$MANIFEST"; }

# One key, read the way a hook reads it, with the environment given in $2.
read_back() {
  env -i HOME="$WORK/read" PATH="$PATH" "${PREFIX}_HOME=$WORK/read" ${2:+"$2"} \
    bash -c ". \"$LIB\" && setting_value $1"
}

printf "Test group: every declared setting is read at its declared default\n"

while read -r key; do
  [ -n "$key" ] || continue
  stated="$(jq --raw-output --arg k "$key" '.settings[$k].default // ""' "$MANIFEST")"
  stated="${stated//\{state\}/$WORK/read/state}"
  stated="${stated//\{home\}/$WORK/read}"
  [ "$(read_back "$key")" = "$stated" ]
  assert "$key defaults to '${stated:-nothing}'" "$?" "it read '$(read_back "$key")'"
done < <(declared)

printf "\nTest group: a value the setting cannot take is refused, and the default stands\n"

while read -r key; do
  [ -n "$key" ] || continue
  kind="$(jq --raw-output --arg k "$key" '.settings[$k].kind // "text"' "$MANIFEST")"
  case "$kind" in text) continue ;; esac

  stated="$(read_back "$key")"
  [ "$(read_back "$key" "${PREFIX}_$key=not-a-$kind-at-all")" = "$stated" ]
  assert "$key refuses a value no $kind takes" "$?" \
    "a hook would read 'not-a-$kind-at-all' and have no rule for it"
done < <(declared)

printf "\nTest group: a value it can take is read, from the environment and from the file\n"

while read -r key; do
  [ -n "$key" ] || continue
  kind="$(jq --raw-output --arg k "$key" '.settings[$k].kind // "text"' "$MANIFEST")"
  case "$kind" in
    count) held=3 ;;
    switch) held=off ;;
    choice) held="$(jq --raw-output --arg k "$key" '.settings[$k].values[-1]' "$MANIFEST")" ;;
    *) held=something ;;
  esac

  [ "$(read_back "$key" "${PREFIX}_$key=$held")" = "$held" ]
  assert "$key reads $held from the environment" "$?" "it read '$(read_back "$key" "${PREFIX}_$key=$held")'"

  mkdir -p "$WORK/read"
  printf '# a comment\n\n%s_%s = %s\n' "$PREFIX" "$key" "$held" > "$WORK/read/settings"
  [ "$(read_back "$key")" = "$held" ]
  assert "and reads it from the settings file" "$?" "it read '$(read_back "$key")'"
  rm -f "$WORK/read/settings"
done < <(declared)

printf "\nTest group: a switch is read whatever the case\n"

while read -r key; do
  [ -n "$key" ] || continue
  [ "$(jq --raw-output --arg k "$key" '.settings[$k].kind // ""' "$MANIFEST")" = "switch" ] || continue
  [ "$(read_back "$key" "${PREFIX}_$key=OFF")" = "off" ]
  assert "$key reads OFF as off" "$?" "a person who writes it in capitals is ignored"
done < <(declared)

printf "\nTest group: the settings skill names every key a hook reads\n"

while read -r key; do
  [ -n "$key" ] || continue
  grep --quiet --fixed-strings "${PREFIX}_$key" "$SKILL"
  assert "the skill names ${PREFIX}_$key" "$?" \
    "a hook reads it and nothing tells the user it is there"
done < <(declared)

printf "\nTest group: and names no key nothing reads\n"

while read -r named; do
  # Unquoted on purpose: one key to a line for grep.
  # shellcheck disable=SC2046
  printf '%s\n' $(declared) "STOP_NOTE_DIRECTORY" "HOME" | grep --quiet --line-regexp "${named#${PREFIX}_}"
  assert "$named is a setting something reads" "$?" \
    "the skill offers it and no hook would ever read it"
done < <(grep --only-matching --extended-regexp "${PREFIX}_[A-Z_]+" "$SKILL" | sort --unique)

counted
