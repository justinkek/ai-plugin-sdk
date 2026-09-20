#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

LIB="$BUILT/$(distributions | head -1)/hooks/lib"

printf "Test group: every library reaches the shell check\n"

# The two roots of the graph. A hook reaches one of them whatever it sources.
for named in payload.sh settings.sh; do
  grep --quiet --fixed-strings 'shell.sh' "$LIB/$named"
  assert "$named sources the check" "$?" "a hook entering through it runs unchecked"
done

for named in say.sh reply.sh notes.sh; do
  reached="$(bash -c ". \"$LIB/$named\" >/dev/null 2>&1; printf '%s' \"\$PLUGIN_SHELL_CHECKED\"")"
  [ "$reached" = "1" ]
  assert "$named reaches it too" "$?" "sourcing it left the check unrun"
done

printf "\nTest group: a shell below the floor is refused, with a sentence\n"

# The check as it ships, with the floor raised past this shell.
sed 's/-lt 3\]/-lt 99]/; s/-lt 3 /-lt 99 /' "$LIB/shell.sh" > "$WORK/too-old.sh"
said="$(bash -c ". \"$WORK/too-old.sh\"; echo REACHED" 2>&1)"

printf '%s' "$said" | grep --quiet --fixed-strings 'bash 3.2 or newer'
assert "it says what it needs" "$?" "it said '$said'"

printf '%s' "$said" | grep --quiet --fixed-strings 'REACHED'
[ "$?" = "1" ]
assert "and nothing after it runs" "$?" "the hook carried on into a syntax error"

printf "\nTest group: the check runs once, not once per library\n"

counted="$(bash -c ". \"$LIB/say.sh\" >/dev/null 2>&1; . \"$LIB/notes.sh\" >/dev/null 2>&1; printf '%s' \"\$PLUGIN_SHELL_CHECKED\"")"
[ "$counted" = "1" ]
assert "the guard holds across several sources" "$?" "it read '$counted'"

printf "\nTest group: no library needs a feature newer than the floor\n"

wrong="$(grep --recursive --line-number --extended-regexp \
  'declare -A|\$\{[A-Za-z_]+\^\^|\bmapfile\b|\breadarray\b|;;&' "$SDK/lib" || true)"
[ -z "$wrong" ]
assert "nothing in lib/ needs bash 4" "$?" "$wrong"

counted
