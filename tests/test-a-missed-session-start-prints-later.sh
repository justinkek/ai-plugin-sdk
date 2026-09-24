#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A client that runs no session start hook would otherwise never be given what
# the plugin prints there. The SDK registers a pair of hooks that carries it to
# the first prompt instead, and the plugin writes neither of them.
if [ -z "$(jq --raw-output '.hooks.SessionStart[]? // empty' "$MANIFEST")" ]; then
  printf "  SKIP  this plugin prints nothing at session start, so there is nothing to carry\n"
  exit 0
fi

printf "Test group: a session start nobody heard is printed on the first prompt\n"

HOOKS="$BUILT/$(distributions | head -1)/hooks"

[ -f "$HOOKS/print-session-start-if-missed.sh" ] && [ -f "$HOOKS/mark-session-started.sh" ]
assert "the build wrote both hooks" "$?" "a plugin would have to write them itself"

for distribution in $(distributions); do
  for where in "$BUILT/$distribution/hooks/hooks.json" "$BUILT/$distribution/settings.json"; do
    [ -f "$where" ] || continue
    grep --quiet --fixed-strings 'print-session-start-if-missed.sh' "$where" \
      && grep --quiet --fixed-strings 'mark-session-started.sh' "$where"
    assert "$distribution registers both" "$?" "a hook nothing runs prints nothing"
  done
done

named() { printf '{"hook_event_name":"%s","session_id":"%s"}' "$1" "$2"; }

prompted() {
  named UserPromptSubmit "$2" \
    | env "${PREFIX}_HOME=$1" bash "$HOOKS/print-session-start-if-missed.sh"
}

# Nothing ran at the start of this session, so the first prompt carries it.
unheard="$WORK/unheard"
first="$(prompted "$unheard" s1)"
[ -n "$first" ]
assert "a session nothing started is given the print" "$?" "the client is left without it"

printf '%s' "$first" | jq --exit-status '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null
assert "and it is addressed to the prompt it arrived on" "$?" "the client reads nothing else"

[ -z "$(prompted "$unheard" s1)" ]
assert "and the next prompt is not given it again" "$?" "every prompt repeats the print"

# The session start hooks ran here, so the first prompt has nothing to carry.
heard="$WORK/heard"
named SessionStart s2 | env "${PREFIX}_HOME=$heard" bash "$HOOKS/mark-session-started.sh"
[ -z "$(prompted "$heard" s2)" ]
assert "a session that was started is not told twice" "$?" "the print arrives once at the start and again on the first prompt"

# What the two hooks carry is what the session start hooks say, not a copy the
# SDK keeps of it.
for script in $(bash -c ". \"$HOOKS/lib/plugin-manifest.sh\"; plugin_session_start_hooks"); do
  named SessionStart s3 | env "${PREFIX}_HOME=$WORK/own" bash "$HOOKS/$script"
done | jq --raw-output '.hookSpecificOutput.additionalContext // .' > "$WORK/said-at-start"
printf '%s' "$first" | jq --raw-output '.hookSpecificOutput.additionalContext' > "$WORK/said-later"
diff --unified "$WORK/said-at-start" "$WORK/said-later" >/dev/null
assert "and it says what the session start hooks say" "$?" "the later print has drifted from the one at the start"

counted
