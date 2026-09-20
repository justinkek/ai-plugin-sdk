#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

FOLDER="$BUILT/claude-code-cloud"
if [ ! -x "$FOLDER/install.sh" ]; then
  printf "This plugin has no cloud install.\n"
  exit 0
fi

HOME_DIR="$WORK/cloud-home"
mkdir -p "$HOME_DIR"

registered() {
  jq '[.hooks[]?[]?.hooks[]?.command] | length' "$HOME_DIR/.claude/settings.json"
}

declared="$(jq '[.hooks[]?[]?.hooks[]?.command] | length' "$FOLDER/settings.json")"

printf "Test group: an install registers every hook the folder declares\n"

env HOME="$HOME_DIR" bash "$FOLDER/install.sh" >/dev/null 2>&1
assert "the install runs" "$?" "nothing is registered at all"

[ "$(registered)" = "$declared" ]
assert "it registers $declared commands" "$?" "it registered $(registered)"

printf "\nTest group: an upgrade merges rather than appends\n"

# A cloud environment rebuilds and runs the install again. Appending would
# register every hook a second time, and a session would be told twice.
env HOME="$HOME_DIR" bash "$FOLDER/install.sh" >/dev/null 2>&1
[ "$(registered)" = "$declared" ]
assert "running it again still registers $declared" "$?" \
  "it registered $(registered), so a session is told everything twice"

printf "\nTest group: it keeps what someone else put there\n"

python3 - "$HOME_DIR/.claude/settings.json" <<'ADD'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); d = json.loads(p.read_text())
d["model"] = "theirs"
d["hooks"].setdefault("SessionStart", []).append(
    {"hooks": [{"type": "command", "command": "bash \"/somewhere/else/theirs.sh\""}]})
p.write_text(json.dumps(d, indent="\t"))
ADD
env HOME="$HOME_DIR" bash "$FOLDER/install.sh" >/dev/null 2>&1

[ "$(jq --raw-output '.model' "$HOME_DIR/.claude/settings.json")" = "theirs" ]
assert "a setting of theirs is still there" "$?" "the install overwrote the file"

jq --exit-status '[.hooks[]?[]?.hooks[]?.command] | map(select(contains("theirs.sh"))) | length == 1' \
  "$HOME_DIR/.claude/settings.json" >/dev/null
assert "and a hook of theirs is registered once" "$?" "the install dropped it or doubled it"

[ "$(registered)" = "$((declared + 1))" ]
assert "beside this plugin's $declared" "$?" "it registered $(registered)"

printf "\nTest group: the skills and commands land where the client looks\n"

[ -f "$HOME_DIR/.claude/skills/update/SKILL.md" ]
assert "the skills are under ~/.claude/skills" "$?" "a session finds no skill to follow"

[ -f "$HOME_DIR/.claude/commands/$NAME-update.md" ]
assert "the commands carry the plugin's name" "$?" \
  "a command and a skill of the same name both answer to it, and the command wins"

printf "\nTest group: an unreadable settings file is kept rather than lost\n"

printf 'not json at all\n' > "$HOME_DIR/.claude/settings.json"
env HOME="$HOME_DIR" bash "$FOLDER/install.sh" >/dev/null 2>&1
[ -f "$HOME_DIR/.claude/settings.json.unreadable" ]
assert "what could not be read is kept beside it" "$?" "someone's file went in the bin"

[ "$(registered)" = "$declared" ]
assert "and the hooks are registered fresh" "$?" "it registered $(registered)"

counted
