#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# The cloud install is the SDK's: a setup script the container runs, which
# registers the hooks and copies the skills and commands into the home it finds.
CLOUD="$BUILT/claude-code-cloud"
[ -d "$CLOUD" ] || { printf "  SKIP  this plugin has no cloud install\n"; exit 0; }

printf "Test group: an install puts everything a session reads in place\n"

home="$WORK/cloud-home"
settings="$home/.claude/settings.json"

install() { env HOME="$home" bash "$CLOUD/install.sh"; }

held() {
  jq --raw-output ".hooks[\"$1\"][]?.hooks[]?.command" "$settings" \
    | grep --count --fixed-strings "$2"
}

install >/dev/null
assert "the install exits 0" "$?" "the setup script would report a failure"

[ -f "$home/.claude/skills/settings/SKILL.md" ]
assert "the settings skill is in place" "$?" "the skill never appears"

[ -f "$home/.claude/commands/$NAME-update.md" ]
assert "the update command is in place" "$?" "the menu entry never appears"

# Every hook the build registered for this harness, each one once. The install
# writes the folder it is run from, which is not the folder the build named, so
# what is compared is the part below that folder.
registered() {
  jq --raw-output '.hooks | to_entries[] | .key as $e | .value[].hooks[].command
    | sub("^bash \"";"") | sub("\"$";"") | sub(".*/claude-code-cloud/";"")
    | "\($e) \(.)"' "$CLOUD/settings.json"
}

while read -r command; do
  [ -n "$command" ] || continue
  event="${command%% *}"
  inside="${command#* }"
  label="$inside is registered for $event"
  counted_as="$(held "$event" "$CLOUD/$inside")"
  [ "$counted_as" = "1" ]
  assert "$label" "$?" "it is registered $counted_as times, not once"
done < <(registered)

printf "\nTest group: installing over a settings file keeps what it holds\n"

jq --tab '.hooks.SessionStart += [ { hooks: [ { type: "command", command: "/somewhere/theirs.sh" } ] } ]' \
  "$settings" > "$settings.theirs" && mv "$settings.theirs" "$settings"

install >/dev/null
assert "the install exits 0" "$?" "the setup script would report a failure"

[ "$(held SessionStart "/somewhere/theirs.sh")" = "1" ]
assert "a hook the reader registered themselves survives it" "$?" \
  "every install and every refresh takes it away again"

first="$(registered | sed -n 's/^SessionStart //p' | head -1)"
counted_as="$(held SessionStart "$CLOUD/$first")"
[ "$counted_as" = "1" ]
assert "and this plugin is registered once, not twice" "$?" \
  "$first is registered $counted_as times"

counted
