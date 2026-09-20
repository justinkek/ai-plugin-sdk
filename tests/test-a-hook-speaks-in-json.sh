#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# Some clients read nothing but this shape, and discard plain text in silence.
carried() {
  python3 -c '
import json, sys
said = json.load(sys.stdin)["hookSpecificOutput"]
print(said["hookEventName"])
print(said["additionalContext"][:80])' 2>/dev/null
}

said_for() {
  local script="$1" event="$2" session="$3"
  printf '{"hook_event_name":"%s","session_id":"%s","prompt":"x"}' "$event" "$session" \
    | env "${PREFIX}_HOME=$WORK/home-$session" bash "$BUILT/$(distributions | head -1)/hooks/$script" 2>/dev/null
}

printf "Test group: a hook that speaks says it in the one shape every client reads\n"

spoke=0
while read -r event script; do
  said="$(said_for "$script" "$event" "$event-$script")"
  [ -n "$said" ] || continue
  spoke=$((spoke + 1))

  printf '%s' "$said" | head -1 | grep --quiet '^{"hookSpecificOutput"\|^{"systemMessage"'
  assert "$script answers in JSON" "$?" "it printed '$(printf '%s' "$said" | head -c 60)'"

  named="$(printf '%s' "$said" | carried | head -1)"
  [ "$named" = "$event" ]
  assert "and names $event, so a client knows what it is answering" "$?" "it named '$named'"
done < <(jq --raw-output '.hooks | to_entries[] | .key as $event | .value[] | "\($event) \(.)"' "$MANIFEST")

[ "$spoke" -gt 0 ]
assert "at least one hook speaks at all" "$?" "no hook printed anything, so nothing reaches a session"

printf "\nTest group: a hand run prints the text itself\n"

for script in $(jq --raw-output '.hooks.SessionStart[]? // empty' "$MANIFEST"); do
  plain="$(printf '{}' | env "${PREFIX}_HOME=$WORK/home-plain" \
    bash "$BUILT/$(distributions | head -1)/hooks/$script" 2>/dev/null | head -1)"
  [ -n "$plain" ] || continue
  printf '%s' "$plain" | grep --quiet --fixed-strings '{"hookSpecificOutput"'
  [ "$?" = "1" ]
  assert "$script answers a payload with no event name in text" "$?" \
    "a person piping it by hand reads JSON"
done

printf "\nTest group: a registration runs the script through an interpreter\n"

# ZCode will not run a hook that has lost its executable bit, and an install
# that extracts a zip loses it, so nothing is run by its own path.
for distribution in $(distributions); do
  for registered in "$BUILT/$distribution/hooks/hooks.json" "$BUILT/$distribution/settings.json"; do
    [ -f "$registered" ] || continue
    wrong="$(jq --raw-output '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$registered" \
      | grep --invert-match '^bash "' || true)"
    [ -z "$wrong" ]
    assert "$distribution runs every hook through bash" "$?" \
      "$wrong needs the executable bit, and a client that extracts without it runs nothing"
  done
done

counted
