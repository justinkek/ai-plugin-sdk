#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A plugin names tool calls by common kinds, `bash(git *)` or `edit(*.sh)`, and
# never by a client's own tool names. The build turns them into each client's
# registration, and tool_entries hands the hook the calls it asked for, in the
# same shape whichever client sent them. This builds a plugin of its own, since
# which kinds the example asks for is not the point.
fixture="$WORK/fixture"
mkdir -p "$fixture/hooks"
cat > "$fixture/plugin.json" <<'JSON'
{
	"name": "fixture", "version": "0.1.0", "description": "Asks for tool calls.", "repository": "you/fixture",
	"hooks": {
		"session_start": [ { "script": "hello.sh", "on": ["startup", "resume"] } ],
		"before_tool": [ { "script": "guard.sh", "on": ["bash(git *)", "write(*.sh)", "edit"] } ],
		"stop": ["note.sh"]
	}
}
JSON
printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$fixture/hooks/hello.sh"
printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$fixture/hooks/note.sh"
printf '#!/usr/bin/env bash\npayload="$(cat)"\n. "$(dirname "$0")/lib/tool.sh"\ntool_entries "$payload"\n' \
  > "$fixture/hooks/guard.sh"
built="$WORK/fixture-built"
"$SDK/build" "$fixture" "$built" "$WORK/fixture-install.md" >/dev/null

groups() { jq --compact-output --arg event "$2" '.hooks[$event][] | {matcher, if: [.hooks[].if // empty]}' "$1"; }

printf "Test group: the build names each client's own tools\n"

claude="$built/claude/hooks/hooks.json"
groups "$claude" PreToolUse | grep --quiet --fixed-strings '{"matcher":"Bash","if":["Bash(git *)"]}'
assert "Claude filters bash(git *) with its own if" "$?" "$(groups "$claude" PreToolUse)"

groups "$claude" PreToolUse | grep --quiet --fixed-strings '{"matcher":"Write","if":["Write(*.sh)"]}'
assert "and write(*.sh) the same way" "$?" "$(groups "$claude" PreToolUse)"

groups "$claude" PreToolUse | grep --quiet --fixed-strings '{"matcher":"mcp__remote-devices__device_bash","if":[]}'
assert "a command run on a connected device is a bash call too" "$?" "$(groups "$claude" PreToolUse)"

codex="$built/codex/hooks/hooks.json"
[ "$(groups "$codex" PreToolUse)" = '{"matcher":"^(Bash|apply_patch)$","if":[]}' ]
assert "Codex filters on tool names alone, so the patterns are left to the hook" "$?" "$(groups "$codex" PreToolUse)"

groups "$claude" SessionStart | grep --quiet --fixed-strings '{"matcher":"startup|resume","if":[]}'
assert "an event that is not a tool call filters on its own values" "$?" "$(groups "$claude" SessionStart)"

printf "\nTest group: the hook reads the calls it asked for, the same way on every client\n"

entries() { printf '%s' "$2" | bash "$built/$1/hooks/guard.sh" | jq --raw-output '"\(.kind) \(.file)\(.command)"'; }

[ "$(entries claude '{"tool_name":"Bash","tool_input":{"command":"npm test && git push"}}')" = "bash npm test && git push" ]
assert "a git command inside a longer one is asked for" "$?" "it was not handed over"

[ -z "$(entries claude '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}')" ]
assert "a command that runs no git is not" "$?" "it was handed over"

[ "$(entries claude '{"tool_name":"Write","tool_input":{"file_path":"bin/run.sh","content":"enc=1"}}')" = "write bin/run.sh" ]
assert "a shell file written on Claude is a write entry" "$?" "it was not"

[ -z "$(entries claude '{"tool_name":"Write","tool_input":{"file_path":"index.ts","content":"x"}}')" ]
assert "a file the pattern does not name is not" "$?" "it was handed over"

patch=$'*** Begin Patch\n*** Add File: new.sh\n+enc=1\n*** Update File: run.txt\n@@\n-value=1\n+value=2\n*** Add File: notes.md\n+hi\n*** Delete File: old.sh\n*** End Patch'
payload="$(jq --null-input --compact-output --arg patch "$patch" '{tool_name:"apply_patch",tool_input:{command:$patch}}')"
[ "$(entries codex "$payload" | tr '\n' ',')" = "write new.sh,edit run.txt," ]
assert "one Codex patch is one entry per file it asked for" "$?" "it read '$(entries codex "$payload" | tr '\n' ',')'"

edited="$(printf '%s' "$payload" | bash "$built/codex/hooks/guard.sh" | jq --raw-output 'select(.kind == "edit") | "\(.removed) -> \(.added)"')"
[ "$edited" = "value=1 -> value=2" ]
assert "and an edit carries what it removed and what it added" "$?" "it read '$edited'"

printf "\nTest group: each distribution carries only its own client's reader\n"

[ -f "$built/claude/hooks/lib/tool/tool_entries_read.sh" ] && [ -f "$built/codex/hooks/lib/tool/tool_entries_read.sh" ]
assert "each distribution carries its own reader" "$?" "one is missing"

grep --quiet --fixed-strings 'apply_patch' "$built/claude/hooks/lib/tool/tool_entries_read.sh"
[ "$?" = "1" ]
assert "and Claude's reader knows nothing of Codex's patches" "$?" "it carries Codex's code"

printf "\nTest group: an event the SDK does not know stops the build\n"

jq '.hooks.before_every_thing = ["hello.sh"]' "$fixture/plugin.json" > "$WORK/plugin.json.new" \
  && mv "$WORK/plugin.json.new" "$fixture/plugin.json"
"$SDK/build" "$fixture" "$WORK/refused" "$WORK/refused.md" >/dev/null 2>&1
[ "$?" != "0" ]
assert "a misspelt event is refused" "$?" "it built a registration nothing fires"

counted
