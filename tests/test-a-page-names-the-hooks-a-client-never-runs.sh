#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A client that runs hooks does not run every event, or show a hook every kind
# of tool call. The compatibility page says Partial where this plugin needs one
# a client lacks, and names it, rather than Supported because hooks run at all.
printf "Test group: every client that runs hooks says which events and tool kinds\n"

for source in "$SDK"/clients/*/client.json; do
  named="$(basename "$(dirname "$source")")"
  [ "$(jq --raw-output '.runs.hooks' "$source")" = "true" ] || continue
  jq --exit-status '.runs.events | length > 0' "$source" >/dev/null
  assert "$named names the events it fires" "$?" "the page cannot tell which hooks run there"
  jq --exit-status '.runs.tool_kinds | length > 0' "$source" >/dev/null
  assert "$named names the tool kinds a hook sees" "$?" "the page cannot tell which calls are guarded"
done

printf "\nTest group: a plugin needing what a client lacks reads Partial there, with the reason\n"

fixture="$WORK/needs"
mkdir -p "$fixture/hooks"
cat > "$fixture/plugin.json" <<'JSON'
{
	"name": "needs", "version": "0.1.0", "description": "Needs things.", "repository": "you/needs",
	"hooks": {
		"before_tool": [ { "script": "guard.sh", "on": ["bash(git *)", "read(*.env)", "multi_edit", "edit"] } ],
		"session_end": ["after.sh"]
	}
}
JSON
printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$fixture/hooks/guard.sh"
printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$fixture/hooks/after.sh"
"$SDK/build" "$fixture" "$WORK/needs-built" "$WORK/needs-install.md" >/dev/null
page="$fixture/COMPATIBILITY.md"

row() { grep --max-count=1 "^| $1 | $2 | $3 |" "$page"; }

row Codex CLI Local | grep --quiet '| Partial |$'
assert "Codex reads Partial: it reads files through Bash, and the plugin asks for git commands alone" "$?" "$(row Codex CLI Local)"

grep --quiet --fixed-strings 'read (done through bash here)' "$page"
assert "and the page says read is done through bash there" "$?" "$(grep --fixed-strings '**Codex**' "$page")"

grep '^- \*\*Pi\*\*' "$page" | grep --quiet --fixed-strings 'session_end'
assert "Pi names session_end, an event it never fires" "$?" "$(grep --fixed-strings '**Pi**' "$page")"

row 'Claude Code' CLI Local | grep --quiet '| Supported |$'
assert "Claude Code reads Supported: several replacements come through Edit, which the plugin asks for" "$?" \
  "$(row 'Claude Code' CLI Local)"

counted
