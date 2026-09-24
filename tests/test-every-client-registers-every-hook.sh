#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A hook one distribution runs and another does not is a plugin that behaves
# differently depending on where it was installed from.
printf "Test group: every hook is registered in every distribution that ships hooks\n"

# What a distribution registers, by file name alone.
scripts_in() {
  local where="$1"
  [ -f "$where" ] || return 0
  jq --raw-output '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$where" \
    | sed -e 's/"$//' -e 's#.*/##' | sort --unique
}

registration_of() {
  local distribution="$1"
  if [ -f "$BUILT/$distribution/hooks/hooks.json" ]; then
    printf '%s' "$BUILT/$distribution/hooks/hooks.json"
  else
    printf '%s' "$BUILT/$distribution/settings.json"
  fi
}

# The hooks themselves, which is what every distribution has to register. A
# harness may add one of its own on top; that one is nobody else's to run.
first="$(distributions | head -1)"
expected="$(for script in "$BUILT/$first"/hooks/*.sh; do basename "$script"; done | sort --unique)"

[ -n "$expected" ]
assert "$first was given hooks at all" "$?" "the build wrote none to register"

for distribution in $(distributions); do
  where="$(registration_of "$distribution")"
  [ -f "$where" ] || continue
  missing="$(comm -23 <(printf '%s\n' "$expected") <(scripts_in "$where"))"
  [ -z "$missing" ]
  assert "$distribution registers all of them" "$?" \
    "it never runs $(printf '%s' "$missing" | tr '\n' ' ')"
done

# An extension spawns the scripts itself rather than reading a registration.
for distribution in $(distributions); do
  [ -f "$BUILT/$distribution/src/index.ts" ] || continue
  missing=""
  while read -r script; do
    [ -n "$script" ] || continue
    grep --quiet --fixed-strings "\"$script\"" "$BUILT/$distribution/src/index.ts" \
      || missing="$missing $script"
  done < <(printf '%s\n' "$expected")
  [ -z "$missing" ]
  assert "$distribution's extension names all of them" "$?" "it never runs$missing"
done

printf "\nTest group: a client reads the registration from where its manifest says\n"

for distribution in $(distributions); do
  manifest="$BUILT/$distribution/.codex-plugin/plugin.json"
  [ -f "$manifest" ] || continue

  stated="$(jq --raw-output '.hooks // empty' "$manifest")"
  [ -n "$stated" ]
  assert "$distribution's manifest names a hooks file" "$?" \
    "Codex reads hooks from the manifest, and this one names none"

  [ -f "$BUILT/$distribution/${stated#./}" ]
  assert "and that file is one the build wrote" "$?" "it names $stated, which is not there"
done

counted
