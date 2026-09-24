#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# Two plugins that restrict what a tool call may do are installed side by side,
# and one of them allowing a call must never undo another refusing it. Claude
# Code decides that itself across every hook it runs. Pi hands
# each extension the call in turn and stops at the first block, so what the SDK
# decides is how one plugin's own hooks add up: a deny outranks an ask, and an
# ask outranks an allow, whatever order they ran in.

if ! command -v node >/dev/null 2>&1 || ! node --experimental-strip-types --eval '' >/dev/null 2>&1; then
  printf '  SKIP  node that strips types is not installed, so the Pi extension cannot be run here\n'
  exit 0
fi

fixture="$WORK/restricting-plugin"
mkdir -p "$fixture/hooks"
jq --null-input '{
  name: "restricting-plugin",
  version: "0.1.0",
  description: "Allows one call and refuses another.",
  hooks: { PreToolUse: ["allow-everything.sh", "refuse-a-secret.sh", "ask-about-a-write.sh"] }
}' > "$fixture/plugin.json"

answer() {
  printf 'jq --null-input --compact-output --arg r "%s" '"'"'{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "%s", permissionDecisionReason: $r}}'"'"'\n' "$2" "$1"
}
{
  printf '#!/usr/bin/env bash\ncat >/dev/null\n'
  answer allow "everything is allowed"
} > "$fixture/hooks/allow-everything.sh"
{
  printf '#!/usr/bin/env bash\npayload="$(cat)"\n'
  printf 'case "$(printf "%%s" "$payload" | jq --raw-output ".tool_input.command // .tool_input.file_path // empty")" in\n'
  printf '  *secret*) ;;\n  *) exit 0 ;;\nesac\n'
  answer deny "that names a secret"
} > "$fixture/hooks/refuse-a-secret.sh"
{
  printf '#!/usr/bin/env bash\npayload="$(cat)"\n'
  printf '[ "$(printf "%%s" "$payload" | jq --raw-output .tool_name)" = "Write" ] || exit 0\n'
  answer ask "that writes a file"
} > "$fixture/hooks/ask-about-a-write.sh"

"$SDK/build" "$fixture" "$WORK/fixture-built" "$WORK/fixture-INSTALL.md" >/dev/null
EXTENSION="$WORK/fixture-built/pi/src/index.ts"

# One call handed to the extension the way Pi hands it, and what came back.
called() {
  local tool="$1" input="$2" confirms="${3-}"
  (cd "$WORK" && node --experimental-strip-types --no-warnings --input-type=module --eval "
    const extension = (await import('$EXTENSION')).default;
    const handlers = {};
    extension({ on: (event, handler) => { handlers[event] = handler; } });
    const ctx = { cwd: '$WORK', hasUI: '$confirms' !== '', ui: { confirm: async () => '$confirms' === 'yes' } };
    const result = await handlers.tool_call({ type: 'tool_call', toolCallId: '1', toolName: '$tool', input: $input }, ctx);
    process.stdout.write(result?.block ? 'block: ' + result.reason : 'pass');
  ")
}

printf "Test group: one hook refusing outranks another allowing\n"

said="$(called bash '{"command": "cat the-secret"}')"
[ "$said" = "block: that names a secret" ]
assert "a call one hook denies and another allows is blocked" "$?" "it came back '$said'"

said="$(called bash '{"command": "ls"}')"
[ "$said" = "pass" ]
assert "a call every hook allows goes ahead" "$?" "it came back '$said'"

said="$(called write '{"path": "the-secret.txt", "content": "x"}' yes)"
[ "$said" = "block: that names a secret" ]
assert "a deny outranks an ask, even one a person would approve" "$?" "it came back '$said'"

printf "\nTest group: an ask outranks an allow, and a person answers it\n"

said="$(called write '{"path": "notes.txt", "content": "x"}' yes)"
[ "$said" = "pass" ]
assert "approved, it goes ahead" "$?" "it came back '$said'"

said="$(called write '{"path": "notes.txt", "content": "x"}' no)"
[ "$said" = "block: that writes a file" ]
assert "declined, it is blocked" "$?" "it came back '$said'"

said="$(called write '{"path": "notes.txt", "content": "x"}')"
[ "$said" = "block: that writes a file" ]
assert "with nobody there to ask, it is blocked" "$?" "it came back '$said'"

printf "\nTest group: a hook reads the call in the names every other harness sends\n"

said="$(called read '{"path": "the-secret.env"}')"
[ "$said" = "block: that names a secret" ]
assert "Pi's path arrives as file_path" "$?" "it came back '$said'"

printf "\nTest group: a hook that lost its executable bit still runs\n"

chmod -x "$WORK/fixture-built/pi/hooks/refuse-a-secret.sh"
said="$(called bash '{"command": "cat the-secret"}')"
[ "$said" = "block: that names a secret" ]
assert "it is run through bash" "$?" "it came back '$said'"

printf "\nTest group: a hook that refuses by exiting 2 is a deny\n"

printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "refused by status" >&2\nexit 2\n' \
  > "$WORK/fixture-built/pi/hooks/allow-everything.sh"
said="$(called bash '{"command": "ls"}')"
[ "$said" = "block: refused by status" ]
assert "it blocks, with what it wrote to stderr as the reason" "$?" "it came back '$said'"

counted
