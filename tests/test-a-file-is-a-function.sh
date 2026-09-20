#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# lib/ is a directory per subject. Inside one, a file is a function and carries
# its name, so a reader finds setting_value by looking for setting_value.sh.
printf "Test group: a file under a subject holds one function, named after it\n"

for source in "$SDK"/lib/*/*.sh; do
  named="$(basename "$source" .sh)"
  defined="$(grep -cE '^[a-z_]+\(\)' "$source")"

  # paths.sh is the one file that is not a function: the variables every other
  # file in its directory reads.
  if [ "$named" = "paths" ]; then
    [ "$defined" = "0" ]
    assert "settings/paths.sh defines no function" "$?" "it defines $defined"
    continue
  fi

  [ "$defined" = "1" ]
  assert "${source#$SDK/lib/} holds one function" "$?" "it holds $defined"

  grep --quiet --extended-regexp "^$named\(\)" "$source"
  assert "and it is called $named" "$?" "the file and the function disagree"
done

printf "\nTest group: the file a hook sources names its parts and nothing else\n"

for source in "$SDK"/lib/*.sh; do
  named="$(basename "$source" .sh)"
  [ "$named" = "shell" ] && continue

  defined="$(grep -cE '^[a-z_]+\(\)' "$source")"
  [ "$defined" = "0" ]
  assert "lib/$named.sh defines nothing itself" "$?" \
    "it defines $defined, so a reader cannot trust the directory to hold them"

  [ -d "$SDK/lib/$named" ]
  assert "and lib/$named/ is where they live" "$?" "there is no directory beside it"
done

printf "\nTest group: every part is sourced by the file that owns it\n"

for source in "$SDK"/lib/*/*.sh; do
  subject="$(basename "$(dirname "$source")")"
  named="$(basename "$source")"
  grep --quiet --fixed-strings "$subject/$named" "$SDK/lib/$subject.sh"
  assert "lib/$subject.sh sources $named" "$?" "it ships and nothing loads it"
done

printf "\nTest group: what the build ships carries the same shape\n"

for distribution in $(distributions); do
  [ -d "$BUILT/$distribution/hooks/lib" ] || continue
  for subject in payload say reply notes settings state; do
    [ -d "$BUILT/$distribution/hooks/lib/$subject" ]
    assert "$distribution ships lib/$subject/" "$?" "the build flattened it"
  done
  [ ! -f "$BUILT/$distribution/hooks/lib/settings.json" ]
  assert "$distribution ships no settings.json" "$?" \
    "that file is the build's, and nothing a hook runs reads it"
done

counted
