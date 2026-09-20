#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# Every hook is its own process, so two plugins installed together cannot
# collide: each sources its own lib/ and nothing else. The collision that can
# happen is a plugin's own hook defining a name lib/ already defines. It is
# silent, and which one wins depends on the order they were sourced in.

# Every function lib/ defines, wherever it defines it.
library_functions() {
  grep -hoE '^[a-z_]+\(\)' "$SDK"/lib/*.sh "$SDK"/lib/*/*.sh 2>/dev/null | tr -d '()' | sort --unique
}

# Every variable settings/paths.sh leaves in the shell.
library_variables() {
  grep -hoE '^[A-Z_]+=' "$SDK"/lib/*/*.sh 2>/dev/null | tr -d '=' | sort --unique
}

printf "Test group: lib/ defines each name once\n"

repeated="$(grep -hoE '^[a-z_]+\(\)' "$SDK"/lib/*.sh "$SDK"/lib/*/*.sh 2>/dev/null \
  | tr -d '()' | sort | uniq -d)"
[ -z "$repeated" ]
assert "no function is defined twice" "$?" \
  "$repeated is defined in two files, and which one wins depends on the source order"

printf "\nTest group: a plugin's hooks define no name the libraries already define\n"

for script in "$PLUGIN"/hooks/*.sh; do
  [ -f "$script" ] || continue
  named="$(basename "$script")"

  taken="$(comm -12 \
    <(grep -oE '^[a-z_]+\(\)' "$script" | tr -d '()' | sort --unique) \
    <(library_functions))"
  [ -z "$taken" ]
  assert "hooks/$named defines no library function" "$?" \
    "it defines $taken, which silently replaces the library's, or is replaced by it"

  taken="$(comm -12 \
    <(grep -oE '^[A-Z_]+=' "$script" | tr -d '=' | sort --unique) \
    <(library_variables))"
  [ -z "$taken" ]
  assert "and no library variable" "$?" "it assigns $taken, which the libraries read"
done

printf "\nTest group: and the check catches one when it is there\n"

planted="$WORK/planted.sh"
printf '%s\n' '#!/usr/bin/env bash' 'setting_value() { printf clobbered; }' > "$planted"
taken="$(comm -12 <(grep -oE '^[a-z_]+\(\)' "$planted" | tr -d '()' | sort --unique) <(library_functions))"
[ "$taken" = "setting_value" ]
assert "a planted setting_value is found" "$?" "the check saw nothing wrong with it"

printf '%s\n' '#!/usr/bin/env bash' 'PLUGIN_STATE=/somewhere/else' > "$planted"
taken="$(comm -12 <(grep -oE '^[A-Z_]+=' "$planted" | tr -d '=' | sort --unique) <(library_variables))"
[ "$taken" = "PLUGIN_STATE" ]
assert "a planted PLUGIN_STATE is found" "$?" "the check saw nothing wrong with it"

printf '%s\n' '#!/usr/bin/env bash' 'a_name_of_its_own() { :; }' 'MY_OWN=1' > "$planted"
taken="$(comm -12 <(grep -oE '^[a-z_]+\(\)' "$planted" | tr -d '()' | sort --unique) <(library_functions))"
[ -z "$taken" ]
assert "a plugin's own names are left alone" "$?" "it refused $taken, which lib/ does not define"

counted
