#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# new-plugin lays down a plugin. What it lays down has to build, and the built
# hook has to speak, or an author's first run of the build fails on something
# the SDK wrote for them.
printf "Test group: what new-plugin writes is a plugin the build builds\n"

made="$WORK/made"

"$SDK/new-plugin" "$made/first-plugin" someone/first-plugin > "$WORK/said"
assert "new-plugin runs" "$?" "an author cannot start: $(cat "$WORK/said")"

for wanted in plugin.json hooks/say-the-rule.sh rules/reply-shape.md; do
  [ -f "$made/first-plugin/$wanted" ]
  assert "it writes $wanted" "$?" "the build would have nothing to read"
done

jq --exit-status . "$made/first-plugin/plugin.json" >/dev/null
assert "the manifest is readable JSON" "$?" "the build stops on the first line"

[ "$(jq --raw-output '."ai-plugin-sdk".version' "$made/first-plugin/plugin.json")" \
  = "$(jq --raw-output '.version' "$SDK/package.json")" ]
assert "and names this SDK as the one it needs" "$?" \
  "a new plugin asks for a version that is not the one that wrote it"

"$SDK/build" "$made/first-plugin" >/dev/null 2>"$WORK/built-said"
assert "the build builds it" "$?" "it said: $(cat "$WORK/built-said")"

printf "\nTest group: and the hook it wrote speaks\n"

distribution="$(for folder in "$made/first-plugin"/distributions/*/; do basename "$folder"; done | head -1)"
[ -n "$distribution" ]
assert "the build wrote a distribution" "$?" "there is nothing to install"

said="$(printf '{"hook_event_name":"SessionStart","session_id":"s1"}' \
  | env FIRST_PLUGIN_HOME="$WORK/made-home" \
    bash "$made/first-plugin/distributions/$distribution/hooks/say-the-rule.sh" 2>/dev/null)"

printf '%s' "$said" | jq --exit-status '.hookSpecificOutput.additionalContext | length > 0' >/dev/null
assert "a session start is given the rule" "$?" "it said '$said'"

printf '%s' "$said" | grep --quiet --fixed-strings 'at most 8 lines'
assert "with the default ceiling written into it" "$?" "the setting reached nothing"

printf '%s' "$said" | grep --quiet --fixed-strings '{ceiling}'
[ "$?" = "1" ]
assert "and nothing left to fill in" "$?" "a reader is shown the placeholder"

printf "\nTest group: it refuses to write over a plugin\n"

"$SDK/new-plugin" "$made/first-plugin" >/dev/null 2>&1
outcome="$?"
[ "$outcome" != "0" ]
assert "a directory that already holds a manifest is refused" "$?" \
  "it overwrote a plugin somebody was working on"

counted
