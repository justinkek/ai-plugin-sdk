#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# The cloud install is the SDK's: a setup script the container runs, which
# registers the hooks and copies the skills into the home it finds.
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

[ -f "$home/.claude/skills/$NAME-settings/SKILL.md" ]
assert "the settings skill is in place, under the plugin's name" "$?" "the skill never appears"

sed -n '2p' "$home/.claude/skills/$NAME-settings/SKILL.md" | grep --quiet --line-regexp "name: $NAME-settings"
assert "and it answers to that name" "$?" \
  "its frontmatter still says $(sed -n '2p' "$home/.claude/skills/$NAME-settings/SKILL.md")"

[ ! -e "$home/.claude/skills/settings" ] && [ ! -e "$home/.claude/commands/$NAME-update.md" ]
assert "and nothing is written under a bare name" "$?" \
  "a second plugin built with this SDK writes the same name"

# Every hook the build registered for this harness, as many times as the build
# registered it: a hook asking for several tool kinds is one group each. The install
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
  wanted="$(registered | grep --count --line-regexp --fixed-strings "$command")"
  [ "$counted_as" = "$wanted" ]
  assert "$label" "$?" "it is registered $counted_as times, not $wanted"
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

printf "\nTest group: a second plugin in the same home keeps both sets of skills\n"

# The same plugin under another name is a second plugin as far as an install
# can tell: its skills carry the same bare names as this one's.
other="$WORK/other-plugin"
cp -R "$PLUGIN" "$other"
rm -rf "$other/.git" "$other/distributions"
jq --tab '.name = "other-plugin" | .displayName = "other-plugin"' "$PLUGIN/plugin.json" > "$other/plugin.json"
"$SDK/build" "$other" "$other/distributions" "$other/INSTALL.md" >/dev/null 2>&1
env HOME="$home" bash "$other/distributions/claude-code-cloud/install.sh" >/dev/null

grep --quiet --fixed-strings "Rendered from $NAME " "$home/.claude/skills/$NAME-settings/SKILL.md"
assert "this plugin's settings skill is still its own" "$?" \
  "the second install overwrote it, and this plugin's settings now open the other one's"

grep --quiet --fixed-strings "Rendered from other-plugin " "$home/.claude/skills/other-plugin-settings/SKILL.md"
assert "and the other plugin's sits beside it" "$?" "the second install wrote none of its own"

printf "\nTest group: what an older install left under the bare names is cleared\n"

leftover="$WORK/leftover-home"
mkdir -p "$leftover/.claude/skills/settings" "$leftover/.claude/skills/update" "$leftover/.claude/commands"
printf -- '---\nname: settings\n---\n\nRendered from %s 0.0.1.\n' "$NAME" > "$leftover/.claude/skills/settings/SKILL.md"
printf -- '---\nname: update\n---\n\nRendered from somebody-else 0.0.1.\n' > "$leftover/.claude/skills/update/SKILL.md"
printf 'old\n' > "$leftover/.claude/commands/$NAME-settings.md"
env HOME="$leftover" bash "$CLOUD/install.sh" >/dev/null

[ ! -e "$leftover/.claude/skills/settings" ]
assert "a bare skill rendered from this plugin is taken away" "$?" \
  "it stays, answering to settings beside the named copy"

[ -f "$leftover/.claude/skills/update/SKILL.md" ]
assert "a bare skill rendered from another plugin is left alone" "$?" "the install deleted someone else's skill"

[ ! -e "$leftover/.claude/commands/$NAME-settings.md" ]
assert "and the old command of the same name is taken away" "$?" \
  "a command and a skill of the same name both answer to it"

counted
