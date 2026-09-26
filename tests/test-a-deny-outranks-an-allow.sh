#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A hook on a tool call answers deny, ask or allow, and a second plugin's hook
# answers the same call. A deny from either has to hold whatever the other said,
# or installing one plugin quietly switches another one off.
LIB="$BUILT/$(distributions | head -1)/hooks/lib"

merged() { printf '%s\n' "$@" | bash -c '. "$1/permission.sh"; strongest_permission' _ "$LIB"; }
answer() { bash -c '. "$1/permission.sh"; hook_permission "$2" "$3"' _ "$LIB" "$1" "$2"; }
decision_of() { printf '%s' "$1" | jq --raw-output '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }

allow="$(answer allow 'fine by me')"
ask="$(answer ask 'check with a person')"
deny="$(answer deny 'not here')"

printf "Test group: a decision is said in the shape every client reads\n"

[ "$(printf '%s' "$deny" | jq --raw-output '.hookSpecificOutput.hookEventName')" = "PreToolUse" ]
assert "it names the event it answers" "$?" "it said '$deny'"

[ "$(decision_of "$deny")" = "deny" ] && [ "$(decision_of "$allow")" = "allow" ] && [ "$(decision_of "$ask")" = "ask" ]
assert "and carries the decision it was given" "$?" "deny, ask and allow came out as $(decision_of "$deny"), $(decision_of "$ask"), $(decision_of "$allow")"

quoted="$(answer deny 'a "quoted" path\with a backslash')"
[ "$(printf '%s' "$quoted" | jq --raw-output '.hookSpecificOutput.permissionDecisionReason')" = 'a "quoted" path\with a backslash' ]
assert "a reason holding quotes survives as JSON" "$?" "it said '$quoted'"

[ "$(decision_of "$(answer permit 'typo')")" = "deny" ]
assert "a decision that is none of the three is a deny" "$?" "a guard that misspells deny would let the call through"

printf "\nTest group: across hooks, deny outranks ask and ask outranks allow\n"

[ "$(decision_of "$(merged "$allow" "$deny")")" = "deny" ]
assert "an allow before a deny is a deny" "$?" "one plugin allowing switched another off"

[ "$(decision_of "$(merged "$deny" "$allow")")" = "deny" ]
assert "and so is a deny before an allow" "$?" "the order the hooks ran in decided it"

[ "$(decision_of "$(merged "$allow" "$ask" "$deny")")" = "deny" ]
assert "a deny outranks an ask" "$?" "a person would be asked about a call a guard refused"

[ "$(decision_of "$(merged "$allow" "$ask")")" = "ask" ]
assert "an ask outranks an allow" "$?" "a call a guard wanted checked went through unasked"

[ "$(decision_of "$(merged "$allow")")" = "allow" ]
assert "an allow alone stands" "$?" "nothing refused it"

[ -z "$(merged "" "plain text a hook printed")" ]
assert "no decision at all leaves the call to the client" "$?" "a decision was made up"

printf "\nTest group: where the SDK runs the hooks, it merges them this way\n"

EXTENSION="$BUILT/pi/src/index.ts"
if [ -f "$EXTENSION" ]; then
  grep --quiet --fixed-strings 'pi.on("tool_call"' "$EXTENSION"
  assert "the Pi extension runs the hooks on a tool call" "$?" "a guard is never asked on Pi"

  grep --quiet --fixed-strings 'strongest_permission' "$EXTENSION"
  assert "and merges their answers with strongest_permission" "$?" "it would merge them some other way"
else
  printf "  SKIP  this plugin has no Pi install\n"
fi

counted
