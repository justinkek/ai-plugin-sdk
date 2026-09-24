#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# The cloud install clones into one directory under /opt and everything else
# has to name that same one: the registrations, the rewrite the merge does, and
# the install the pasted script runs.
CLOUD="$BUILT/claude-code-cloud"
[ -d "$CLOUD" ] || { printf "  SKIP  this plugin has no cloud install\n"; exit 0; }

PAGE="$CLOUD/clients/claude-code-cloud.md"

printf "Test group: the install script names the checkout once and for all\n"

[ -f "$PAGE" ]
assert "the page a reader installs from is there" "$?" "nothing tells anyone how to install it"

cloned="$(sed -n 's/^[[:space:]]*mv [^ ]*\.new \(\/opt\/[A-Za-z0-9._-]*\)$/\1/p' "$PAGE" | head -1)"

[ -n "$cloned" ]
assert "the install script says where it clones to" "$?" \
  "nothing on the page moves a clone into place, so there is no path to hold the rest to"

named="$(grep --recursive --only-matching --extended-regexp '/opt/[A-Za-z0-9._-]+' "$CLOUD" \
  | sed -e 's/^[^:]*://' -e 's/\.new$//' | sort --unique)"

[ "$named" = "$cloned" ]
assert "every file naming a path under /opt names that one" "$?" \
  "they name $(printf '%s' "$named" | tr '\n' ' '), and an install writes to one while the rest point elsewhere"

printf "\nTest group: the pieces that have to agree on it do\n"

stated="$(sed -n 's/^stated=\(.*\)$/\1/p' "$CLOUD/merge-settings.sh")"
case "$stated" in "$cloned"/*) true ;; *) false ;; esac
assert "the merge rewrites away a path inside the checkout" "$?" \
  "it rewrites $stated, so a registration from another checkout is never recognised as this plugin's"

outside="$(jq --raw-output --arg checkout "$cloned/" \
  '.hooks | to_entries[] | .value[] | .hooks[] | .command
     | sub("^bash \""; "") | sub("\"$"; "")
     | select(startswith($checkout) | not)' \
  "$CLOUD/settings.json")"
[ -z "$outside" ]
assert "every registration names a command inside it" "$?" \
  "$(printf '%s' "$outside" | tr '\n' ' ')sits outside the checkout, and nothing is there to run"

grep --quiet --fixed-strings "$cloned/distributions/claude-code-cloud/install.sh" "$PAGE"
assert "and the pasted script runs the install from it" "$?" \
  "it clones to one place and installs from another"

printf "\nTest group: the pasted script is one a container can run\n"

script="$(sed -n '/^```bash$/,/^```$/p' "$PAGE" | sed '1d;$d')"

printf '%s' "$script" | bash -n
assert "it parses as bash" "$?" "the fenced bash block on the page is not a runnable script"

printf '%s' "$script" | grep --quiet --fixed-strings '|| true'
assert "a failed clone does not stop the session starting" "$?" \
  "a setup script that exits non-zero refuses the session"

jq --exit-status '.hooks != null' "$CLOUD/settings.json" >/dev/null
assert "and the settings it copies are readable JSON" "$?" \
  "the block writes something a harness cannot read"

[ -x "$CLOUD/install.sh" ]
assert "the install script is there and runnable" "$?" "the pasted script would run nothing"

bash -n "$CLOUD/install.sh"
assert "and it parses as bash" "$?" "the setup script would fail on a fresh container"

counted
