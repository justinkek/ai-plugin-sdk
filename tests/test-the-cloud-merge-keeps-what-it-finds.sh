#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# The cloud install has no plugin directory to drop a registration file into:
# it writes into the one settings file the reader may already be using. The
# merge puts this plugin's hooks in and leaves everything else alone.
CLOUD="$BUILT/claude-code-cloud"
[ -d "$CLOUD" ] || { printf "  SKIP  this plugin has no cloud install\n"; exit 0; }

settings="$WORK/merge/settings.json"
checkout="$WORK/merge/checkout"
said="$WORK/merge/said"
mkdir -p "$WORK/merge" "$WORK/empty"

merge() { bash "$CLOUD/merge-settings.sh" "$CLOUD/settings.json" "$settings" "$checkout" 2>"$said"; }

held() {
  jq --raw-output ".hooks[\"$1\"][]?.hooks[]?.command" "$settings" \
    | grep --count --fixed-strings "$2"
}

# The first hook this plugin registers for an event, as a path below the
# checkout, which is what the merge writes.
inside() {
  jq --raw-output --arg event "$1" '.hooks[$event][]?.hooks[]?.command
    | sub("^bash \"";"") | sub("\"$";"") | sub(".*/claude-code-cloud/";"")' \
    "$CLOUD/settings.json" | grep '^hooks/' | head -1
}

FIRST="$(inside SessionStart)"
[ -n "$FIRST" ] || { printf "  SKIP  this plugin registers no session start hook\n"; exit 0; }

printf "Test group: with no file there, the registrations are written as they are\n"

rm -f "$settings"
merge
assert "the merge exits 0" "$?" "an install would report a failure"

[ "$(held SessionStart "$checkout/$FIRST")" = "1" ]
assert "every command names the checkout it was run from" "$?" \
  "they name the path the registrations state, which an install elsewhere has nothing at"

printf '%s' "$(cat "$settings")" | grep --quiet --perl-regexp '^\t"hooks"'
assert "and the file is written with tabs, as the one beside it is" "$?" \
  "a reader opening it sees it reformatted"

printf "\nTest group: what somebody else registered is kept\n"

cat > "$settings" <<'JSON'
{
	"env": { "THEIRS": "kept" },
	"hooks": {
		"SessionStart": [ { "hooks": [ { "type": "command", "command": "/somewhere/theirs.sh" } ] } ],
		"PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "/somewhere/guard.sh" } ] } ]
	}
}
JSON

merge
assert "the merge exits 0" "$?" "an install would report a failure"

[ "$(held SessionStart "/somewhere/theirs.sh")" = "1" ]
assert "their hook on an event this plugin uses is still registered" "$?" \
  "merging took away a hook the reader registered themselves"

[ "$(held PreToolUse "/somewhere/guard.sh")" = "1" ]
assert "so is their hook on an event it never touches" "$?" \
  "a whole event the reader configured was dropped"

[ "$(jq --raw-output '.env.THEIRS' "$settings")" = "kept" ]
assert "and a key that is not a hook at all is untouched" "$?" "everything but the hooks was dropped"

[ "$(held SessionStart "$checkout/$FIRST")" = "1" ]
assert "this plugin is registered beside them" "$?" "the merge kept their file and registered nothing"

[ "$(jq '.hooks.SessionStart | length' "$settings")" = "2" ]
assert "in a group of its own, not folded into theirs" "$?" \
  "their group was rewritten rather than left as it was"

printf "\nTest group: merging twice registers each hook once\n"

merge
[ "$(held SessionStart "$checkout/$FIRST")" = "1" ]
assert "the second merge does not register $FIRST twice" "$?" \
  "every refresh adds another copy, and every hook runs again for each"

[ "$(held SessionStart "/somewhere/theirs.sh")" = "1" ]
assert "and still holds their hook once" "$?" "their hook was duplicated or dropped"

printf "\nTest group: what an older install of this plugin registered is replaced\n"

stale="/opt/$NAME/$FIRST"
jq --tab --null-input --arg stale "$stale" \
  '{ hooks: { SessionStart: [ { hooks: [ { type: "command", command: $stale } ] } ] } }' > "$settings"
merge

[ "$(held SessionStart "$stale")" = "0" ]
assert "the path an older version registered is gone" "$?" \
  "both copies run, so everything this plugin does happens twice"

[ "$(held SessionStart "$checkout/$FIRST")" = "1" ]
assert "and the current one is there, once" "$?" "an upgraded session would run none or two"

printf "\nTest group: a group this plugin filled on its own goes away rather than sitting empty\n"

alone="$(inside Stop)"
if [ -n "$alone" ]; then
  jq --tab --null-input --arg only "$checkout/$alone" \
    '{ hooks: { Stop: [ { hooks: [ { type: "command", command: $only } ] } ] } }' > "$settings"
  merge
  [ "$(jq '.hooks.Stop | length' "$settings")" = "1" ]
  assert "the emptied group is dropped" "$?" \
    "an empty group is left behind, and it grows by one on every refresh"
fi

printf "\nTest group: a file that does not read as an object is kept, not thrown away\n"

for holds in 'this is not json' '[1, 2, 3]'; do
  printf '%s' "$holds" > "$settings"
  rm -f "$settings.unreadable"
  merge
  assert "the merge exits 0 on: $holds" "$?" "an install would report a failure"

  [ "$(cat "$settings.unreadable")" = "$holds" ]
  assert "what it could not read is kept beside the new file" "$?" \
    "what the reader wrote is gone with nothing to recover it from"

  [ "$(held SessionStart "$checkout/$FIRST")" = "1" ]
  assert "and the registrations are written all the same" "$?" "the session gets no hooks"

  grep --quiet --fixed-strings "unreadable" "$said"
  assert "the merge says it did that" "$?" "it happened silently"
done

printf "\nTest group: without jq the file is left alone\n"

printf '%s\n' '{ "env": { "THEIRS": "kept" } }' > "$settings"

env PATH="$WORK/empty" "$BASH" "$CLOUD/merge-settings.sh" \
  "$CLOUD/settings.json" "$settings" "$checkout" 2>"$said"
outcome="$?"
[ "$outcome" != "0" ]
assert "the merge fails rather than reporting success" "$?" "an install would say the hooks are registered"

[ "$(jq --raw-output '.env.THEIRS' "$settings")" = "kept" ]
assert "and what the reader wrote is still there" "$?" "it was overwritten by a merge that could not merge"

grep --quiet --fixed-strings "jq" "$said"
assert "and it says what is missing" "$?" "it failed without saying why"

counted
