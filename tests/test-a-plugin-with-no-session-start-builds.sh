#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A plugin that only refuses tool calls prints nothing at the start of a
# session. Its generated manifest still names the function that lists what it
# prints, and bash refuses a function with nothing in it: every line after that
# one is never read, and every hook that sources the libraries says so on stderr.

fixture="$WORK/quiet-plugin"
mkdir -p "$fixture/hooks"
jq --null-input '{name: "quiet-plugin", version: "0.1.0", description: "Refuses, and says nothing.",
  hooks: {PreToolUse: ["refuse.sh"]}}' > "$fixture/plugin.json"
printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$fixture/hooks/refuse.sh"

"$SDK/build" "$fixture" "$WORK/quiet-built" "$WORK/quiet-INSTALL.md" >/dev/null

printf "Test group: a plugin with no session start hook gets a manifest bash reads\n"

for manifest in "$WORK"/quiet-built/*/hooks/lib/plugin-manifest.sh; do
  harness="${manifest#"$WORK/quiet-built/"}"
  harness="${harness%%/*}"

  complaint="$(bash -n "$manifest" 2>&1)"
  [ -z "$complaint" ]
  assert "the $harness manifest parses" "$?" "$complaint"

  listed="$(bash -c ". \"$manifest\" && plugin_session_start_hooks" 2>&1)"
  [ -z "$listed" ]
  assert "and lists nothing to print" "$?" "it said '$listed'"
done

complaint="$(printf '{}' | bash -c ". \"$WORK/quiet-built/claude/hooks/lib/settings.sh\"" 2>&1)"
[ -z "$complaint" ]
assert "the settings library sources without a word on stderr" "$?" "$complaint"

printf "\nTest group: the cloud checkout is still refreshed at session start\n"

refreshes="$(jq --raw-output '.hooks.SessionStart[]?.hooks[]?.command' "$WORK/quiet-built/claude-code-cloud/settings.json" \
  | grep --count --fixed-strings 'refresh.sh')"
[ "$refreshes" = "1" ]
assert "refresh.sh is registered once" "$?" \
  "it is registered $refreshes times, and a container that has been up for days runs last week's copy"

counted
